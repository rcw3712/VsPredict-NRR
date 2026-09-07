# VsPredict-Geoenergy — corrected NRR v5

Reproducibility code and non-sensitive reference outputs for:

> Wibowo et al., **Cross-Well Shear-Wave Velocity Prediction under Severe Covariate Shift: External Validation and Geomechanical Consequences**. Manuscript prepared for *Natural Resources Research*.

This branch contains the corrected v5 analysis. The previous Geoenergy Science and Engineering submission is preserved in Git history and the `v4.0.0-gse-submission` tag.

## Scientific status

- Provenance class: `V5_CORRECTED_REANALYSIS`
- Canonical numerical run: `run_20260903_155408`
- Model development: Well-A only
- Primary external population: Pop-A, 329 depth-disjoint Well-B rows
- Diagnostic population: Pop-B, 236 rows; **target-informed**
- Primary model: Ridge stacker
- Direct Ridge: **post-hoc sensitivity only**, not confirmatory

Pop-A comprises 93 rows recorded as “Pop-A primary blind” plus the 236 Pop-B rows in the canonical role ledger. Pop-B uses measured Vp/Vs for physical screening and cannot be treated as a deployment-time population when measured Vs is unavailable.

## Canonical results

| Quantity | Corrected v5 value |
|---|---:|
| Well-A development / historical holdout | 392 / 100 |
| Shared-depth coordinates excluded | 163 |
| Nested depth-blocked CV | 5 outer × 4 inner folds |
| Pooled outer-OOF R² | 0.6632 |
| Pooled outer-OOF RMSE | 0.0565 km/s |
| Mean fold R² | 0.5526 ± 0.1246 |
| Ridge stacker Pop-A R² | −2.6162 |
| Ridge stacker Pop-B R² | −5.2708 |
| Direct Ridge Pop-A / Pop-B R² | 0.6831 / 0.6504 |
| DT shift z(B\|A) / KS | +7.85 / 1.000 |
| Ridge Pop-B ALL-OK | 0 / 236 |
| Direct Ridge Pop-B ALL-OK | 236 / 236 |
| Cross-run reproducibility | 44 / 44 checks PASS |

Negative external R² is a primary scientific result, not a software failure. Direct Ridge results are exploratory because the model was assessed after the primary analysis was locked.

## Repository structure

```text
run_pipeline.m
main_nrr_pipeline.m
run_reproducibility_check.m
config/config_nrr_v5.m
+nrr_data/       loading, role definition, folds, fold-local preprocessing
+nrr_models/     base learners, stacker, and post-hoc Direct Ridge
+nrr_eval/       nested CV, blind evaluation, diagnostics, bootstrap, freeze
+nrr_report/     post-Gate-18 report generation
figure_scripts/  canonical-aware publication figure generators
figures/publication/
tests/
results/reference_outputs_v5/
```

## Reproducing the analysis

Requirements: MATLAB R2024a and the required Statistics and Machine Learning, Deep Learning, and related toolboxes.

Place authorized input files at:

```text
data/Well-A.xlsx
data/Well-B.xlsx
```

The expected schema is defined in `config/config_nrr_v5.m`. Then run:

```matlab
clear classes
run_pipeline
```

Run a second independent clean MATLAB session, then compare the two run IDs:

```matlab
result = run_reproducibility_check('run_ID_1','run_ID_2',pwd);
```

Generate reports only after Gate 18 passes:

```matlab
nrr_report.generate_all('runs/run_ID_2',pwd);
```

After a canonical run is available locally, execute the 34 fail-hard repository checks:

```matlab
summary = run_integrity_tests();
```

## Data and artifact policy

The well logs are proprietary and are not included. Trained model binaries, complete run folders, failed runs, row-level predictions, and row-level geomechanical files are also excluded. The repository provides non-sensitive aggregate tables, configuration metadata, canonical hashes, figures, and source code.

The included summary outputs permit verification of reported values but do not make the analysis independently executable without authorized input data. This limitation must remain explicit in the manuscript and archive metadata.

## Versioning

- `v4.0.0-gse-submission`: historical GSE/v4 snapshot.
- `v5.0.0-nrr-corrected-reanalysis`: corrected NRR analysis after release.
- Future releases must not rewrite or replace earlier tagged versions.
- A new Zenodo version should be minted from the v5 release.

## License

Source code is released under the MIT License. The license does not apply to proprietary well-log data.
