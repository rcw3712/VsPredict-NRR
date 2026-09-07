function result = test_no_hardcoded_metrics()
% TEST: No literal scientific numerics in +nrr_report/*.m
report_dir = fullfile(fileparts(mfilename('fullpath')),'..', '+nrr_report');
if ~isfolder(report_dir)
    result = struct('name','test_no_hardcoded_metrics','status','FAIL',...
        'message','+nrr_report does not exist yet'); return
end
files = dir(fullfile(report_dir,'*.m'));
patterns = {'-3\.9607','-7\.397','0\.6804','0\.6418'};
violations = {};
for fi = 1:numel(files)
    txt = fileread(fullfile(report_dir, files(fi).name));
    lines = strsplit(txt, newline);
    for li = 1:numel(lines)
        if startsWith(strtrim(lines{li}),'%'); continue; end
        for pi = 1:numel(patterns)
            if ~isempty(regexp(lines{li}, patterns{pi},'once'))
                violations{end+1} = sprintf('%s L%d', files(fi).name, li);
            end
        end
    end
end
if isempty(violations)
    result = struct('name','test_no_hardcoded_metrics','status','PASS','message','Clean');
else
    result = struct('name','test_no_hardcoded_metrics','status','FAIL',...
        'message',strjoin(violations(1:min(3,end)),'; '));
end
end
