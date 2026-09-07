function result = test_no_v4_entrypoint_called()
% TEST: v4 entry points must not be called from v5 code.
V5_root = fileparts(fileparts(mfilename('fullpath')));
src_files = dir(fullfile(V5_root,'**','*.m'));
forbidden = {'main_numerical_pipeline','run_gate15','+core/'};
violations = {};
for fi=1:numel(src_files)
    fp=fullfile(src_files(fi).folder,src_files(fi).name);
    if strcmp(src_files(fi).name,[mfilename '.m']), continue; end
    txt=fileread(fp);
    for bi=1:numel(forbidden)
        if contains(txt,forbidden{bi})
            violations{end+1}=sprintf('%s: %s',src_files(fi).name,forbidden{bi});
        end
    end
end
if isempty(violations)
    result=struct('name','test_no_v4_entrypoint_called','status','PASS','message','Clean');
else
    result=struct('name','test_no_v4_entrypoint_called','status','FAIL',...
        'message',strjoin(violations(1:min(3,end)),'; '));
end
end
