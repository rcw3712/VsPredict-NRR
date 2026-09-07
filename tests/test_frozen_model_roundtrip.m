function result = test_frozen_model_roundtrip()
% TEST: save/load deploy struct; predictions must be identical.
f = fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_frozen_model_roundtrip','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
mat=fullfile('runs',run_id,'08_freeze','FROZEN_MODEL_ARTIFACTS.mat');
if ~isfile(mat)
    result=struct('name','test_frozen_model_roundtrip','status','FAIL',...
        'message','FROZEN_MODEL_ARTIFACTS.mat not found'); return
end
cfg=config_nrr_v5();
L=load(mat,'deploy'); deploy=L.deploy;
T_B=readtable(fullfile('data','Well-B.xlsx'),'VariableNamingRule','preserve');
T_B=nrr_data.read_well(fullfile('data','Well-B.xlsx'),'B',cfg);
pred1=nrr_eval.predict_frozen_deployment(deploy,T_B,cfg);
tmp=fullfile(tempdir,'rt_test.mat'); save(tmp,'deploy','-v7.3');
L2=load(tmp,'deploy'); delete(tmp);
pred2=nrr_eval.predict_frozen_deployment(L2.deploy,T_B,cfg);
max_d=max(abs(pred1-pred2));
if max_d < 1e-10
    result=struct('name','test_frozen_model_roundtrip','status','PASS',...
        'message',sprintf('max_diff=%.2e',max_d));
else
    result=struct('name','test_frozen_model_roundtrip','status','FAIL',...
        'message',sprintf('max_diff=%.2e > 1e-10',max_d));
end
end
