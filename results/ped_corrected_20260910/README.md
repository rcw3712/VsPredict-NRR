# PED corrected reference outputs

This directory contains curated, non-sensitive outputs supporting the current manuscript prepared for *Petroleum Exploration and Development*.

## Authoritative identifiers

- Canonical corrected run: `run_PED_corrected_20260910_071523`
- PED extension manifest: `ped_extension_run_PED_corrected_20260910_071523_20260910_114659`
- Canonical provenance: `PED_CORRECTED_FULL_REANALYSIS`
- Cross-run verification: 44/44 checks PASS

## Directory scope

- `canonical/`: aggregate nested-CV, corrected holdout, blind-well, shift, bootstrap, multiseed, and geomechanical outputs.
- `extension/`: aggregate architecture, boundary, all-model transfer, paired-bootstrap, and physics audit outputs.

## Explicitly excluded

The public directory does not contain proprietary well logs, row-level prediction tables, row-level population membership, trained model binaries, full run archives, or failed/intermediate runs.

The run manifests list the complete local output inventory for provenance, but entries absent from this public directory remain restricted. Independent numerical execution therefore requires authorized access to the source well logs.

## Interpretation lock

The pre-specified primary model is the Ridge stacker. Direct Ridge is a post-hoc sensitivity analysis. Pop-A is the primary depth-disjoint blind population; Pop-B is target-informed and diagnostic.

The historical holdout value R² = −3.0622 is invalid for inference and is classified as `LEGACY_INVALID_RAW_META_SCALING`. The corrected fixed-hyperparameter holdout result is R² = 0.3591.
