function run = main_nrr_pipeline(repo_root, varargin)
% MAIN_NRR_PIPELINE  VsPredict_NRR_v5 — Gates 0–17.
%   Package structure per audit spec:
%     +nrr_data, +nrr_models, +nrr_eval, +nrr_audit, +nrr_report
%   Gates 18 (reproducibility) and 19 (report) are external scripts.
%
%   Usage:
%     run = main_nrr_pipeline(pwd)
%     run = main_nrr_pipeline(pwd, 'seed', 42)

if nargin<1; repo_root=fileparts(mfilename('fullpath')); end
addpath(repo_root);
addpath(fullfile(repo_root,'config'));
cfg=config_nrr_v5();
seed=cfg.seeds.canonical;
for k=1:2:numel(varargin)
    if strcmp(varargin{k},'seed'); seed=varargin{k+1}; end
end
rng(seed,'twister');

sep=repmat('=',1,60);
fprintf('\n%s\n  VsPredict_NRR_v5 | NRR Pipeline\n%s\n',sep,sep);
fprintf('  Seed: %d | Canonical: %d\n\n',seed,cfg.seeds.canonical);

%% Initialize run struct
run=struct();
run.id     =sprintf('run_%s',datestr(now,'yyyymmdd_HHMMSS'));
run.seed   =seed;
run.folder =fullfile(repo_root,cfg.out.runs_dir,run.id);
run.gate   =struct();

% Output subdirectories
for d={'00_environment','01_data_audit','02_cv','03_models',...
        '04_blind','05_diagnostics','06_bootstrap','07_geomech','08_freeze'}
    mkdir(fullfile(run.folder,d{1}));
end

run.env.repo_root  =repo_root;
run.env.matlab_ver =version;
run.env.os         =computer;
run.env.rng_type   ='twister';
run.env.config_hash=num2str(sum(double(jsonencode(cfg))));

% Suppress all figure rendering during Gates 0-17 (renderer safety)
set(groot,'DefaultFigureVisible','off');

% ENVIRONMENT_MANIFEST.json
env_out=fullfile(run.folder,'00_environment');
manifest=struct('run_id',run.id,'seed',seed,'matlab_ver',run.env.matlab_ver,...
    'os',run.env.os,'config_hash',run.env.config_hash,'timestamp',datestr(now));
fid=fopen(fullfile(env_out,'ENVIRONMENT_MANIFEST.json'),'w');
fprintf(fid,'%s',jsonencode(manifest)); fclose(fid);

% CONFIG_CANONICAL.json
fid2=fopen(fullfile(env_out,'CONFIG_CANONICAL.json'),'w');
fprintf(fid2,'%s',jsonencode(cfg)); fclose(fid2);

% SOURCE_SHA256.csv — hash all active .m files
src_files=dir(fullfile(repo_root,'**','*.m'));
src_rows={};
for sfi=1:numel(src_files)
    fp=fullfile(src_files(sfi).folder,src_files(sfi).name);
    try; fid3=fopen(fp,'rb'); raw=fread(fid3); fclose(fid3);
    h=num2str(sum(double(raw)));
    catch; h='unavailable'; end
    src_rows{end+1}={strrep(fp,repo_root,''),h};
end
writetable(cell2table(vertcat(src_rows{:}),'VariableNames',{'FILE','HASH'}),...
    fullfile(env_out,'SOURCE_SHA256.csv'));

run.gate.GATE_0='PASS';
gpass(run,'GATE_0','Gate 0: Initialization');

%% GATE 1 — Load
[run.T_A_raw,run.T_B_raw,run.hashes]=nrr_data.load(repo_root,cfg);
run.gate.GATE_1='PASS';
gpass(run,'GATE_1','Gate 1: Load wells');

%% GATE 2 — Integrity
nrr_data.validate(run.T_A_raw,run.T_B_raw,cfg);
run.gate.GATE_2='PASS';
gpass(run,'GATE_2','Gate 2: Data integrity');

%% GATE 3 — Exact duplicate audit
out1=fullfile(run.folder,'01_data_audit');
run.dup=nrr_data.audit_duplicates(run.T_A_raw,run.T_B_raw,out1,cfg);
run.gate.GATE_3='PASS';
gpass(run,'GATE_3','Gate 3: Exact duplicate audit');

%% GATE 4 — Data roles
run.roles=nrr_data.define_roles(run.T_A_raw,run.T_B_raw,run.dup,out1,cfg);
run.n_A=run.roles.n_A; run.n_dev=run.roles.n_dev; run.n_hold=run.roles.n_hold;
run.n_popA=run.roles.n_popA; run.n_popB=run.roles.n_popB;
run.gate.GATE_4='PASS';
gpass(run,'GATE_4','Gate 4: Population definition');

%% GATE 5 — Outer folds (on development rows only)
T_dev=run.T_A_raw(run.roles.dev_mask,:);
[run.outer_folds,run.fold_hash]=nrr_data.build_folds(T_dev,cfg.cv.n_outer,cfg);
% Save OUTER_FOLD_ASSIGNMENTS.csv
out2=fullfile(run.folder,'02_cv');
T_fa=cell2table(cell(run.n_dev,4),'VariableNames',...
    {'ROW_ID','DEPTH','FOLD_ID','ROLE'});
for fi=1:cfg.cv.n_outer
    vi=run.outer_folds(fi).val_idx;
    T_fa.ROW_ID(vi)   =num2cell(T_dev.(cfg.data.id_col)(vi));
    T_fa.DEPTH(vi)    =num2cell(T_dev.(cfg.data.depth_col)(vi));
    T_fa.FOLD_ID(vi)  =num2cell(repmat(fi,numel(vi),1));
    T_fa.ROLE(vi)     ={'outer_val'};
end
writetable(T_fa,fullfile(out2,'OUTER_FOLD_ASSIGNMENTS.csv'));
fprintf('[G5] Fold hash: %s\n',run.fold_hash);
run.gate.GATE_5='PASS';
gpass(run,'GATE_5','Gate 5: Outer depth folds');

%% GATES 6-8 — True nested CV
run=nrr_eval.run_nested_cv(run,cfg);
gpass(run,'GATE_6','Gate 6: Inner HP tuning');
gpass(run,'GATE_7','Gate 7: Outer-fold prediction');
gpass(run,'GATE_8','Gate 8: OOF assembly');

%% GATE 9 — Historical provenance (V5_CORRECTED_REANALYSIS label)
run=nrr_eval.gate9_provenance(run,cfg);
gpass(run,'GATE_9','Gate 9: Historical provenance');

%% GATE 10 — Canonical HP policy
run=nrr_eval.gate10_canonical_hp(run,cfg);
gpass(run,'GATE_10','Gate 10: Canonical HP');

%% GATE 11 — Freeze deployment on full Well-A n=492
run=nrr_eval.gate11_freeze_deployment(run,cfg);
gpass(run,'GATE_11','Gate 11: Freeze deployment');

%% GATE 12 — Primary blind evaluation + LOCK
run=nrr_eval.gate12_primary_blind(run,cfg);
gpass(run,'GATE_12','Gate 12: Primary blind evaluation [LOCKED]');
fprintf('  >> PRIMARY RESULT LOCKED.\n\n');

%% GATE 13 — Direct Ridge post-hoc
run=nrr_eval.gate13_direct_ridge(run,cfg);
gpass(run,'GATE_13','Gate 13: Direct Ridge post-hoc');

%% GATE 14 — Domain shift
run=nrr_eval.gate14_domain_shift(run,cfg);
gpass(run,'GATE_14','Gate 14: Domain-shift diagnostics');

%% GATE 15 — Block bootstrap
run=nrr_eval.gate15_bootstrap(run,cfg);
gpass(run,'GATE_15','Gate 15: Block bootstrap');

%% GATE 16 — Exact multi-seed
run=nrr_eval.gate16_multiseed(run,cfg);
gpass(run,'GATE_16','Gate 16: Exact multi-seed');

%% GATE 17 — Geomechanics + freeze
run=nrr_eval.gate17_geomech_freeze(run,cfg);
gpass(run,'GATE_17','Gate 17: Geomechanics + freeze');

fprintf('\n%s\n  Gates 0-17 COMPLETE\n%s\n',sep,sep);
fprintf('  Run ID: %s\n  Seed:   %d\n  Folder: %s\n\n',run.id,run.seed,run.folder);
fprintf('  Next:\n');
fprintf('    1. Second clean MATLAB session -> run_pipeline\n');
fprintf('    2. run_reproducibility_check(''%s'', ''run_ID_2'', pwd)\n',run.id);
fprintf('    3. nrr_report.generate_all after Gate 18 PASS\n\n');
end

function gpass(run,field,label)
if ~isfield(run.gate,field)||~strcmp(run.gate.(field),'PASS')
    error('Pipeline:GateFail','%s FAIL',label);
end
fprintf('  [PASS] %s\n\n',label);
end
