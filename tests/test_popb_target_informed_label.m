function result = test_popb_target_informed_label()
% TEST: Pop-B CSV must be labeled TARGET_INFORMED_DIAGNOSTIC_SUBSET.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_popb_target_informed_label','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'04_blind','DIAGNOSTIC_BLIND_EVALUATION_POP_B.csv');
if ~isfile(g)
    result=struct('name','test_popb_target_informed_label','status','FAIL',...
        'message','DIAGNOSTIC_BLIND_EVALUATION_POP_B.csv not found'); return
end
T=readtable(g);
assert(any(strcmp(T.STATUS,'TARGET_INFORMED_DIAGNOSTIC_SUBSET')),...
    'Pop-B not labeled TARGET_INFORMED_DIAGNOSTIC_SUBSET');
result=struct('name','test_popb_target_informed_label','status','PASS','message','OK');
end
