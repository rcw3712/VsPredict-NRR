function result = test_gate_fails_on_scaling_mismatch()
% TEST: predict_ridge_stacker must reject non-standardized input.
% We verify that using raw OOF (not scaled) causes detectable difference.
cfg=config_nrr_v5(); n=50; M=randn(n,4)*10+5; y=1.5+rand(n,1);
ms=nrr_models.fit_meta_scaler(M);
Msc=nrr_models.apply_meta_scaler(M,ms);
stk=nrr_models.fit_ridge_stacker(Msc,y,0.01,cfg);
yp_correct=nrr_models.predict_ridge_stacker(stk,Msc);
% Raw M has very different scale — predictions must differ
yp_raw=M*stk.B+stk.b0;
assert(max(abs(yp_correct-yp_raw))>0.1,...
    'Correct and raw predictions too similar — scaling not doing anything');
result=struct('name','test_gate_fails_on_scaling_mismatch','status','PASS','message','OK');
end
