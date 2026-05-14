# Pipeline Documentation

## Full CRISP-DM Pipeline

```
DATA UNDERSTANDING
├── 5,000 patients · 16 features · 3 outcome classes
├── Balanced classes: Active (32.3%), In Remission (33.5%), Deceased (34.2%)
├── 3 cancer types: Melanoma, Retinoblastoma, Lymphoma
└── One partially missing feature: Genetic_Markers (~50% absent)

DATA PREPARATION
├── Drop: Patient_ID, Date_of_Diagnosis (non-predictive)
├── Cast: Surgery_Status, Family_History → factor
├── Normalize outcome levels via make.names()
├── EDA: Pearson correlation heatmap, histograms, chi-squared tests
└── Feature Engineering
    ├── PCA → PC1, PC2 (top 2 components of numeric features)
    ├── LongSurvival → binary flag (above-median survival time)
    ├── AgeGroup → Young (<40) / Middle (40–60) / Senior (60+)
    └── AgeSurvInt → Age × Survival_Time_Months interaction

MODELING (stratified 70/30 split · 5-fold CV · macro-F1 objective)
│
├── 4.1 LOGISTIC REGRESSION
│   ├── Shaping: one-hot encode factors, center+scale numerics
│   ├── Tune: glmnet over α ∈ {0, 0.5, 1}, λ ∈ [0.001, 1] (10 values)
│   │   └── Best: α=0 (ridge), λ≈0.022
│   └── Ensemble: 30-bootstrap majority-vote bagging
│
├── 4.2 k-NEAREST NEIGHBORS
│   ├── Shaping: integer-encode factors, center+scale all numerics
│   ├── Tune: odd k from 5 to √N ≈ 59 via manual 5-fold CV
│   │   └── Best: k=15
│   └── Ensemble: 30-bootstrap majority-vote bagging
│
├── 4.3 RANDOM FOREST
│   ├── Shaping: native R factors, no scaling needed
│   ├── Tune: mtry from 1 to #predictors-1 via caret 5-fold CV
│   │   └── Best: mtry=3
│   └── Single tuned model (RF already bootstraps internally)
│
└── 4.4 XGBOOST
    ├── Shaping: sparse.model.matrix (auto one-hot), xgb.DMatrix
    ├── Tune: nrounds ∈ {50,100} × max_depth ∈ {4,6} × η ∈ {0.05,0.1}
    │   └── Best: nrounds=100, max_depth=6, η=0.05
    └── Single tuned model (XGBoost subsamples internally)

ENSEMBLE
├── 4.5 VOTING ENSEMBLE
│   ├── Inputs: glmnet, bagged-kNN, RF, XGBoost predictions
│   └── Method: row-wise majority vote
│
└── 4.6 STACKED META-LEARNER
    ├── Features: 4 base-learner predictions as inputs
    ├── Meta-model: multinomial logistic regression (nnet::multinom)
    └── Learns optimal weighting per region of feature space

EVALUATION
└── Primary metric: macro-averaged F1 (equal weight to all 3 classes)
    Secondary: accuracy, per-class sensitivity/specificity
    Rationale: accuracy misleading on balanced 3-class problem
```

## Why Macro-F1?

On a balanced 3-class problem, accuracy and macro-F1 can diverge when a model
performs well on one class at the expense of others. A model predicting only
"Deceased" would achieve ~34% accuracy — seemingly reasonable — while completely
failing Active and In Remission patients. Macro-F1 forces the model to balance
precision and recall across all three classes equally.

## Why Independent Preprocessing per Model?

Each algorithm has fundamentally different input requirements:

| Requirement | LR | kNN | RF | XGB |
|---|---|---|---|---|
| Numeric only | ✓ (one-hot) | ✓ (integer codes) | ✗ (handles factors) | ✓ (sparse matrix) |
| Centering/scaling | Required | Required | Not needed | Not needed |
| Factor levels consistent | Required | N/A | Required | N/A |

A shared preprocessing pipeline would force compromises that degrade at least
one model. Independent pipelines ensure each algorithm receives optimal input.
