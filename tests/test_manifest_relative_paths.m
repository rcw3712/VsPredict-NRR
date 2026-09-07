function result = test_manifest_relative_paths()
% TEST: no absolute paths in manifest FILE column.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_manifest_relative_paths','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_manifest_relative_paths','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g,'TextType','string');
has_abs=any(startsWith(T.FILE,'/') | startsWith(T.FILE,'C:') | startsWith(T.FILE,'\\'));
if ~has_abs
    result=struct('name','test_manifest_relative_paths','status','PASS',...
        'message','All paths are relative');
else
    result=struct('name','test_manifest_relative_paths','status','FAIL',...
        'message','Absolute paths found in manifest');
end
end
