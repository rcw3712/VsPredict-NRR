# Model Architecture Provenance

Only PNN spread and Ridge lambda were tuned within inner folds.
Neural network architectures were fixed from prior development.

**Implication:** Nested CV applies to the selected hyperparameters, not to the full architecture-development process.

| Component | Value | Status |
|---|---|---|
| PNN_spread | 0.50 | INNER_CV_TUNED |
| Ridge_lambda | 0.001 | INNER_CV_TUNED |
| MLFFNN_layers | [64,32] | FIXED_FROM_PRIOR_DEVELOPMENT |
| DFFNN_layers | [128,64,32] | FIXED_FROM_PRIOR_DEVELOPMENT |
| CNN1D_filters | 32 | FIXED_FROM_PRIOR_DEVELOPMENT |
| CNN1D_window | 16 | FIXED_FROM_PRIOR_DEVELOPMENT |
| learning_rate | 1e-3 | FIXED_FROM_PRIOR_DEVELOPMENT |
| Direct_Ridge_lam | 1.0 | POST_HOC_EXPLORATORY |
| feature_set | GR,DT,NPHI,RHOB | FIXED_A_PRIORI |
| resampling_rule | 0.1524m | FIXED_A_PRIORI |
