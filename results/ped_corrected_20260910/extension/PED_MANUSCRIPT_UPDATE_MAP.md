# Manuscript Update Map

Maps EXT_GATE results to manuscript sections requiring update.

## Abstract
- Update if holdout classification changes three-level hierarchy claim
- Use only values read from the corrected frozen canonical run; do not retain legacy hard-coded metrics

## Methods
- EXT_GATE_3: Add architecture provenance table
- EXT_GATE_4: Add CNN boundary audit statement
- EXT_GATE_5: Clarify holdout is provenance, not v5 nested-CV test set
- EXT_GATE_10: Replace "stable isotropic media" with "application-specific sedimentary-rock screen"
- EXT_GATE_10: Add Vp formula: Vp (km/s) = 304.8 / DT (µs/ft)
- EXT_GATE_10: Add unit statement: rho (g/cm3) × V² (km/s)² = GPa

## Results
- EXT_GATE_1: Clarify 163-row classification (confirmed or revised)
- EXT_GATE_5: Add corrected holdout R² if positive (recovery) or negative (confirms three-level)
- EXT_GATE_6: Add external predictions for all base learners
- EXT_GATE_7: Add Full Well-B sensitivity if condition B
- EXT_GATE_8: Add DT interpretation limits paragraph

## Discussion
- EXT_GATE_5: Reconcile historical holdout R²=-3.0622
- EXT_GATE_6: Discuss whether failure is model-specific or universal
- EXT_GATE_9: Add paired bootstrap supporting Direct Ridge vs stacker difference
- EXT_GATE_10: Change "Geomechanical Consequences" to "Physical-Admissibility Consequences" if no wellbore calc

## Figures
- PED_FIG_VALIDATION_HIERARCHY: new figure (CV / same-well holdout / cross-well)
- PED_FIG_EXTERNAL_ALL_MODELS: new figure (all base learners external)
- PED_FIG_DT_SUPPORT: DT distribution with source support boundaries

## Do NOT change
- Canonical numerical results from run_PED_corrected_20260910_071523
- Primary analysis: Ridge stacker is pre-specified confirmatory model
- Direct Ridge: always POST_HOC_EXPLORATORY
