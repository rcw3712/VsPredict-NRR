function result = test_geomech_all_ok_invariants()
% TEST: N_ALL_OK must not exceed any component gate count.
cfg=config_nrr_v5();
T=readtable(fullfile('runs','CANONICAL_RUN_POINTER.txt'),'ReadVariableNames',false);
run_id=strtrim(string(T{1,1})); run_id=run_id(1);
f=fullfile('runs',run_id,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv');
if ~isfile(f)
    result=struct('name','test_geomech_all_ok_invariants','status','FAIL',...
        'message','Geomech CSV not found — awaiting Gate 17'); return
end
T=readtable(f);
for ri=1:height(T)
    N=T.N_ALL_OK(ri);
    assert(N<=T.N_INPUT_OK(ri),'N_ALL_OK > N_INPUT_OK for %s',T.MODEL{ri});
    assert(N<=T.N_VPVS_OK(ri),'N_ALL_OK > N_VPVS_OK for %s',T.MODEL{ri});
    assert(N<=T.N_NU_OK(ri),'N_ALL_OK > N_NU_OK for %s',T.MODEL{ri});
    assert(N<=T.N_G_OK(ri),'N_ALL_OK > N_G_OK for %s',T.MODEL{ri});
end
result=struct('name','test_geomech_all_ok_invariants','status','PASS','message','OK');
end
