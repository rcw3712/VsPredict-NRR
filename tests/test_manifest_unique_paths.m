function result = test_manifest_unique_paths()
% TEST: all FILE entries in manifest must be unique.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_manifest_unique_paths','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_manifest_unique_paths','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g,'TextType','string');
n_dup=height(T)-numel(unique(T.FILE));
if n_dup==0
    result=struct('name','test_manifest_unique_paths','status','PASS',...
        'message',sprintf('%d unique paths',height(T)));
else
    result=struct('name','test_manifest_unique_paths','status','FAIL',...
        'message',sprintf('%d duplicate paths',n_dup));
end
end
