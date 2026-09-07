function result = test_manifest_excludes_itself()
% TEST: RUN_MANIFEST_SHA256.csv must not appear in its own FILE column.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_manifest_excludes_itself','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_manifest_excludes_itself','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g,'TextType','string');
files=string(T.FILE);
self_refs=files(contains(files,'RUN_MANIFEST_SHA256'));
if isempty(self_refs)
    result=struct('name','test_manifest_excludes_itself','status','PASS',...
        'message','No self-reference found');
else
    result=struct('name','test_manifest_excludes_itself','status','FAIL',...
        'message',sprintf('Self-reference found: %s',self_refs(1)));
end
end
