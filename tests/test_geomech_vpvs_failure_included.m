function result = test_geomech_vpvs_failure_included()
% TEST: if N_VPVS_OK=0 then N_ALL_OK must also be 0.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_geomech_vpvs_failure_included','status','FAIL',...
        'message','No canonical run — awaiting Gate 17'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv');
if ~isfile(g)
    result=struct('name','test_geomech_vpvs_failure_included','status','FAIL',...
        'message','Geomech CSV not found'); return
end
T=readtable(g);
for ri=1:height(T)
    if T.N_VPVS_OK(ri)==0
        assert(T.N_ALL_OK(ri)==0,...
            'N_VPVS_OK=0 but N_ALL_OK=%d for %s',T.N_ALL_OK(ri),T.MODEL{ri});
    end
end
result=struct('name','test_geomech_vpvs_failure_included','status','PASS','message','OK');
end
