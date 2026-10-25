# Run once explicitly: Rscript environment/requirements.R
# Package installation never happens automatically inside the analysis notebook.
required <- c("nnet", "randomForest", "xgboost", "rmarkdown", "knitr")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
stopifnot(all(vapply(required, requireNamespace, logical(1), quietly = TRUE)))
message("Dependencies available. Actual versions are recorded in each run's sessionInfo.txt.")
