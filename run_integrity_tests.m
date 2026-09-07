function summary = run_integrity_tests()
%RUN_INTEGRITY_TESTS Execute the repository's fail-hard custom test suite.
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root,'config'));
addpath(fullfile(root,'tests'));
files = dir(fullfile(root,'tests','test_*.m'));
results = repmat(struct('name','','status','','message',''),numel(files),1);
fprintf('VsPredict NRR v5 integrity tests: %d\n',numel(files));
for i = 1:numel(files)
    [~,name] = fileparts(files(i).name);
    try
        result = feval(name);
    catch ME
        result = struct('name',name,'status','ERROR','message',ME.message);
    end
    results(i) = result;
    fprintf('%s: %s -- %s\n',result.name,result.status,result.message);
end
passed = strcmp({results.status},'PASS');
summary = struct('n_pass',sum(passed),'n_total',numel(results),'results',results);
assert(all(passed),'Integrity tests failed: %d/%d PASS',sum(passed),numel(results));
fprintf('All %d integrity tests PASS.\n',numel(results));
end
