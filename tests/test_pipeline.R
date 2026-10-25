# Run from the repository root: Rscript tests/test_pipeline.R
source("src/ml_pipeline.R")
classes <- c("Active", "Deceased", "In.Remission")
y <- factor(rep(classes, each = 20), levels = classes)
idx <- stratified_split(y)
stopifnot(length(idx) == 42L, !anyDuplicated(idx), all(table(y[idx]) == 14L))
folds <- make_folds(y[idx], k = 5)
stopifnot(length(folds) == length(idx), all(table(folds, y[idx]) > 0))

# Exact hand-calculated confusion matrix; an unpredicted class contributes F1=0.
truth <- factor(c("Active", "Active", "Deceased", "In.Remission"), levels = classes)
pred <- factor(c("Active", "Deceased", "Deceased", "Deceased"), levels = classes)
s <- score_predictions(truth, pred)
stopifnot(abs(s$summary[["Accuracy"]] - 0.5) < 1e-12,
          abs(s$summary[["Macro_F1"]] - (2/3 + 1/2 + 0)/3) < 1e-12,
          s$per_class$F1[3] == 0)

train <- data.frame(Age = c(10, 20, NA, 40), Gender = c("F", "M", "F", NA),
                    Marker = c("None", "BRAF", "None", "BRAF"))
validation <- data.frame(Age = c(NA, 999), Gender = c("Unseen", "F"), Marker = c("None", "BRAF"))
prep <- fit_preprocessor(train)
stopifnot(prep$medians[["Age"]] == 20)
shaped <- shape_frame(prep, validation)
stopifnot(shaped$Age[1] == 20, as.character(shaped$Gender[1]) == "__NOVEL__",
          as.character(shaped$Marker[1]) == "None")
a <- transform_predictors(prep, train, "lr")
b <- transform_predictors(prep, validation, "lr")
stopifnot(identical(colnames(a), colnames(b)), all(is.finite(b)),
          abs(mean(a[, "Age"])) < 1e-12, prep$medians[["Age"]] == 20,
          is.factor(transform_predictors(prep, train, "rf")$Gender))
# Test-set values must not change fitted preprocessing parameters.
stopifnot(identical(prep, fit_preprocessor(train)))

raw <- read_project_data(find_project_root())
x <- make_predictors(raw)
stopifnot(!any(c("Outcome_Status", "Survival_Time_Months", "Patient_ID", "Treatment_Type",
                "Surgery_Status", "Radiation_Therapy", "Chemotherapy") %in% names(x)))
# Correct nearest-neighbor class probabilities and deterministic ties.
p <- knn_probabilities(matrix(c(0, 2, 10), ncol = 1), factor(classes, levels = classes),
                        matrix(c(0.1, 9.9), ncol = 1), k = 1, classes)
stopifnot(identical(as.character(probability_labels(p)), c("Active", "In.Remission")),
          all(rowSums(p) == 1))
# Tuning must fit only fold-training rows, not validation labels or values.
original_fit_predict <- fit_predict
fit_predict <- function(kind, train_x, train_y, new_x, param, seed) {
  stopifnot(!length(intersect(train_x$row_id, new_x$row_id)), nrow(train_x) == length(train_y))
  p <- matrix(1/3, nrow(new_x), 3, dimnames = list(NULL, levels(train_y)))
  p
}
t <- tune_model("lr", data.frame(row_id = seq_along(y[idx])), y[idx], folds, data.frame(decay = 1))
stopifnot(!anyNA(t$oof), nrow(t$oof) == length(idx))
fit_predict <- original_fit_predict
cat("PASS: splits, metrics, missing classes, fold isolation, imputation, encoding, scaling, predictors, kNN\n")
