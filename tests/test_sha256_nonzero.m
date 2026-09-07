function result = test_sha256_nonzero()
% TEST: manifest must not contain zero-placeholder hashes.
f = fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_sha256_nonzero','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_sha256_nonzero','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g); zero_h=repmat('0',1,64);
n_zero=sum(strcmpi(T.SHA256,zero_h));
if n_zero==0
    result=struct('name','test_sha256_nonzero','status','PASS',...
        'message',sprintf('%d entries, 0 zeros',height(T)));
else
    result=struct('name','test_sha256_nonzero','status','FAIL',...
        'message',sprintf('%d zero-placeholder hashes found',n_zero));
end
end
