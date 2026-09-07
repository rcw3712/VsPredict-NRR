function result = test_geomech_failure_reason_counts()
% TEST: number of FAIL rows equals N_EVAL - N_ALL_OK per model.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_geomech_failure_reason_counts','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
cmp_f=fullfile('runs',run_id,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv');
if ~isfile(cmp_f)
    result=struct('name','test_geomech_failure_reason_counts','status','FAIL',...
        'message','Geomech CSV not found'); return
end
T_cmp=readtable(cmp_f);
for ri=1:height(T_cmp)
    mn=T_cmp.MODEL{ri};
    row_f=fullfile('runs',run_id,'07_geomech',...
        sprintf('GEOMECH_ROW_LEVEL_%s.csv',upper(mn)));
    if ~isfile(row_f); continue; end
    T_row=readtable(row_f);
    n_fail_rows=sum(~strcmp(T_row.FAIL_REASONS,'PASS'));
    n_expected=T_cmp.N_EVAL(ri)-T_cmp.N_ALL_OK(ri);
    assert(n_fail_rows==n_expected,...
        '%s: fail rows=%d expected=%d',mn,n_fail_rows,n_expected);
end
result=struct('name','test_geomech_failure_reason_counts','status','PASS','message','OK');
end
