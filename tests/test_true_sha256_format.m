function result = test_true_sha256_format()
% TEST: all entries in RUN_MANIFEST_SHA256.csv must be 64-char hex.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_true_sha256_format','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_true_sha256_format','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g);
bad=cellfun(@(h)isempty(regexp(h,'^[a-f0-9]{64}$','once')),T.SHA256);
if any(bad)
    result=struct('name','test_true_sha256_format','status','FAIL',...
        'message',sprintf('%d entries not valid SHA-256',sum(bad))); return
end
result=struct('name','test_true_sha256_format','status','PASS','message','OK');
end
