# Changelog

## 2026.09 PED corrected two-well analysis

- Corrected the same-well holdout path to use the canonical meta-feature scaler and stacker prediction API.
- Classified the superseded R² = −3.0622 result as `LEGACY_INVALID_RAW_META_SCALING`; corrected holdout R² is 0.3591.
- Added segment-aware CNN fitting and fail-closed rejection of cross-segment windows.
- Added the PED targeted extension, all-model external comparison, paired moving-block bootstrap, and physical-plausibility audit.
- Added non-sensitive aggregate outputs from canonical run `run_PED_corrected_20260910_071523` and extension manifest `ped_extension_run_PED_corrected_20260910_071523_20260910_114659`.
- Added run-labelled publication figures with a SHA-256 provenance manifest.
- Reframed this historically named repository as the umbrella project archive. Earlier releases remain immutable provenance snapshots and are not authoritative for the PED manuscript.

## v5.0.0 — corrected NRR reanalysis

- Replaced the v4 workflow with true 5×4 nested depth-blocked cross-validation.
- Enforced fold-local preprocessing and inner-OOF meta-feature scaling.
- Defined Pop-A as 329 depth-disjoint Well-B rows.
- Explicitly labeled Pop-B (n=236) as target-informed diagnostic.
- Locked the Ridge stacker as the historical primary model.
- Labeled Direct Ridge as post-hoc sensitivity only.
- Added exact multi-seed execution, block bootstrap, domain-shift diagnostics, physical-admissibility gates, frozen artifacts, SHA-256 manifests, and 44-check cross-run verification.
- Added canonical-aware publication figure generators and corrected FIG01–FIG08/FIGS1.
- Retained only non-sensitive aggregate reference outputs.

This release changes reported numerical results relative to v4. It is a corrected reanalysis, not a cosmetic revision.

## v4.0.0 — historical legacy submission

Historical v4 snapshot preserved for provenance; it is not the authoritative analysis for the NRR manuscript.
