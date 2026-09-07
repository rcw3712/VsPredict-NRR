# NRR_NUMERICAL_RESULTS_SUMMARY

Run: run_20260903_155408 | Seed: 42

## Provenance
All results: V5_CORRECTED_REANALYSIS
P0-1 bug FIXED (meta_scaler consistent across fit/predict)
P0-2 bug FIXED (ALL_OK includes Vp/Vs gate)
P0-3: stacker lambda tuned via full stacked pipeline

## Internal CV (n_dev=392)
Pooled OOF R²=0.6632 RMSE=0.0565
Mean fold R²=0.5526±0.1246 SD

## Primary Blind (Pop-A, primary non-duplicate)
Ridge stacker R²=-2.6162 RMSE=0.4115 bias=+0.3699 (n=329)

## Diagnostic (Pop-B, target-informed)
Ridge stacker R²=-5.2708 (n=236)

## Post-Hoc Direct Ridge (POST_HOC_SENSITIVITY)
Pop-A R²=0.6831 (n=329)
Pop-B R²=0.6504 (n=236)
