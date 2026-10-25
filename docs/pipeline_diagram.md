# Pipeline and assignment mapping

The outer split separates training patients from held-out test patients before
any learned transformation. The same patients appear in each model's version of
the training and test data; model-specific shaping does not create independent
random splits.

1. Validate IDs, outcome labels and ages; select conservative baseline predictors.
2. Make a fixed stratified 70/30 split and shared training-only folds.
3. Within each fold, learn preprocessing on fit rows, transform validation rows,
   fit each candidate and evaluate macro-F1. Select hyperparameters using those
   training-CV scores only.
4. Refit each selected learner on the full training partition and predict test
   features. Separately bootstrap training rows, refit preprocessing and each
   algorithm, and average probabilities into four homogeneous ensembles.
5. Average the homogeneous ensembles with equal weights for heterogeneous voting.
6. Fit the stack on OOF training probabilities from the selected unbagged learners.
   Apply the stack to their held-out probabilities. Test labels never train it.
7. Evaluate fixed models and ensemble rules against held-out labels. Export
   predictions, probabilities, metrics, folds, settings and package versions.

| Requirement | Implementation |
|---|---|
| At least three algorithms | Multinomial logistic regression, kNN, random forest, XGBoost |
| Shape data per algorithm | Scaled encoded matrices for LR/kNN, factors for RF, unscaled encoded matrix for XGBoost |
| Boosting and hyperparameter tuning | XGBoost; shared stratified training-CV grids for all algorithms |
| Bagging and homogeneous ensembles | 30 stratified bootstrap fits per algorithm in full mode |
| CRISP-DM | Question, data audit, preparation, modeling, evaluation and limitations in notebook |
| Heterogeneous ensemble | Soft voting plus separately evaluated OOF stacking |
| Appropriate evaluation | Untouched outer test, majority/random baselines, macro-F1, accuracy, precision/recall and class results |
| Code, journaling and interpretation | Notebook, visible method code, helper implementation and generated results |
| Dataset approval | External course record; not verified by this repository |

The OOF probabilities for stacking use hyperparameters selected within the outer
training partition. They are training features, not an unbiased performance
estimate after hyperparameter selection. All final comparisons use the outer test.
