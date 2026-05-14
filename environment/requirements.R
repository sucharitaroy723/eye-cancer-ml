# requirements.R
# Run this script once in your R console to install all required packages.
# Usage: source("environment/requirements.R")

required_packages <- c(
  # Core ML
  "caret",          # unified ML interface, cross-validation
  "randomForest",   # random forest (tuned mtry)
  "xgboost",        # gradient boosting
  "glmnet",         # penalized logistic regression (ridge/lasso/elastic-net)
  "nnet",           # multinomial logistic regression (multinom)
  "class",          # k-nearest neighbors (knn)
  # Metrics
  "MLmetrics",      # F1_Score and multiclass metrics
  # Data manipulation
  "dplyr",
  "tidyr",
  "readr",
  # Visualization
  "ggplot2",
  "corrplot",
  # Reporting
  "rmarkdown",
  "knitr"
)

new_packages <- required_packages[
  !(required_packages %in% installed.packages()[, "Package"])
]

if (length(new_packages) > 0) {
  message("Installing missing packages: ", paste(new_packages, collapse = ", "))
  install.packages(new_packages, dependencies = TRUE)
} else {
  message("All required packages are already installed.")
}

# Load all to verify no errors
invisible(lapply(required_packages, library, character.only = TRUE))
message("All packages loaded successfully.")
