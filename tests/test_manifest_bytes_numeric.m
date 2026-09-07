function result = test_manifest_bytes_numeric()
% TEST: BYTES column must be finite and non-negative.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_manifest_bytes_numeric','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_manifest_bytes_numeric','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g);
if all(isfinite(T.BYTES) & T.BYTES>=0)
    result=struct('name','test_manifest_bytes_numeric','status','PASS',...
        'message',sprintf('%d rows, all BYTES valid',height(T)));
else
    result=struct('name','test_manifest_bytes_numeric','status','FAIL',...
        'message',sprintf('%d invalid BYTES entries',sum(~isfinite(T.BYTES)|T.BYTES<0)));
end
end
