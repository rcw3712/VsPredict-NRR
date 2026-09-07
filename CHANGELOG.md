# Changelog

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
