# Eye cancer outcome classification

A CRISP-DM course project comparing four classifiers and their ensembles on a
5,000-record teaching dataset. The original notebook describes the dataset as
simulated; this is an educational modeling exercise, not a validated clinical
prediction system.

The corrected analysis uses a shared stratified 70/30 split, training-only
preprocessing and cross-validation, homogeneous bootstrap ensembles for every
algorithm, heterogeneous soft voting, and a stack trained on out-of-fold training
predictions. No test labels are used for tuning or ensemble training.

## Read the analysis

- [R Notebook with explanations and code](src/RoyS_DA5030_EyeCancerML.Rmd)
- [Rendered full analysis](docs/report.html)
- [Full held-out results](results/full/model_comparison.csv)
- [Per-class metrics](results/full/per_class_metrics.csv)
- [Pipeline and assignment mapping](docs/pipeline_diagram.md)

The full-run CSV and rendered report are the current results. Earlier values in
Git history were retired because their stacking evaluation and metric reporting
were unreliable. Smoke outputs are validation artifacts, not final performance.

## Corrected full-run finding

The bagged random forest has the highest macro-F1 among trained models (0.340),
while the stratified-random baseline scores 0.342. Corrected stacking scores
0.252. None of the trained models exceeds the random baseline on this split.
These results provide no evidence of useful patient-specific prediction in this
teaching exercise; the project demonstrates the modeling and evaluation process.
The full output table reports accuracy and class-sensitive metrics for every model.

## Models and data shaping

| Learner | Representation | Tuning |
|---|---|---|
| Multinomial logistic regression (`nnet`) | One-hot categories and scaled numeric matrix | Decay penalty |
| kNN | One-hot categories and scaled numeric matrix | Neighbor count |
| Random forest | Imputed numeric columns and categorical factors | Features per split |
| XGBoost | One-hot numeric matrix, without scaling | Depth and learning rate |

Random-forest trees have a fixed minimum terminal-node size of 10 and at most
64 terminal nodes; these limits are set before test evaluation.

Every training fold fits its own imputation, category mapping, zero-variance
filter, and scaling. The same applies to each bootstrap replica. Logistic
regression uses the same regularized implementation for both the individual and
bagged model. PCA was removed rather than reused from the old pre-split fit.

The full experiment fits 30 stratified bootstrap replicas per algorithm. Outer
bagging of random forests is redundant with their internal bootstrap trees but
included to make the assignment's per-algorithm homogeneous-ensemble requirement
explicit. XGBoost supplies boosting. Soft voting averages the four bagged models;
the separate stack uses training-only OOF probabilities from four unbagged models.

## Reproduce

```bash
git clone https://github.com/sucharitaroy723/eye-cancer-ml.git
cd eye-cancer-ml
conda env create -f environment/environment.yml
conda activate eye-cancer-ml
Rscript tests/test_pipeline.R
Rscript scripts/run_analysis.R --smoke
Rscript scripts/run_analysis.R
Rscript -e 'rmarkdown::render("src/RoyS_DA5030_EyeCancerML.Rmd", output_file="report.html", output_dir="docs")'
```

The environment pins R 4.3.3 and XGBoost 1.7.7.1. Alternatively, with a compatible
current R installation, explicitly run `Rscript environment/requirements.R`.
The analysis does not install packages automatically. You can also open and knit
the notebook in RStudio; no active source-editor API is needed.

To render the report after running the CLI without refitting all models:

```r
rmarkdown::render(
  "src/RoyS_DA5030_EyeCancerML.Rmd",
  output_file = "report.html", output_dir = "docs",
  params = list(smoke = FALSE, rerun = FALSE)
)
```

This checks saved data/code fingerprints. The CLI's local `analysis.rds` is not
tracked; regenerate it before using `rerun = FALSE` on a fresh checkout.

Each output directory has a run-status marker, split assignments, tuning tables,
held-out predictions and probabilities, aggregate and per-class metrics, a run
configuration, and package session information. Interpret outputs only when
`run_status.txt` says `COMPLETE`. The full and smoke runs use separate directories.

## Scope and limitations

- Source listing: [Kaggle Eye Cancer Patient Records](https://www.kaggle.com/datasets/ak0212/eye-cancer-patient-records).
  Confirm the source's provenance and license terms before reuse. Public access
  is not itself a license. Dataset approval must be confirmed from course records.
- The target is recorded outcome status, not a defined time-to-event endpoint.
  Survival duration and treatment variables are excluded because their timing is
  not established. There is no claim of a validated prediction-at-diagnosis model.
- Literal `None` marker values are retained as a recorded category, not silently
  treated as missing. A data dictionary is needed for biological interpretation.
- One held-out split provides a descriptive comparison. No ensemble is assumed to
  win, and the highest observed test score is not proof of statistical superiority.
- Majority and stratified-random baselines use training class counts. No clinical
  usefulness, external validation, or fairness across subgroups is established.

## Files

- `src/ml_pipeline.R`: preprocessing, models, tuning, ensembles, metrics and exports.
- `src/RoyS_DA5030_EyeCancerML.Rmd`: narrated notebook, method code and interpretation.
- `scripts/run_analysis.R`: reproducible command-line entry point.
- `tests/test_pipeline.R`: targeted regression checks for the corrected behavior.
- `results/full/`: full-data held-out outputs; `results/smoke/`: small-run validation.
- `docs/report.html`: rendered notebook with full results.

Sucharita Roy · M.S. Bioinformatics, Northeastern University · Expected December 2026
