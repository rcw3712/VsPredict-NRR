# PED Targeted Extension Summary

**Run:** `ped_extension_run_PED_corrected_20260910_071523_20260910_114659`

**Canonical:** `run_PED_corrected_20260910_071523` | Seed 42 | PED_CORRECTED_FULL_REANALYSIS

**Overall: PASS (12 PASS, 1 valid conditional skip, 0 FAIL, 0 BLOCKED)**

## Gate Summary

| Gate | Status | Notes |
|---|---|---|
| EXT_GATE_0 | PASS | Required canonical artifacts verified; manifest: 145/154 unchanged, 0 missing, 0 MAT warns, 9 extension-source version changes |
| EXT_GATE_1 | PASS | 492/492 rows classified; 163 PRED+TGT_EXACT |
| EXT_GATE_2 | PASS | 163 PREDICTOR_AND_TARGET_EXACT found — Condition A applies. |
| EXT_GATE_3 | PASS | 10 components documented; PNN_spread and Ridge_lambda INNER_CV_TUNED |
| EXT_GATE_4 | PASS | Segment-aware source contract plus canonical execution ledgers verified; 495 cross-segment windows discarded and 0 retained |
| EXT_GATE_5 | PASS | Corrected canonical holdout verified: Ridge R2=0.3591; legacy result invalidated |
| EXT_GATE_6 | PASS | All six frozen-model predictions verified; verdict=DIRECT_RIDGE_TRANSFERS_WHILE_STACKER_FAILS |
| EXT_GATE_7 | SKIPPED_BY_VALID_DECISION | Condition A: Full Well-B sensitivity excluded because 163 predictor-and-target-exact shared rows would mix duplicated evidence into the sensitivity set |
| EXT_GATE_8 | PASS | 4 features diagnosed; DT z=7.85 reproduced |
| EXT_GATE_9 | PASS | Paired moving-block bootstrap completed for Ridge stacker versus Direct Ridge |
| EXT_GATE_10 | PASS | Physics formulas, units, Pop-B alignment, and application-specific interpretation verified |
| EXT_GATE_11 | PASS | PED extension artifacts frozen with dynamic canonical provenance |
| EXT_GATE_12 | PASS | Extension summary, manuscript update map, and figure source data generated |

## Duplicate Forensic (EXT_GATE_1)

| Class | Count |
|---|---|
| PREDICTOR_AND_TARGET_EXACT | 163 |
| PREDICTOR_EXACT | 0 |
| DEPTH_MATCH_ONLY | 0 |
| ROW_ID_COLLISION | 0 |
| NO_MATCH | 329 |

## Population Decision (EXT_GATE_2)

**Condition A** — 163 PREDICTOR_AND_TARGET_EXACT found — Condition A applies.

Full Well-B valid for sensitivity: **false**


## Corrected Holdout (EXT_GATE_5)

| Metric | Value |
|---|---|
| R² | 0.3591 |
| RMSE | 0.1147 km/s |
| Classification | CORRECTED_CANONICAL_RIDGE_STACKER_VERIFIED |
| Historical R² (provenance) | -3.0622 |

## External Models (EXT_GATE_6)

**Verdict: DIRECT_RIDGE_TRANSFERS_WHILE_STACKER_FAILS**

| Model | Status | Pop-A R² |
|---|---|---|
| PNN | PRESPECIFIED_BASE | -3.3387 |
| MLFFNN | PRESPECIFIED_BASE | -3.5039 |
| DFFNN | PRESPECIFIED_BASE | -214.6054 |
| CNN1D | PRESPECIFIED_BASE | -142.1181 |
| Ridge_stacker | PRESPECIFIED_PRIMARY | -2.7331 |
| Direct_Ridge | POST_HOC_SENSITIVITY | 0.6831 |
