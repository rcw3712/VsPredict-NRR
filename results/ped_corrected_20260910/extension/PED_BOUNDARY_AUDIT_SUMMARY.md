# CNN and Preprocessing Boundary Audit

**Verdict: PASS_SEGMENT_AWARE_LEDGER_VERIFIED**

CNN1D window=16 samples (2.4384m at 0.1524m sampling).

| Assertion | Status | Evidence |
|---|---|---|
| SPLIT_BEFORE_WINDOW | PASS | Canonical pipeline uses depth-blocked split first, then windowing |
| SCALER_FIT_TRAIN_ONLY | PASS | fold-local preprocessing confirmed: scaler fit on train partition only |
| NO_GLOBAL_NORMALIZATION | PASS | Preprocessing is fold-local per canonical pipeline design |
| CNN_WINDOW_SIZE_16 | PASS | CNN1D window=16 samples (2.44m at 0.1524m spacing) |
| NO_VALIDATION_IN_TRAIN | PASS | OOF design: each row predicted exactly once as validation |
| META_SCALER_OOF_ONLY | PASS | Meta-feature scaler fit on inner OOF predictions only |
