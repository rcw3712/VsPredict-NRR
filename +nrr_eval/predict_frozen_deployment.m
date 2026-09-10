function [y_pred, pred_audit] = predict_frozen_deployment(deploy, T_B, cfg)
% NRR_EVAL.PREDICT_FROZEN_DEPLOYMENT  Segment-aware deployment prediction.
[X_B,~]=nrr_data.apply_pm_deploy(T_B,deploy.pm,cfg);
seg_B=nrr_data.depth_segment_ids(T_B.(cfg.data.depth_col),cfg);
[meta_B,pred_audit]=nrr_models.predict_base_set(deploy.base_nets,X_B,seg_B);
assert(pred_audit.N_RETAINED_CROSS_SEGMENT==0, ...
    'predict_frozen_deployment: cross-segment window retained');
meta_sc=nrr_models.apply_meta_scaler(meta_B,deploy.meta_scaler);
y_pred=nrr_models.predict_ridge_stacker(deploy.stacker,meta_sc);
assert(all(isfinite(y_pred)), ...
    'predict_frozen_deployment: NaN/Inf in predictions');
end
