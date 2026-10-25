# Leakage-safe helpers for the accompanying CRISP-DM notebook.
# No packages are installed and no analysis runs when this file is sourced.
required_packages <- c("nnet", "randomForest", "xgboost")
check_packages <- function() {
  missing <- required_packages[!vapply(required_packages, requireNamespace,
                                     logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install required packages first: ", paste(missing, collapse = ", "))
}

find_project_root <- function(start = getwd()) {
  here <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(here, "data", "eye_cancer_patients.csv")) &&
        file.exists(file.path(here, "src", "ml_pipeline.R"))) return(here)
    parent <- dirname(here)
    if (identical(parent, here)) stop("Run from the repository root or a subdirectory.")
    here <- parent
  }
}

read_project_data <- function(root) {
  raw <- read.csv(file.path(root, "data", "eye_cancer_patients.csv"),
                  stringsAsFactors = FALSE, na.strings = c("", "NA"))
  needed <- c("Patient_ID", "Outcome_Status", "Age", "Gender", "Cancer_Type",
              "Laterality", "Stage_at_Diagnosis", "Genetic_Markers", "Family_History", "Country")
  if (!all(needed %in% names(raw))) stop("Missing required data columns.")
  if (anyNA(raw$Patient_ID) || anyDuplicated(raw$Patient_ID)) stop("Patient IDs must be unique and present.")
  if (anyNA(raw$Outcome_Status)) stop("Missing outcomes require a documented exclusion policy.")
  raw$Outcome_Status <- factor(make.names(raw$Outcome_Status))
  if (!setequal(levels(raw$Outcome_Status), c("Active", "Deceased", "In.Remission")))
    stop("Unexpected outcome labels.")
  if (any(!is.na(raw$Age) & (!is.finite(raw$Age) | raw$Age <= 0))) stop("Check invalid ages.")
  # Keep the literal marker category 'None'; it is not automatically an NA.
  raw
}

make_predictors <- function(raw) {
  # Conservative baseline-feature analysis. Future survival and treatment information
  # are excluded because their timing relative to the outcome is not established.
  cols <- c("Age", "Gender", "Cancer_Type", "Laterality", "Stage_at_Diagnosis",
            "Genetic_Markers", "Family_History", "Country")
  x <- raw[, cols, drop = FALSE]
  x$AgeGroup <- as.character(cut(x$Age, breaks = c(0, 40, 60, Inf),
                                labels = c("Young", "Middle", "Senior"), right = FALSE))
  x
}

stratified_split <- function(y, fraction = 0.7, seed = 123) {
  set.seed(seed)
  sort(unlist(lapply(split(seq_along(y), y), function(idx) {
    n <- max(1L, min(length(idx) - 1L, floor(length(idx) * fraction)))
    sample(idx, n)
  }), use.names = FALSE))
}
make_folds <- function(y, k = 5L, seed = 456) {
  if (any(table(y) < k)) stop("Each class needs at least k training observations.")
  set.seed(seed)
  folds <- integer(length(y))
  for (idx in split(seq_along(y), y)) folds[sample(idx)] <- rep(seq_len(k), length.out = length(idx))
  folds
}

# Learn imputation, category mappings, encoding and scaling only from fit rows.
fit_preprocessor <- function(x) {
  numeric_cols <- names(x)[vapply(x, is.numeric, logical(1))]
  categorical_cols <- setdiff(names(x), numeric_cols)
  medians <- vapply(x[numeric_cols], function(v) {
    m <- median(v, na.rm = TRUE)
    if (!is.finite(m)) stop("An entirely missing numeric predictor needs an explicit policy.")
    m
  }, numeric(1))
  vocab <- lapply(x[categorical_cols], function(v) {
    sort(unique(c(as.character(v[!is.na(v)]), "__MISSING__", "__NOVEL__")))
  })
  prep <- list(columns = names(x), numeric = numeric_cols, categorical = categorical_cols,
               medians = medians, vocab = vocab)
  shaped <- shape_frame(prep, x)
  mm <- encode_frame(prep, shaped)
  sds <- apply(mm, 2, sd)
  prep$keep <- names(sds)[is.finite(sds) & sds > 0]
  if (!length(prep$keep)) stop("No varying predictors.")
  mm <- mm[, prep$keep, drop = FALSE]
  prep$center <- colMeans(mm)
  prep$scale <- apply(mm, 2, sd)
  prep
}
shape_frame <- function(prep, x) {
  x <- x[, prep$columns, drop = FALSE]
  for (nm in prep$numeric) {
    x[[nm]][is.na(x[[nm]])] <- prep$medians[[nm]]
    if (any(!is.finite(x[[nm]]))) stop("Non-finite predictor.")
  }
  for (nm in prep$categorical) {
    v <- as.character(x[[nm]])
    v[is.na(v)] <- "__MISSING__"
    v[!v %in% prep$vocab[[nm]]] <- "__NOVEL__"
    x[[nm]] <- factor(v, levels = prep$vocab[[nm]])
  }
  x
}
encode_frame <- function(prep, shaped) {
  parts <- lapply(prep$columns, function(nm) {
    if (nm %in% prep$numeric) {
      m <- matrix(shaped[[nm]], ncol = 1, dimnames = list(NULL, nm))
    } else {
      m <- vapply(prep$vocab[[nm]], function(level) as.numeric(shaped[[nm]] == level),
                  numeric(nrow(shaped)))
      colnames(m) <- paste(nm, prep$vocab[[nm]], sep = "__")
    }
    m
  })
  do.call(cbind, parts)
}
transform_predictors <- function(prep, x, kind) {
  frame <- shape_frame(prep, x)
  if (kind == "rf") return(frame)
  mm <- encode_frame(prep, frame)[, prep$keep, drop = FALSE]
  if (kind %in% c("lr", "knn")) mm <- sweep(sweep(mm, 2, prep$center, "-"), 2, prep$scale, "/")
  mm
}

probability_labels <- function(p) factor(colnames(p)[max.col(p, ties.method = "first")],
                                          levels = colnames(p))
score_predictions <- function(truth, pred, classes = levels(truth)) {
  cm <- table(factor(truth, levels = classes), factor(pred, levels = classes))
  tp <- diag(cm)
  divide <- function(a, b) ifelse(b == 0, 0, a / b)
  precision <- divide(tp, colSums(cm))
  recall <- divide(tp, rowSums(cm))
  f1 <- divide(2 * tp, rowSums(cm) + colSums(cm))
  list(summary = c(Accuracy = sum(tp) / sum(cm), Macro_F1 = mean(f1),
                   Macro_Precision = mean(precision), Macro_Recall = mean(recall)),
       per_class = data.frame(Class = classes, Precision = precision,
                              Recall = recall, F1 = f1, Support = rowSums(cm)), confusion = cm)
}

# Full class probabilities for kNN, rather than only the winning class probability.
knn_probabilities <- function(train_x, y, new_x, k, classes) {
  k <- min(as.integer(k), nrow(train_x))
  out <- matrix(0, nrow(new_x), length(classes), dimnames = list(NULL, classes))
  train_sq <- rowSums(train_x * train_x)
  for (i in seq_len(nrow(new_x))) {
    distances <- pmax(0, train_sq + sum(new_x[i, ]^2) - 2 * as.vector(train_x %*% new_x[i, ]))
    # Stable ordering makes equal-distance ties reproducible.
    nearest <- order(distances, seq_along(distances))[seq_len(k)]
    out[i, ] <- tabulate(match(y[nearest], classes), nbins = length(classes)) / k
  }
  out
}
fit_engine <- function(kind, x, y, param, seed) {
  set.seed(seed)
  if (kind == "lr") {
    model <- nnet::multinom(y ~ ., data = data.frame(y = y, x, check.names = TRUE),
                           decay = param$decay, maxit = 1000, MaxNWts = 100000,
                           trace = FALSE)
    if (model$convergence != 0) stop("Logistic regression did not converge.")
    return(model)
  }
  if (kind == "knn") return(list(x = x, y = y, k = param$k))
  if (kind == "rf") return(randomForest::randomForest(x = x, y = y,
      ntree = param$ntree, mtry = min(param$mtry, ncol(x)),
      nodesize = 10L, maxnodes = 64L))
  if (kind == "xgb") return(xgboost::xgboost(data = x, label = as.integer(y) - 1L,
      objective = "multi:softprob", num_class = nlevels(y), nrounds = param$nrounds,
      max_depth = param$max_depth, eta = param$eta, subsample = 0.8,
      colsample_bytree = 0.8, nthread = 1, eval_metric = "mlogloss", verbose = 0))
  stop("Unknown model.")
}
engine_probabilities <- function(kind, model, x, classes) {
  if (kind == "knn") return(knn_probabilities(model$x, model$y, x, model$k, classes))
  if (kind == "lr") p <- predict(model, newdata = data.frame(x, check.names = TRUE), type = "probs")
  if (kind == "rf") p <- predict(model, newdata = x, type = "prob")
  if (kind == "xgb") p <- matrix(predict(model, x), ncol = length(classes), byrow = TRUE,
                                  dimnames = list(NULL, classes))
  p <- as.matrix(p)[, classes, drop = FALSE]
  if (any(!is.finite(p)) || any(p < 0) || any(abs(rowSums(p) - 1) > 1e-5))
    stop("Invalid class probabilities.")
  p
}
fit_predict <- function(kind, train_x, train_y, new_x, param, seed) {
  prep <- fit_preprocessor(train_x)
  fit_x <- transform_predictors(prep, train_x, kind)
  model <- fit_engine(kind, fit_x, train_y, param, seed)
  engine_probabilities(kind, model, transform_predictors(prep, new_x, kind), levels(train_y))
}

tune_model <- function(kind, x, y, folds, grid, seed = 1000) {
  classes <- levels(y)
  scores <- matrix(NA_real_, nrow(grid), max(folds))
  predictions <- vector("list", nrow(grid))
  for (g in seq_len(nrow(grid))) {
    oof <- matrix(NA_real_, nrow(x), length(classes), dimnames = list(NULL, classes))
    for (f in sort(unique(folds))) {
      validation <- which(folds == f)
      fit <- which(folds != f)
      p <- fit_predict(kind, x[fit, , drop = FALSE], y[fit], x[validation, , drop = FALSE],
                       as.list(grid[g, , drop = FALSE]), seed + f)
      oof[validation, ] <- p
      scores[g, f] <- score_predictions(y[validation], probability_labels(p), classes)$summary[["Macro_F1"]]
    }
    predictions[[g]] <- oof
  }
  mean_scores <- rowMeans(scores)
  best <- which.max(mean_scores)
  list(params = as.list(grid[best, , drop = FALSE]), oof = predictions[[best]],
       table = cbind(grid, CV_Macro_F1 = mean_scores,
                     CV_SD = apply(scores, 1, sd)), best_row = best)
}

bag_probabilities <- function(kind, x, y, new_x, param, bags = 30L, seed = 3000) {
  # Stratified sampling with replacement preserves all three classes in each bag.
  total <- matrix(0, nrow(new_x), nlevels(y), dimnames = list(NULL, levels(y)))
  for (b in seq_len(bags)) {
    set.seed(seed + b)
    idx <- unlist(lapply(split(seq_along(y), y), function(rows) sample(rows, length(rows), replace = TRUE)),
                  use.names = FALSE)
    total <- total + fit_predict(kind, x[idx, , drop = FALSE], y[idx], new_x, param, seed + 10000 + b)
  }
  total / bags
}
meta_features <- function(probabilities) {
  # Drop the last class per learner to avoid exact sum-to-one collinearity.
  out <- lapply(names(probabilities), function(nm) {
    p <- probabilities[[nm]][, -ncol(probabilities[[nm]]), drop = FALSE]
    colnames(p) <- paste(nm, colnames(p), sep = "__")
    p
  })
  as.data.frame(do.call(cbind, out), check.names = TRUE)
}
model_grids <- function(smoke = FALSE) {
  if (smoke) return(list(lr = data.frame(decay = c(0.1, 1)), knn = data.frame(k = c(5L, 15L)),
    rf = expand.grid(mtry = c(2L, 4L), ntree = 40L),
    xgb = expand.grid(max_depth = c(2L, 3L), eta = 0.1, nrounds = 15L)))
  list(lr = data.frame(decay = c(0.01, 0.1, 1)), knn = data.frame(k = c(5L, 15L, 35L)),
       rf = expand.grid(mtry = c(2L, 4L, 7L), ntree = 300L),
       xgb = expand.grid(max_depth = c(2L, 4L), eta = c(0.05, 0.1), nrounds = 100L))
}

run_experiment <- function(raw, outdir, smoke = FALSE, bags = if (smoke) 2L else 30L) {
  check_packages()
  if (smoke) {
    set.seed(99)
    # Deliberately separate outputs; smoke scores are never portfolio performance.
    idx <- unlist(lapply(split(seq_len(nrow(raw)), raw$Outcome_Status),
                         function(rows) sample(rows, min(100L, length(rows)))))
    raw <- raw[sort(idx), , drop = FALSE]
  }
  x <- make_predictors(raw)
  y <- raw$Outcome_Status
  train_idx <- stratified_split(y)
  test_idx <- setdiff(seq_along(y), train_idx)
  stopifnot(!length(intersect(raw$Patient_ID[train_idx], raw$Patient_ID[test_idx])))
  train_x <- x[train_idx, , drop = FALSE]; train_y <- y[train_idx]
  test_x <- x[test_idx, , drop = FALSE]
  folds <- make_folds(train_y, k = if (smoke) 3L else 5L)
  grids <- model_grids(smoke)
  names_display <- c(lr = "Logistic regression", knn = "kNN", rf = "Random forest", xgb = "XGBoost")
  tuning <- list(); oof <- list(); base_probs <- list(); bagged_probs <- list()
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  # Do not leave a previous run looking current if this run fails partway through.
  writeLines("RUNNING: results are not complete until run_status.txt says COMPLETE.", file.path(outdir, "run_status.txt"))
  for (kind in names(grids)) {
    message("Tuning ", names_display[[kind]], " using training folds only")
    tuning[[kind]] <- tune_model(kind, train_x, train_y, folds, grids[[kind]])
    oof[[kind]] <- tuning[[kind]]$oof
    write.csv(tuning[[kind]]$table, file.path(outdir, paste0("tuning_", kind, ".csv")), row.names = FALSE)
    base_probs[[kind]] <- fit_predict(kind, train_x, train_y, test_x, tuning[[kind]]$params, 2000)
    message("Bagging ", names_display[[kind]], ": ", bags, " fits")
    bagged_probs[[kind]] <- bag_probabilities(kind, train_x, train_y, test_x,
                                             tuning[[kind]]$params, bags)
  }
  # Training-only OOF predictions are the inputs to the meta-learner.
  # Hyperparameters were selected within training data; OOF scores themselves are
  # not reported as unbiased estimates after that selection. The outer test is untouched.
  meta_train <- data.frame(Outcome_Status = train_y, meta_features(oof))
  meta_model <- nnet::multinom(Outcome_Status ~ ., data = meta_train, decay = 1,
                              maxit = 1000, trace = FALSE)
  if (meta_model$convergence != 0) stop("Meta-learner did not converge.")
  stack_probs <- as.matrix(predict(meta_model, newdata = meta_features(base_probs), type = "probs"))[, levels(y), drop = FALSE]
  # Equal-weight soft voting across four homogeneous ensembles; no test-based weights.
  vote_probs <- Reduce("+", bagged_probs) / length(bagged_probs)
  final_probs <- c(setNames(base_probs, names_display[names(base_probs)]),
                   setNames(bagged_probs, paste("Bagged", names_display[names(bagged_probs)])),
                   list("Heterogeneous soft vote" = vote_probs, "OOF stacked ensemble" = stack_probs))
  # Majority baseline is learned from TRAINING class counts.
  majority <- names(which.max(table(train_y)))
  test_y <- y[test_idx]  # Evaluation starts only after models and ensemble rules are fixed.
  predicted <- lapply(final_probs, probability_labels)
  set.seed(9000)
  random_pred <- factor(sample(levels(y), length(test_idx), replace = TRUE,
                               prob = as.numeric(prop.table(table(train_y)))), levels = levels(y))
  predicted <- c(list("Majority baseline" = factor(rep(majority, length(test_idx)), levels = levels(y)),
                     "Stratified random baseline" = random_pred), predicted)
  scored <- lapply(predicted, function(pred) score_predictions(test_y, pred))
  comparison <- do.call(rbind, lapply(names(scored), function(nm) {
    data.frame(Model = nm, as.list(scored[[nm]]$summary), row.names = NULL)
  }))
  comparison$Mode <- if (smoke) "smoke" else "full"
  write.csv(comparison, file.path(outdir, "model_comparison.csv"), row.names = FALSE)
  per_class <- do.call(rbind, lapply(names(scored), function(nm) data.frame(Model = nm, scored[[nm]]$per_class)))
  write.csv(per_class, file.path(outdir, "per_class_metrics.csv"), row.names = FALSE)
  assignments <- data.frame(Patient_ID = raw$Patient_ID,
                             Partition = ifelse(seq_along(y) %in% train_idx, "train", "test"),
                             Fold = NA_integer_)
  assignments$Fold[train_idx] <- folds
  write.csv(assignments, file.path(outdir, "split_assignments.csv"), row.names = FALSE)
  pred_table <- data.frame(Patient_ID = raw$Patient_ID[test_idx], Actual = test_y,
                            as.data.frame(predicted, check.names = FALSE), check.names = FALSE)
  write.csv(pred_table, file.path(outdir, "test_predictions.csv"), row.names = FALSE)
  prob_table <- data.frame(Patient_ID = raw$Patient_ID[test_idx])
  for (nm in names(final_probs)) {
    p <- final_probs[[nm]]
    colnames(p) <- paste(nm, colnames(p), sep = "__")
    prob_table <- cbind(prob_table, p)
  }
  write.csv(prob_table, file.path(outdir, "test_probabilities.csv"), row.names = FALSE)
  saveRDS(list(tuning = tuning, metrics = comparison, per_class = per_class,
               confusion = lapply(scored, `[[`, "confusion"), smoke = smoke, bags = bags,
               train_n = length(train_idx), test_n = length(test_idx)), file.path(outdir, "analysis.rds"))
  capture.output(sessionInfo(), file = file.path(outdir, "sessionInfo.txt"))
  config <- list(mode = if (smoke) "smoke" else "full", bags = bags,
                 folds = max(folds), split_seed = 123, fold_seed = 456,
                 data_md5 = unname(tools::md5sum(file.path(find_project_root(), "data", "eye_cancer_patients.csv"))),
                 code_md5 = unname(tools::md5sum(file.path(find_project_root(), "src", "ml_pipeline.R"))),
                 predictors = names(x), excluded = c("Patient_ID", "Date_of_Diagnosis", "Survival_Time_Months",
                 "Treatment_Type", "Surgery_Status", "Radiation_Therapy", "Chemotherapy"))
  dput(config, file = file.path(outdir, "run_config.R"))
  writeLines("COMPLETE", file.path(outdir, "run_status.txt"))
  list(comparison = comparison, per_class = per_class, scored = scored,
       tuning = tuning, train_n = length(train_idx), test_n = length(test_idx), smoke = smoke)
}
