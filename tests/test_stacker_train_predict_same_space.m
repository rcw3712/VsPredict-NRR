function result = test_stacker_train_predict_same_space()
% TEST: stacker must be trained and predicted in the same (standardized) space.
cfg = config_nrr_v5();
n=50; M=randn(n,4); y=1.5+rand(n,1);
ms=nrr_models.fit_meta_scaler(M);
Msc=nrr_models.apply_meta_scaler(M,ms);
stk=nrr_models.fit_ridge_stacker(Msc,y,0.01,cfg);
assert(strcmp(stk.input_space,'standardized_meta'),...
    'stacker.input_space must be standardized_meta');
yp=nrr_models.predict_ridge_stacker(stk,Msc);
assert(all(isfinite(yp)),'predictions not finite');
result=struct('name','test_stacker_train_predict_same_space','status','PASS','message','OK');
end
