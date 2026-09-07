function generate_all(run_folder, repo_root)
% NRR_REPORT.GENERATE_ALL  Gate 19 — generate all NRR tables from canonical run.
%   Fails if: canonical pointer missing, Gate 18 not PASS, or metrics mismatch.
%   Asserts: Direct Ridge never labeled primary/confirmatory.
if nargin<2; repo_root=fileparts(fileparts(mfilename('fullpath'))); end
addpath(repo_root); addpath(fullfile(repo_root,'config'));
cfg=config_nrr_v5();
sep=repmat('=',1,60);
fprintf('\n%s\n  Gate 19: NRR Report Generation\n%s\n\n',sep,sep);

% Pre-check 1: canonical pointer
ptr=fullfile(repo_root,'runs','CANONICAL_RUN_POINTER.txt');
assert(isfile(ptr),'[G19] CANONICAL_RUN_POINTER.txt not found');
fid=fopen(ptr,'r'); canon_id=strtrim(fgetl(fid)); fclose(fid);
[~,run_id]=fileparts(run_folder);
assert(strcmp(canon_id,run_id),'[G19] %s is not canonical run (%s)',run_id,canon_id);
fprintf('  Canonical run: %s\n',canon_id);

% Pre-check 2: Gate 18 PASS
repro=fullfile(repo_root,'runs','CROSS_RUN_REPRODUCIBILITY.csv');
assert(isfile(repro),'[G19] CROSS_RUN_REPRODUCIBILITY.csv missing — run Gate 18');
T_rep=readtable(repro); n_fail=sum(strcmp(T_rep.STATUS,'FAIL'));
assert(n_fail==0,'[G19] Gate 18 has %d failures — fix before reporting',n_fail);
fprintf('  Gate 18: PASS (%d checks)\n\n',height(T_rep));

% Load frozen run
mat=fullfile(run_folder,'08_freeze','FROZEN_NUMERICAL_RUN.mat');
assert(isfile(mat),'[G19] FROZEN_NUMERICAL_RUN.mat not found');
r=load(mat,'run'); run=r.run;

% Verify frozen metrics (tol 1e-10 per audit)
tol=1e-10;
T_pa=readtable(fullfile(run_folder,'04_blind','PRIMARY_BLIND_EVALUATION_POP_A.csv'));
assert(abs(T_pa.R2(1)-run.blind.ridge.popA.r2)<tol,'[G19] Pop-A R² mismatch');

% Assert Direct Ridge not labeled primary
T_cmp=readtable(fullfile(run_folder,'04_blind','BLIND_MODEL_COMPARISON_POP_A.csv'));
dr_rows=strcmp(T_cmp.MODEL,'direct_ridge');
if any(dr_rows)
    dr_stat=T_cmp.STATUS(dr_rows);
    for ri=1:sum(dr_rows)
        assert(~strcmp(dr_stat{ri},'primary'),'[G19] DR labeled primary — violation');
        assert(~strcmp(dr_stat{ri},'confirmatory'),'[G19] DR labeled confirmatory — violation');
    end
end
fprintf('  Frozen metric verification: PASS\n  Direct Ridge status: PASS\n  Provenance class: %s\n\n',...
    run.deploy.provenance);

% Generate tables
out_tab=fullfile(run_folder,'08_freeze','tables'); mkdir(out_tab);
copyfile(fullfile(run_folder,'04_blind','BLIND_MODEL_COMPARISON_POP_A.csv'),...
    fullfile(out_tab,'TABLE_1_BLIND_POP_A.csv'));
copyfile(fullfile(run_folder,'04_blind','BLIND_MODEL_COMPARISON_POP_B.csv'),...
    fullfile(out_tab,'TABLE_1_BLIND_POP_B.csv'));
copyfile(fullfile(run_folder,'02_cv','NESTED_CV_OUTER_FOLD_METRICS.csv'),...
    fullfile(out_tab,'TABLE_S1_NESTED_CV.csv'));
copyfile(fullfile(run_folder,'05_diagnostics','DOMAIN_SHIFT_DIAGNOSTICS.csv'),...
    fullfile(out_tab,'TABLE_S2_DOMAIN_SHIFT.csv'));
copyfile(fullfile(run_folder,'06_bootstrap','BLOCK_BOOTSTRAP_SUMMARY.csv'),...
    fullfile(out_tab,'TABLE_S3_BOOTSTRAP.csv'));
copyfile(fullfile(run_folder,'04_blind','MULTISEED_EXACT_PIPELINE_METRICS.csv'),...
    fullfile(out_tab,'TABLE_S4_MULTISEED.csv'));
copyfile(fullfile(run_folder,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv'),...
    fullfile(out_tab,'TABLE_S5_GEOMECH.csv'));
copyfile(fullfile(run_folder,'07_geomech','GEOMECH_FAILURE_REASONS.csv'),...
    fullfile(out_tab,'TABLE_S6_GEOMECH_FAILURE_REASONS.csv'));
copyfile(fullfile(run_folder,'08_freeze','NRR_NUMERICAL_RESULTS_SUMMARY.md'),...
    fullfile(out_tab,'NRR_NUMERICAL_RESULTS_SUMMARY.md'));

fprintf('  Tables generated in: %s\n\n',out_tab);
fprintf('%s\n  Gate 19: PASS\n%s\n\n',sep,sep);
fprintf('  All outputs from canonical run: %s\n',canon_id);
fprintf('  Provenance class: %s\n\n',run.deploy.provenance);
end
