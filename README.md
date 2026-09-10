# VsPredict cross-well shear-wave velocity archive

This repository is the project-history and reproducibility archive for the VsPredict cross-well shear-wave velocity study. The repository name `VsPredict-NRR` is historical: it now serves as an umbrella for earlier journal-target snapshots and the current analysis prepared for *Petroleum Exploration and Development* (PED).

Earlier tagged and branched snapshots remain available for provenance. They are not authoritative for the current PED manuscript.

## Current PED analysis

Manuscript working title:

> **Two-well evaluation of shear-wave velocity transfer under severe log-distribution shift: Validation hierarchy and physical-admissibility assessment**

This is a two-well calibration-to-blind-well study. It evaluates one transfer event and does not claim population-wide geological generalization.

| Item | Authoritative PED value |
|---|---:|
| Canonical corrected run | `run_PED_corrected_20260910_071523` |
| PED extension manifest | `ped_extension_run_PED_corrected_20260910_071523_20260910_114659` |
| Well-A development / same-well holdout | 392 / 100 |
| Shared-depth coordinates excluded | 163 |
| Primary blind population, Pop-A | 329 |
| Target-informed diagnostic population, Pop-B | 236 |
| Nested depth-blocked CV | 5 outer × 4 inner folds |
| Pooled outer-OOF R² / RMSE | 0.6386 / 0.0585 km/s |
| Mean outer-fold R² | 0.5152 ± 0.1675 |
| Corrected same-well holdout R² | 0.3591 |
| Pre-specified Ridge stacker Pop-A R² | −2.7331 |
| Pre-specified Ridge stacker Pop-A RMSE / bias | 0.4181 / +0.3768 km/s |
| Pre-specified Ridge stacker Pop-B R² | −5.4721 |
| Post-hoc Direct Ridge Pop-A R² | 0.6831 |
| DT shift z(B\|A) / KS | +7.85 / 1.000 |
| Ridge / Direct Ridge Pop-B ALL-OK | 0/236 / 236/236 |
| Clean-session cross-run checks | 44/44 PASS |

All four pre-specified base learners had negative Pop-A R². Direct Ridge was evaluated only after the primary model failed and is therefore a post-hoc sensitivity analysis, not a replacement confirmatory model.

## Corrected provenance

The earlier same-well holdout value R² = −3.0622 is classified as `LEGACY_INVALID_RAW_META_SCALING`. It used unscaled meta-features and bypassed the canonical stacker prediction API. It is retained only as software provenance and must not be used as a scientific result.

The corrected fixed-hyperparameter holdout result is R² = 0.3591. The corrected pipeline also propagates physical depth-segment identifiers to CNN fitting and rejects windows crossing disconnected training segments.

## Repository layout

```text
+nrr_data/                     shared loading, roles, folds, preprocessing
+nrr_models/                   base learners, segment-aware CNN, stacker
+nrr_eval/                     nested CV, blind evaluation, diagnostics
+nrr_report/                   report generation
ped_extension/                 PED targeted extension and audit gates
VsPredict_PED_Extension_Codex_v2/
                               fail-closed PED extension entry point
results/ped_corrected_20260910/
  canonical/                   non-sensitive canonical aggregate outputs
  extension/                   non-sensitive PED extension outputs
figures/ped-canonical-20260910/
                               run-labelled PNG/TIFF figures and manifest
tests/                         inherited integrity tests
run_ped_corrected_pipeline.m   corrected canonical pipeline entry point
selftest_ped_codex_patch_v3.m  fail-closed patch self-test
```

Legacy NRR-named MATLAB packages and paths are retained where renaming would break reproducibility of historical runs. Their names do not define the current journal target.

## Reproduction sequence

Requirements: MATLAB R2024a plus Statistics and Machine Learning Toolbox and Deep Learning Toolbox. Proprietary well logs are not distributed.

Place authorized inputs at:

```text
data/Well-A.xlsx
data/Well-B.xlsx
```

Run the patch self-test, then the corrected pipeline:

```matlab
clear classes
clear functions
rehash toolboxcache
selftest_ped_codex_patch_v3
result = run_ped_corrected_pipeline;
```

Create a second independent clean-session run and compare the two run IDs:

```matlab
result = run_reproducibility_check('run_ID_1', 'run_ID_2', pwd);
```

Run the PED targeted extension only after the corrected canonical run and cross-run verification pass:

```matlab
cd ped_extension
run_ped_targeted_extension
```

The committed aggregate outputs correspond to the run identifiers shown above. Row-level predictions, well logs, trained model binaries, and re-identification-sensitive artifacts are intentionally excluded.

## Figures

The publication figures are under [`figures/ped-canonical-20260910`](figures/ped-canonical-20260910). Every filename contains the canonical run ID, and `FIGURE_MANIFEST_SHA256.csv` records provenance and hashes.

- Figures 1 and 7 and Supplementary Fig. S1 were re-exported and are numerically unchanged because they depend only on audited raw logs, population masks, or distribution-shift statistics.
- Figures 2–6 and 8 were regenerated from corrected model outputs.
- Supplementary Fig. S2 was regenerated from corrected multiseed outputs.

## Archive and citation status

- GitHub: this repository is the project-history umbrella archive.
- Zenodo umbrella DOI: [`10.5281/zenodo.22637960`](https://doi.org/10.5281/zenodo.22637960).
- For the PED article, a dedicated versioned GitHub release and matching Zenodo version must cite both authoritative run identifiers and their SHA-256 manifests before publication.
- Earlier tags and snapshots do not reproduce the current PED manuscript values.

## Data policy

The well logs are proprietary and are not included. The public package contains source code, non-sensitive aggregate tables, configuration/provenance summaries, figure files, and cryptographic manifests. Independent numerical execution requires authorized access to the original inputs.

## License

Source code is released under the MIT License. The license does not apply to proprietary well-log data.
