function result = test_meta_scaler_fit_on_oof_only()
% TEST: applying wrong scaler must produce different (wrong) predictions.
n=50; M_tr=randn(n,4); M_val=randn(n,4)+5; y=1.5+rand(n,1);
cfg=config_nrr_v5();
ms_tr=nrr_models.fit_meta_scaler(M_tr);
ms_val=nrr_models.fit_meta_scaler(M_val);
Msc_tr=nrr_models.apply_meta_scaler(M_tr,ms_tr);
stk=nrr_models.fit_ridge_stacker(Msc_tr,y,0.01,cfg);
Msc_wrong=nrr_models.apply_meta_scaler(M_val,ms_tr);
Msc_right=nrr_models.apply_meta_scaler(M_val,ms_val);
yp_wrong=nrr_models.predict_ridge_stacker(stk,Msc_wrong);
yp_right=nrr_models.predict_ridge_stacker(stk,Msc_right);
assert(max(abs(yp_wrong-yp_right))>1e-6,'wrong and right scalers give same result');
result=struct('name','test_meta_scaler_fit_on_oof_only','status','PASS','message','OK');
end
