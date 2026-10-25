# Validation record

Validated on October 25, 2026 with R 4.3.3, nnet 7.3-19, randomForest
4.7-1.1 and XGBoost 1.7.7.1. Full package details are in the run outputs.

- Targeted R regression checks passed for split stratification, fold isolation,
  imputation, unseen-category encoding, scaling, excluded predictors, kNN
  probabilities, and hand-calculated metrics including an unpredicted class.
- Smoke run completed: 210 training and 90 held-out records; three CV folds and
  two bootstrap replicas for each of four algorithms.
- Full run completed: 3,499 training and 1,501 held-out records; five CV folds
  and 30 bootstrap replicas for each algorithm.
- Independently recomputed accuracy, macro-F1, macro precision and macro recall
  from both runs' exported predictions using scikit-learn 1.8.0. All 12 rows
  in each comparison matched within 1e-12.
- Checked patient-ID partition separation and exported probability validity.
  Predicted labels agree with probability maxima within CSV rounding tolerance.
- Rendered both notebook modes. The full report includes generated interpretation,
  all figures, and the visible stacking implementation.

The tested local runtime used the stated package versions. The supplied conda
environment file was not independently solved during this session. Dataset
approval and source licensing remain external records, not code-validation claims.
