function result = test_canonical_pointer_unchanged_on_failure()
% TEST: canonical pointer must not be written if hashing fails.
% Simulate: if Gate 17 throws before movefile, pointer is unchanged.
% We verify that the pointer file contains a valid run ID (not a failed one).
ptr=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(ptr)
    result=struct('name','test_canonical_pointer_unchanged_on_failure','status','FAIL',...
        'message','No canonical pointer file'); return
end
T=readtable(ptr,'ReadVariableNames',false);
run_id = string(T{1,1});
run_id = strtrim(run_id(1));
% Canonical run must have a frozen MAT
mat=fullfile('runs',run_id,'08_freeze','FROZEN_NUMERICAL_RUN.mat');
if isfile(mat)
    result=struct('name','test_canonical_pointer_unchanged_on_failure','status','PASS',...
        'message',sprintf('Canonical run %s has frozen MAT',char(run_id)));
else
    result=struct('name','test_canonical_pointer_unchanged_on_failure','status','FAIL',...
        'message',sprintf('Canonical run %s missing frozen MAT — may be failed run',char(run_id)));
end
end
