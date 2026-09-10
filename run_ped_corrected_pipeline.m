function run_out = run_ped_corrected_pipeline(repo_root, varargin)
% RUN_PED_CORRECTED_PIPELINE  PED corrected runner, Codex patch v3.
% Phase 1: corrected fixed-canonical-HP 392/100 holdout.
% Phase 2: complete corrected Gates 0-17 with segment-aware CNN training
%          and prediction, followed by regenerated downstream analyses.

if nargin<1 || isempty(repo_root); repo_root=fileparts(mfilename('fullpath')); end
addpath(genpath(repo_root)); cfg=config_nrr_v5();
phase='all'; legacy_run_id='run_20260903_155408'; seed=cfg.seeds.canonical;
for k=1:2:numel(varargin)
    switch lower(string(varargin{k}))
        case "phase"; phase=varargin{k+1};
        case "legacy_run_id"; legacy_run_id=char(varargin{k+1});
        case "seed"; seed=varargin{k+1};
        otherwise; error('run_ped_corrected_pipeline: unknown option %s',string(varargin{k}));
    end
end
run_out=struct();
fprintf('\n%s\nPED CORRECTED PIPELINE - CODEX PATCH V3\n%s\n', ...
    repmat('=',1,68),repmat('=',1,68));

if selected(phase,1)
    legacy_dir=fullfile(repo_root,'runs',legacy_run_id);
    model_path=fullfile(legacy_dir,'08_freeze','FROZEN_MODEL_ARTIFACTS.mat');
    manifest_path=fullfile(legacy_dir,'08_freeze','RUN_MANIFEST_SHA256.csv');
    assert(isfile(model_path)&&isfile(manifest_path), ...
        'Phase 1: legacy model artifact or manifest missing');
    A=load(model_path,'deploy');
    assert(isfield(A,'deploy')&&isfield(A.deploy,'hp'), ...
        'Phase 1: canonical HP artifact missing');
    verify_model_artifact(model_path,manifest_path);
    ph1_id=sprintf('run_PED_P1_codex_%s',char(datetime('now','Format','yyyyMMdd_HHmmss')));
    ph1_dir=fullfile(repo_root,'runs',ph1_id);
    audit_dir=fullfile(ph1_dir,'01_data_audit');
    mkdir(ph1_dir); mkdir(audit_dir); mkdir(fullfile(ph1_dir,'03_models'));
    [T_A,T_B,hashes]=nrr_data.load(repo_root,cfg);
    dup=nrr_data.audit_duplicates(T_A,T_B,audit_dir,cfg);
    roles=nrr_data.define_roles(T_A,T_B,dup,audit_dir,cfg);
    run_p1=struct('id',ph1_id,'folder',ph1_dir,'seed',seed, ...
        'T_A_raw',T_A,'T_B_raw',T_B,'hashes',hashes,'roles',roles, ...
        'n_dev',roles.n_dev,'n_hold',roles.n_hold,'n_popA',roles.n_popA, ...
        'n_popB',roles.n_popB,'gate',struct());
    run_p1.canon_hp=A.deploy.hp;
    run_p1.canon_hp_hash=sprintf('spread=%.4f|lambda=%.6f', ...
        A.deploy.hp.pnn_spread,A.deploy.hp.ridge_lambda);
    run_p1.provenance='PED_CORRECTED_FIXED_HP_EXTENSION';
    assert(abs(run_p1.canon_hp.pnn_spread-0.5)<1e-12 && ...
        abs(run_p1.canon_hp.ridge_lambda-0.001)<1e-12, ...
        'Phase 1: unexpected frozen canonical HP');
    fprintf('[PHASE 1] canonical HP spread=%.2f lambda=%.4f\n', ...
        run_p1.canon_hp.pnn_spread,run_p1.canon_hp.ridge_lambda);
    rng(seed,'twister'); run_p1=nrr_eval.gate9_provenance(run_p1,cfg);

    ms=run_p1.hist.holdout_metrics; md=run_p1.hist.direct_ridge;
    T=table(["Ridge_stacker";"Direct_Ridge";"Legacy_Ridge_stacker"], ...
        ["PRESPECIFIED_PRIMARY";"POST_HOC_EXPLORATORY_392_ONLY"; ...
        "LEGACY_INVALID_RAW_META_SCALING"], ...
        [ms.n;md.n;run_p1.n_hold],[ms.r2;md.r2;-3.0622], ...
        [ms.rmse;md.rmse;NaN],[ms.mae;md.mae;NaN],[ms.bias;md.bias;NaN], ...
        'VariableNames',{'MODEL','STATUS','N','R2','RMSE','MAE','BIAS'});
    writetable(T,fullfile(ph1_dir,'PED_PHASE1_COMPUTED_METRICS.csv'));
    fid=fopen(fullfile(ph1_dir,'PED_PHASE1_SUMMARY.md'),'w');
    assert(fid>=3,'Phase 1: cannot create summary'); clean=onCleanup(@()fclose(fid));
    fprintf(fid,'# PED Phase 1 - corrected fixed-HP holdout\n\n');
    fprintf(fid,'- Run: `%s`\n- Provenance: `%s`\n',ph1_id,run_p1.provenance);
    fprintf(fid,'- Canonical HP: spread %.2f; lambda %.4f\n', ...
        run_p1.canon_hp.pnn_spread,run_p1.canon_hp.ridge_lambda);
    fprintf(fid,'- Ridge stacker: R2 %.4f; RMSE %.4f; MAE %.4f; bias %.4f\n', ...
        ms.r2,ms.rmse,ms.mae,ms.bias);
    fprintf(fid,'- Direct Ridge: R2 %.4f; RMSE %.4f; MAE %.4f; bias %.4f\n', ...
        md.r2,md.rmse,md.mae,md.bias);
    fprintf(fid,'- Legacy R2 -3.0622: `LEGACY_INVALID_RAW_META_SCALING`\n');
    clear clean
    run_out.phase1=run_p1; run_out.phase1_dir=ph1_dir;
    run_out.corrected_holdout_r2=ms.r2;
end

if selected(phase,2)
    fprintf('[PHASE 2] Starting complete corrected Gates 0-17.\n');
    fprintf('[PHASE 2] All model-derived downstream results will be regenerated.\n');
    rng(seed,'twister');
    run_p2=main_nrr_pipeline(repo_root,'seed',seed, ...
        'run_prefix','run_PED_corrected', ...
        'provenance','PED_CORRECTED_FULL_REANALYSIS');
    assert(strcmp(run_p2.provenance,'PED_CORRECTED_FULL_REANALYSIS'), ...
        'Phase 2: provenance mismatch');
    assert(strcmp(run_p2.cv.cnn_window_status, ...
        'PASS_ZERO_RETAINED_CROSS_SEGMENT'), ...
        'Phase 2: CNN window audit missing');
    run_out.phase2=run_p2; run_out.phase2_id=run_p2.id;
    fprintf('[PHASE 2] Complete without post-freeze folder rename: %s\n',run_p2.id);
end
end

function tf = selected(phase,target)
if ischar(phase) || isstring(phase)
    p=lower(string(phase)); tf=(p=="all") || (p==string(target));
else
    tf=isequal(phase,target);
end
end
function verify_model_artifact(model_path,manifest_path)
M=readtable(manifest_path,'TextType','string');
assert(all(ismember({'FILE','SHA256'},M.Properties.VariableNames)), ...
    'Phase 1: manifest schema invalid');
needle=lower(strrep(string(fullfile('08_freeze','FROZEN_MODEL_ARTIFACTS.mat')),'\','/'));
paths=lower(strrep(M.FILE,'\','/'));
ix=find(endsWith(paths,needle),1);
assert(~isempty(ix),'Phase 1: model artifact absent from manifest');
actual=string(nrr_eval.sha256_file_windows(model_path));
assert(strcmpi(actual,M.SHA256(ix)), ...
    'Phase 1: frozen model artifact hash mismatch');
end
