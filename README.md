# Eye Cancer Outcome Prediction · Ensemble Machine Learning

![R](https://img.shields.io/badge/Language-R-276DC3?logo=r&logoColor=white)
![ML](https://img.shields.io/badge/Task-Multiclass%20Classification-brightgreen)
![Dataset](https://img.shields.io/badge/Dataset-5%2C000%20patients-blue)
![Status](https://img.shields.io/badge/Status-Complete-success)

Predicting clinical outcomes (**Active · In Remission · Deceased**) in eye cancer patients using a full ensemble machine learning pipeline in R — from raw data to stacked meta-learner.

---

## Table of Contents
- [Project Overview](#project-overview)
- [Dataset](#dataset)
- [Pipeline Summary](#pipeline-summary)
- [Results](#results)
- [Repository Structure](#repository-structure)
- [How to Reproduce](#how-to-reproduce)
- [Key Design Decisions](#key-design-decisions)
- [Limitations & Future Work](#limitations--future-work)
- [Author](#author)

---

## Project Overview

This project was completed as the signature term project for **DA5030 – Data Mining & Machine Learning** at Northeastern University (Summer 2025). It implements a full CRISP-DM pipeline to predict three-class patient outcomes for eye cancer (Retinoblastoma, Melanoma, Lymphoma) using clinical and demographic features.

**Clinical motivation:** Accurate outcome prediction across Active/In Remission/Deceased classes can inform follow-up scheduling, resource allocation, and treatment planning — but only if the model performs equally well across all three classes, not just the majority. This is why macro-averaged F1 was used as the primary metric throughout.

---

## Dataset

| Property | Value |
|---|---|
| Source | [Kaggle – Eye Cancer Patient Records](https://www.kaggle.com/datasets/ak0212/eye-cancer-patient-records) |
| Patients | 5,000 |
| Features | 16 (clinical, demographic, treatment) |
| Target | `Outcome_Status` (3 classes) |
| Missing data | `Genetic_Markers` only (~50%) |
| License | Public / Kaggle open dataset |

**Feature overview:**

| Feature | Type | Description |
|---|---|---|
| Age | Numeric | Patient age (range: 1–90, mean: 45) |
| Gender | Categorical | M / F / Other |
| Cancer_Type | Categorical | Retinoblastoma, Melanoma, Lymphoma |
| Stage_at_Diagnosis | Ordinal | Stage I–IV |
| Treatment_Type | Categorical | Surgery, Chemotherapy, Radiation |
| Surgery_Status | Boolean | Whether surgery was performed |
| Radiation_Therapy | Numeric | Radiation sessions |
| Chemotherapy | Numeric | Chemotherapy cycles |
| Survival_Time_Months | Numeric | Follow-up duration (1–120 months) |
| Genetic_Markers | Categorical | BRAF Mutation or absent (~50% missing) |
| Family_History | Boolean | Family history of cancer |
| Country | Categorical | 10 countries |
| Laterality | Categorical | Left / Right / Bilateral |

**Class distribution (balanced by design):**

| Outcome | Count | % |
|---|---|---|
| Active | 1,615 | 32.3% |
| In Remission | 1,675 | 33.5% |
| Deceased | 1,710 | 34.2% |

> **Note on F1 scores:** The balanced class distribution and the limited discriminative power of available features (demographics and treatment type do not strongly predict outcome in this dataset) mean that F1 scores in the 0.31–0.36 range are expected — a random baseline on a balanced 3-class problem scores ~0.33. The value of this project lies in the pipeline methodology, not the absolute metric value.

---

## Pipeline Summary

```
Raw CSV
  └─ Data cleaning & type casting
      └─ Exploratory data analysis (correlation, chi-squared)
          └─ Feature engineering
          │    ├─ PCA (PC1, PC2 — top 2 components)
          │    ├─ LongSurvival flag (above median survival)
          │    ├─ AgeGroup bins (Young / Middle / Senior)
          │    └─ AgeSurvInt (Age × Survival interaction)
          └─ Per-model data shaping
               ├─ Median imputation + ±3σ outlier capping
               └─ Model-specific encoding (dummy / scaled / factor)

Modeling (stratified 70/30 split, 5-fold CV, macro-F1 objective)
  ├─ 4.1 Penalized Multinomial Logistic Regression (glmnet)
  │    └─ Bagged ensemble (30 bootstraps)
  ├─ 4.2 k-Nearest Neighbors (tuned k=15)
  │    └─ Bagged ensemble (30 bootstraps)
  ├─ 4.3 Random Forest (tuned mtry)
  └─ 4.4 XGBoost (tuned nrounds, max_depth, eta)

Ensemble
  ├─ 4.5 Heterogeneous voting ensemble (majority vote, 4 models)
  └─ 4.6 Stacked meta-learner (multinomial logit on base predictions)
```

---

## Results

| Model | Macro-F1 | Accuracy | Notes |
|---|---|---|---|
| Logistic Regression (glmnet) | 0.510 | 0.342 | α=0, λ≈0.022 |
| Bagged LR | ~0.51 | ~0.34 | 30 bootstraps |
| kNN (k=15, bagged) | 0.309 | 0.315 | 30 bootstraps |
| Random Forest (mtry=3) | 0.312 | — | 5-fold CV tuned |
| XGBoost | 0.328 | — | nrounds=100, depth=6, η=0.05 |
| Voting Ensemble | 0.313 | — | 4-model majority vote |
| **Stacked Ensemble** | **0.363** | — | **Best overall** |

**Key finding:** The stacked meta-learner outperforms all individual models. Penalized logistic regression (ridge, α=0) achieved the highest single-model macro-F1, suggesting that the decision boundary in this feature space is largely linear. Tree-based methods (RF, XGBoost) did not dramatically outperform the linear baseline — consistent with the limited non-linear signal in the dataset's available features.

---

## Repository Structure

```
eye-cancer-ml/
├── README.md                          # This file
├── environment/
│   ├── environment.yml                # Conda environment (R + packages)
│   └── requirements.R                 # R package install script
├── data/
│   └── eye_cancer_patients.csv        # Full dataset (5,000 patients)
├── src/
│   └── RoyS_DA5030_EyeCancerML.Rmd   # Full analysis — run this
├── results/
│   └── model_comparison.csv           # Summary metrics table
├── docs/
│   └── pipeline_diagram.md            # Annotated pipeline description
└── .gitignore
```

---

## How to Reproduce

### Option A — Conda (recommended)

```bash
# 1. Clone the repository
git clone https://github.com/sucharita-roy/eye-cancer-ml.git
cd eye-cancer-ml

# 2. Create and activate the environment
conda env create -f environment/environment.yml
conda activate eye-cancer-ml

# 3. Open RStudio and knit the Rmd
#    File → Open → src/RoyS_DA5030_EyeCancerML.Rmd → Knit
```

### Option B — R only

```r
# Run this once in your R console to install all required packages
source("environment/requirements.R")

# Then open and knit:
# src/RoyS_DA5030_EyeCancerML.Rmd
```

### Expected runtime
~10–20 minutes on a standard laptop (dominated by 5-fold CV for RF and XGBoost).

---

## Key Design Decisions

**Why macro-averaged F1 as the metric?**
With three near-equal classes (~33% each), accuracy is insufficient — a model predicting only "Deceased" would score 34% accuracy while being clinically useless for Active and In Remission patients. Macro-F1 gives equal weight to all three classes.

**Why independent data shaping pipelines per model?**
Each algorithm has different requirements: logistic regression needs centering/scaling and one-hot encoding; kNN needs numeric-only integer-coded features; RF handles factors natively; XGBoost requires sparse matrices. Using a single shared preprocessing step would force compromises that hurt at least one model.

**Why bagging for LR and kNN but not RF/XGBoost?**
RF and XGBoost already include internal bootstrapping/subsampling as part of their algorithms. Bagging LR and kNN provides the variance reduction those methods lack natively.

**Why stacking over voting?**
The voting ensemble treats all four models equally. The stacked meta-learner learns which models to trust more in each region of feature space — for example, favoring LR for linear patterns and RF for interaction effects.

---

## Limitations & Future Work

- **Feature scope:** Country, laterality, and gender have low discriminative power for outcome prediction. Tumor size, histology, and molecular markers (when available) would likely drive stronger signal.
- **Genetic_Markers missingness:** ~50% of this column is absent. A dedicated imputation strategy or a missingness indicator feature may help.
- **SMOTE / class weighting:** Despite near-balanced classes, per-class recall varied. Oversampling minority errors could improve consistency.
- **External validation:** The pipeline should be tested on an independent cohort to assess generalizability.
- **Interpretability:** Adding SHAP value analysis (via `shapr` or `iml`) would make predictions explainable for clinical stakeholders.

---

## Author

**Sucharita Roy**
M.S. Bioinformatics, Northeastern University (Expected May 2027)
[LinkedIn](https://linkedin.com/in/sucharita-roy) · [GitHub](https://github.com/sucharita-roy)

*Course: DA5030 – Data Mining & Machine Learning, Full Summer Semester 2025*
