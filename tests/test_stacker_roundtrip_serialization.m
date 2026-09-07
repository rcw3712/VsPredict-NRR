function result = test_stacker_roundtrip_serialization()
% TEST: save/load stacker and meta_scaler; predictions must be identical.
cfg=config_nrr_v5(); n=50; M=randn(n,4); y=1.5+rand(n,1);
ms=nrr_models.fit_meta_scaler(M);
Msc=nrr_models.apply_meta_scaler(M,ms);
stk=nrr_models.fit_ridge_stacker(Msc,y,0.01,cfg);
yp1=nrr_models.predict_ridge_stacker(stk,Msc);
tmp=fullfile(tempdir,'stk_test.mat'); save(tmp,'stk','ms','-v7.3');
L=load(tmp); yp2=nrr_models.predict_ridge_stacker(L.stk,...
    nrr_models.apply_meta_scaler(M,L.ms));
delete(tmp);
assert(max(abs(yp1-yp2))<1e-10,'round-trip mismatch');
result=struct('name','test_stacker_roundtrip_serialization','status','PASS','message','OK');
end
