function y_pred = predict_frozen_deployment(deploy, T_B, cfg)
% NRR_EVAL.PREDICT_FROZEN_DEPLOYMENT  Single prediction API for any deployment.
%   Used by Gate 12, Gate 16, and round-trip tests.
%   deploy must have primary_locked checked before calling for Gate 12.

[X_B, ~] = nrr_data.apply_pm_deploy(T_B, deploy.pm, cfg);
meta_B   = nrr_models.predict_base_set(deploy.base_nets, X_B);
meta_sc  = nrr_models.apply_meta_scaler(meta_B, deploy.meta_scaler);
y_pred   = nrr_models.predict_ridge_stacker(deploy.stacker, meta_sc);

assert(all(isfinite(y_pred)), ...
    'predict_frozen_deployment: NaN/Inf in predictions');
end
