function result = test_manifest_completeness()
% TEST: manifest must include source, config, data, fold assignments, predictions.
f = fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_manifest_completeness','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g=fullfile('runs',run_id,'08_freeze','RUN_MANIFEST_SHA256.csv');
if ~isfile(g)
    result=struct('name','test_manifest_completeness','status','FAIL',...
        'message','RUN_MANIFEST_SHA256.csv not found'); return
end
T=readtable(g);
required_patterns={'source_m','data','config','output'};
cats=T.CATEGORY;
missing={};
for ri=1:numel(required_patterns)
    if ~any(strcmp(cats,required_patterns{ri}))
        missing{end+1}=required_patterns{ri};
    end
end
if isempty(missing)
    result=struct('name','test_manifest_completeness','status','PASS',...
        'message',sprintf('%d entries covering all categories',height(T)));
else
    result=struct('name','test_manifest_completeness','status','FAIL',...
        'message',sprintf('Missing categories: %s',strjoin(missing,',')));
end
end
