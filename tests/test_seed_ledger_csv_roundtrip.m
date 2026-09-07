function result = test_seed_ledger_csv_roundtrip()
% TEST: SEED_LEDGER.csv must exist and have correct columns.
f = fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_seed_ledger_csv_roundtrip','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'00_environment','SEED_LEDGER.csv');
if ~isfile(g)
    result=struct('name','test_seed_ledger_csv_roundtrip','status','FAIL',...
        'message','SEED_LEDGER.csv not found'); return
end
T=readtable(g);
req_cols={'BASE_SEED','MODEL','DERIVED_SEED','FOLD_ID'};
missing={};
for ri=1:numel(req_cols)
    if ~ismember(req_cols{ri},T.Properties.VariableNames)
        missing{end+1}=req_cols{ri};
    end
end
if isempty(missing) && height(T)>0
    result=struct('name','test_seed_ledger_csv_roundtrip','status','PASS',...
        'message',sprintf('%d rows, all required columns present',height(T)));
else
    result=struct('name','test_seed_ledger_csv_roundtrip','status','FAIL',...
        'message',sprintf('missing cols: %s; rows=%d',strjoin(missing,','),height(T)));
end
end
