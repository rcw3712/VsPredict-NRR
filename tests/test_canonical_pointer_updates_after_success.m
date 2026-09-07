function result = test_canonical_pointer_updates_after_success()
% TEST: canonical pointer must point to a run with Gate 17 PASS in frozen MAT.
ptr=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(ptr)
    result=struct('name','test_canonical_pointer_updates_after_success','status','FAIL',...
        'message','No canonical pointer'); return
end
T=readtable(ptr,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
mat=fullfile('runs',run_id,'08_freeze','FROZEN_NUMERICAL_RUN.mat');
if ~isfile(mat)
    result=struct('name','test_canonical_pointer_updates_after_success','status','FAIL',...
        'message','No frozen MAT for canonical run'); return
end
R=load(mat,'run');
if isfield(R.run.gate,'GATE_17') && strcmp(R.run.gate.GATE_17,'PASS')
    result=struct('name','test_canonical_pointer_updates_after_success','status','PASS',...
        'message',sprintf('GATE_17=PASS in %s',run_id));
else
    result=struct('name','test_canonical_pointer_updates_after_success','status','FAIL',...
        'message',sprintf('GATE_17 not PASS in %s',run_id));
end
end
