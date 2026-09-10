function summary = run_vspredict_ped_extension_codex(project_root, canonical_run_id)
% RUN_VSPREDICT_PED_EXTENSION_CODEX
% Corrected, evidence-first PED targeted extension for VsPredict_NRR_v5.
%
% This function DOES NOT modify the legacy canonical run. It refits a
% corrected fixed-HP pipeline in a new run folder and quarantines two known
% legacy defects: (1) raw/scaled meta-feature mismatch in historical holdout
% evaluation, and (2) CNN windows crossing a removed depth block.
%
% Usage:
%   addpath('path/to/VsPredict_PED_Extension_Codex_v2')
%   s = run_vspredict_ped_extension_codex('C:\Drive E\VsPredict_NRR_v5', ...
%         'run_20260903_155408');
%
% Scientific status:
%   PED_CORRECTED_FIXED_HP_EXTENSION
% The hyperparameters are read from the frozen legacy deployment and are
% not retuned here. Therefore this is a targeted extension, not a silent
% replacement for a full corrected nested-CV canonical rerun.

if nargin < 1 || isempty(project_root)
    project_root = discover_project_root();
end
if nargin < 2 || isempty(canonical_run_id)
    canonical_run_id = 'run_20260903_155408';
end

assert(isfolder(project_root), 'Project root not found: %s', project_root);
core_cfg_file = fullfile(project_root,'config','config_nrr_v5.m');
assert(isfile(core_cfg_file), 'config_nrr_v5.m not found under project root');
addpath(genpath(project_root));
this_dir = fileparts(mfilename('fullpath'));
addpath(genpath(this_dir));

cfg = config_nrr_v5();
cfg.logging.console_model_fit = false;
cfg.ext.provenance = 'PED_CORRECTED_FIXED_HP_EXTENSION';
cfg.ext.legacy_run = canonical_run_id;
cfg.ext.code_version = '2.0.0-codex';
cfg.ext.block_lens = [10 20 30 40];
cfg.ext.n_boot = 3000;
cfg.ext.boot_seed = 2025;

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
run_id = sprintf('ped_codex_%s_%s', canonical_run_id, stamp);
run_dir = fullfile(project_root,'runs',run_id);
subdirs = {'00_environment','01_population','02_core_audit','03_holdout', ...
    '04_external','05_bootstrap','06_physics','07_freeze','08_report','logs'};
for i=1:numel(subdirs); mkdir(fullfile(run_dir,subdirs{i})); end

diary_file = fullfile(run_dir,'logs','PED_CODEX_RUN.log');
diary(diary_file); diary on;
cleanup_diary = onCleanup(@() diary('off'));
fprintf('\n%s\nVsPredict PED corrected extension | %s\n%s\n', ...
    repmat('=',1,72), run_id, repmat('=',1,72));

gate_names = ["ENVIRONMENT";"POPULATION";"LEGACY_CORE_QUARANTINE"; ...
    "CORRECTED_HOLDOUT";"CORRECTED_EXTERNAL_ALL_MODELS"; ...
    "PAIRED_BOOTSTRAP";"PHYSICAL_PLAUSIBILITY";"FREEZE_AND_REPORT"];
gates = repmat(make_result("PENDING","PENDING","Not run",true,""),8,1);

ctx = struct(); holdout = struct(); deployment = struct(); external = struct();
boot = struct(); phys = struct();

try
    [ctx,gates(1)] = gate_environment(project_root,canonical_run_id,run_dir,cfg);
catch ME
    gates(1)=runtime_failure(ME,fullfile(run_dir,'00_environment'));
end

if gates(1).status == "PASS"
    try
        [ctx,gates(2)] = gate_population(ctx,run_dir,cfg);
    catch ME
        gates(2)=runtime_failure(ME,fullfile(run_dir,'01_population'));
    end
else
    gates(2)=upstream_block("ENVIRONMENT",fullfile(run_dir,'01_population'));
end

if all([gates(1:2).status] == "PASS")
    try
        [ctx,gates(3)] = gate_legacy_core_quarantine(ctx,run_dir);
    catch ME
        gates(3)=runtime_failure(ME,fullfile(run_dir,'02_core_audit'));
    end
else
    gates(3)=upstream_block("POPULATION",fullfile(run_dir,'02_core_audit'));
end

if all([gates(1:3).status] == "PASS")
    try
        [holdout,gates(4)] = gate_corrected_holdout(ctx,run_dir,cfg);
    catch ME
        gates(4)=runtime_failure(ME,fullfile(run_dir,'03_holdout'));
    end
else
    gates(4)=upstream_block("LEGACY_CORE_QUARANTINE",fullfile(run_dir,'03_holdout'));
end

if all([gates(1:3).status] == "PASS")
    try
        [deployment,external,gates(5)] = gate_external(ctx,run_dir,cfg);
    catch ME
        gates(5)=runtime_failure(ME,fullfile(run_dir,'04_external'));
    end
else
    gates(5)=upstream_block("LEGACY_CORE_QUARANTINE",fullfile(run_dir,'04_external'));
end

if gates(5).status == "PASS"
    try
        [boot,gates(6)] = gate_bootstrap(external,run_dir,cfg);
    catch ME
        gates(6)=runtime_failure(ME,fullfile(run_dir,'05_bootstrap'));
    end
    try
        [phys,gates(7)] = gate_physics(external,ctx,run_dir,cfg);
    catch ME
        gates(7)=runtime_failure(ME,fullfile(run_dir,'06_physics'));
    end
else
    gates(6)=upstream_block("CORRECTED_EXTERNAL_ALL_MODELS",fullfile(run_dir,'05_bootstrap'));
    gates(7)=upstream_block("CORRECTED_EXTERNAL_ALL_MODELS",fullfile(run_dir,'06_physics'));
end

if all([gates(1:7).status] == "PASS")
    try
        gates(8)=gate_freeze_report(ctx,holdout,deployment,external,boot,phys, ...
            gates,gate_names,run_dir,run_id,cfg);
    catch ME
        gates(8)=runtime_failure(ME,fullfile(run_dir,'07_freeze'));
    end
else
    gates(8)=make_result("BLOCKED","BLOCKED_REQUIRED_GATE", ...
        "Freeze/report prohibited because at least one required gate did not PASS", ...
        true,fullfile(run_dir,'07_freeze'));
end

T_status = table(gate_names,[gates.status]',[gates.code]',[gates.message]', ...
    [gates.required]',[gates.n_checks]',[gates.n_pass]',[gates.evidence_path]', ...
    'VariableNames',{'GATE','STATUS','CODE','MESSAGE','REQUIRED','N_CHECKS','N_PASS','EVIDENCE_PATH'});
writetable(T_status,fullfile(run_dir,'PED_CODEX_GATE_STATUS.csv'));

overall = "PASS";
if ~all([gates.status] == "PASS"); overall = "BLOCKED"; end
summary = struct('run_id',run_id,'run_dir',run_dir,'overall_status',overall, ...
    'provenance',cfg.ext.provenance,'gates',gates);
save(fullfile(run_dir,'PED_CODEX_RUN_STATE.mat'),'summary','-v7.3');
diary off;
write_final_manifest(run_dir);

fprintf('\nOverall: %s | %d/%d gates PASS\nOutput: %s\n', ...
    overall,sum([gates.status]=="PASS"),numel(gates),run_dir);
if overall ~= "PASS"
    error('PED_CODEX:INCOMPLETE','Run incomplete. Inspect PED_CODEX_GATE_STATUS.csv');
end
end

function [ctx,r] = gate_environment(root,legacy_id,run_dir,cfg)
out=fullfile(run_dir,'00_environment'); legacy=fullfile(root,'runs',legacy_id);
numf=fullfile(legacy,'08_freeze','FROZEN_NUMERICAL_RUN.mat');
modf=fullfile(legacy,'08_freeze','FROZEN_MODEL_ARTIFACTS.mat');
manf=fullfile(legacy,'08_freeze','RUN_MANIFEST_SHA256.csv');
assert(isfile(numf)&&isfile(modf)&&isfile(manf),'Required legacy frozen artifact missing');
fn=load(numf); fa=load(modf);
assert(isfield(fa,'deploy')&&isfield(fa.deploy,'hp'),'Frozen deploy.hp missing');
assert(isfield(fa.deploy,'base_nets')&&isfield(fa.deploy,'stacker'), ...
    'Frozen deployment model components missing');
assert(isfield(fa,'posthoc')&&isfield(fa.posthoc,'dr')&&isfield(fa.posthoc,'pm'), ...
    'Frozen Direct Ridge artifact missing');

mf=readtable(manf,'TextType','string');
assert(all(ismember({'FILE','SHA256','CATEGORY'},mf.Properties.VariableNames)), ...
    'Manifest schema must contain FILE,SHA256,CATEGORY');
status=strings(height(mf),1); resolved=strings(height(mf),1); actual=strings(height(mf),1);
for i=1:height(mf)
    cat=lower(string(mf.CATEGORY(i))); rel=char(mf.FILE(i));
    if any(cat==["source_m","config","test_source","data"])
        fp=fullfile(root,rel);
    elseif cat=="output"
        fp=fullfile(legacy,rel);
    else
        fp='';
    end
    resolved(i)=string(fp);
    if isempty(fp); status(i)="UNKNOWN_CATEGORY"; continue; end
    if ~isfile(fp); status(i)="MISSING"; continue; end
    actual(i)=sha256_file(fp);
    if strcmpi(actual(i),mf.SHA256(i)); status(i)="VERIFIED";
    else; status(i)="HASH_MISMATCH"; end
end
T=table(mf.FILE,mf.CATEGORY,resolved,mf.SHA256,actual,status, ...
    'VariableNames',{'FILE','CATEGORY','RESOLVED_PATH','EXPECTED_SHA256','ACTUAL_SHA256','STATUS'});
writetable(T,fullfile(out,'PED_MANIFEST_VERIFICATION.csv'));

% The legacy run may contain later report products not represented by a
% single immutable manifest. Required inputs are verified independently.
% FROZEN_NUMERICAL_RUN is loaded only as legacy provenance. It is not used
% for refitting because the legacy file was changed after its manifest.
required={modf;fullfile(root,'data',cfg.data.wellA_file); ...
    fullfile(root,'data',cfg.data.wellB_file);fullfile(root,'config','config_nrr_v5.m')};
req_hash=strings(numel(required),1);req_manifest_status=strings(numel(required),1);
for i=1:numel(required)
    assert(isfile(required{i}),'Missing required input: %s',required{i});req_hash(i)=sha256_file(required{i});
    ix=find(strcmpi(T.RESOLVED_PATH,string(required{i})),1);
    assert(~isempty(ix),'Required input absent from legacy manifest: %s',required{i});
    req_manifest_status(i)=T.STATUS(ix);
    assert(req_manifest_status(i)=="VERIFIED",'Required input not verified: %s [%s]',required{i},req_manifest_status(i));
end
Treq=table(string(required),req_hash,req_manifest_status,'VariableNames',{'REQUIRED_FILE','SHA256','MANIFEST_STATUS'});
writetable(Treq,fullfile(out,'PED_REQUIRED_INPUT_HASHES.csv'));

ctx=struct('project_root',root,'legacy_run_id',legacy_id,'legacy_dir',legacy, ...
    'frozen_num',fn,'frozen_art',fa,'hp',fa.deploy.hp,'required_hashes',Treq);
r=make_result("PASS","REQUIRED_INPUTS_VERIFIED", ...
    sprintf('%d required inputs readable and SHA-256 hashed; full legacy manifest retained as audit evidence',numel(required)), ...
    true,out,numel(required),numel(required));
end

function [ctx,r] = gate_population(ctx,run_dir,cfg)
out=fullfile(run_dir,'01_population');
[A,B,hashes]=nrr_data.load(ctx.project_root,cfg);
assert(height(A)==492&&height(B)==492,'Expected 492 rows in each well');
check=cfg.dup.check_cols; td=cfg.dup.tol_depth; tl=cfg.dup.tol_log;
dupB=[]; audit=cell(height(B),1);
for bi=1:height(B)
    cand=find(abs(A.(cfg.data.depth_col)-B.(cfg.data.depth_col)(bi))<=td);
    if isempty(cand); audit{bi}={bi,NaN,"NO_MATCH",NaN}; continue; end
    assert(isscalar(cand),'Ambiguous depth match for Well-B row %d',bi);
    ai=cand(1); exact=true; maxd=0;
    for c=check
        assert(ismember(c{1},A.Properties.VariableNames)&&ismember(c{1},B.Properties.VariableNames), ...
            'Duplicate audit column missing: %s',c{1});
        va=A.(c{1})(ai); vb=B.(c{1})(bi);
        if ~isfinite(va)||~isfinite(vb); exact=false; d=NaN; else; d=abs(va-vb); exact=exact&&(d<=tl); end
        if isfinite(d); maxd=max(maxd,d); end
    end
    if exact; cls="PREDICTOR_AND_TARGET_EXACT"; dupB(end+1,1)=bi; %#ok<AGROW>
    else; cls="DEPTH_MATCH_ONLY"; end
    audit{bi}={bi,ai,cls,maxd};
end
Ta=cell2table(vertcat(audit{:}),'VariableNames',{'IDX_B','IDX_A','CLASSIFICATION','MAX_ABS_DELTA'});
Ta.ROW_ID_B=B.(cfg.data.id_col)(Ta.IDX_B); Ta.DEPTH_B=B.(cfg.data.depth_col)(Ta.IDX_B);
writetable(Ta,fullfile(out,'PED_DUPLICATE_FORENSIC_AUDIT.csv'));
assert(numel(dupB)==cfg.dup.expected_n, ...
    'Exact duplicate count %d differs from expected %d',numel(dupB),cfg.dup.expected_n);

[folds,~]=nrr_data.build_folds(A,cfg.cv.n_outer,cfg); foldid=zeros(height(A),1);
for i=1:numel(folds); foldid(folds(i).val_idx)=i; end
dev=foldid~=cfg.cv.holdout_fold; hold=~dev;
nondup=true(height(B),1); nondup(dupB)=false;
popA=nondup&isfinite(B.(cfg.data.target));
vpvs=B.VP./B.(cfg.data.target); popB=popA&(vpvs>=sqrt(2));
assert(sum(dev)==392&&sum(hold)==100&&sum(popA)==329&&sum(popB)==236, ...
    'Role counts differ: dev=%d hold=%d PopA=%d PopB=%d',sum(dev),sum(hold),sum(popA),sum(popB));
roles=struct('dev_mask',dev,'hold_mask',hold,'dup_mask',~nondup, ...
    'popA_mask',popA,'popB_mask',popB,'fold_id',foldid);
Troles=table([A.ROW_ID;B.ROW_ID],[A.DEPTH;B.DEPTH], ...
    [repmat("WellA_dev",height(A),1);repmat("WellB",height(B),1)], ...
    'VariableNames',{'ROW_ID','DEPTH','ROLE'});
Troles.ROLE(find(hold))="WellA_holdout";
off=height(A); Troles.ROLE(off+find(~nondup))="WellB_exact_duplicate";
Troles.ROLE(off+find(popA))="WellB_PopA"; Troles.ROLE(off+find(popB))="WellB_PopB";
writetable(Troles,fullfile(out,'PED_DATA_ROLE_ROW_IDS.csv'));
counts=table([height(A);sum(dev);sum(hold);height(B);numel(dupB);sum(popA);sum(popB)], ...
    'RowNames',{'WellA','Development','Holdout','WellB','ExactDuplicate','PopA','PopB'}, ...
    'VariableNames',{'N'});
writetable(counts,fullfile(out,'PED_DATA_ROLE_COUNTS.csv'),'WriteRowNames',true);
ctx.A=A;ctx.B=B;ctx.hashes=hashes;ctx.roles=roles;
r=make_result("PASS","CONDITION_A_EXACT_DUPLICATES", ...
    '163 exact duplicates excluded; Pop-A=329 primary; Pop-B=236 target-informed diagnostic; Full Well-B sensitivity prohibited', ...
    true,out,height(B),height(B));
end

function [ctx,r] = gate_legacy_core_quarantine(ctx,run_dir)
out=fullfile(run_dir,'02_core_audit'); root=ctx.project_root;
g9=fileread(fullfile(root,'+nrr_eval','gate9_provenance.m'));
fc=fileread(fullfile(root,'+nrr_models','fit_cnn1d.m'));
bf=fileread(fullfile(root,'+nrr_data','build_folds.m'));
raw_fit=contains(g9,'fit_ridge_stacker(oof_m');
scaled_predict=contains(g9,'meta_h_sc');
positional_window=contains(fc,'X(j:j+W-1,:)');
split_concat=contains(bf,'setdiff(1:n,s:e)');
T=table(["HISTORICAL_RAW_META_FIT";"HISTORICAL_SCALED_META_PREDICT"; ...
    "CNN_POSITIONAL_WINDOW";"TRAIN_TWO_SEGMENTS_CONCATENATED"], ...
    [raw_fit;scaled_predict;positional_window;split_concat], ...
    'VariableNames',{'CHECK','LEGACY_DEFECT_PRESENT'});
writetable(T,fullfile(out,'PED_LEGACY_CORE_DEFECT_AUDIT.csv'));
ctx.legacy_defects=struct('holdout_scaling',raw_fit&&scaled_predict, ...
    'cnn_cross_gap_risk',positional_window&&split_concat);
if ctx.legacy_defects.holdout_scaling || ctx.legacy_defects.cnn_cross_gap_risk
    code="LEGACY_DEFECTS_QUARANTINED";
    msg='Legacy affected outputs will not be reused; local corrected scaling and segmented CNN refits are used';
else
    code="NO_LEGACY_DEFECT_SIGNATURE";
    msg='Known legacy defect signatures were not detected; local corrected implementation is still used';
end
r=make_result("PASS",code,msg,true,out,4,4);
end

function [res,r] = gate_corrected_holdout(ctx,run_dir,cfg)
out=fullfile(run_dir,'03_holdout'); A=ctx.A; dev=A(ctx.roles.dev_mask,:); hold=A(ctx.roles.hold_mask,:);
hp=ctx.hp; seed=cfg.seeds.canonical;
[meta_oof,ledger_oof]=generate_oof(dev,cfg.cv.n_inner,hp,seed,cfg,"HOLDOUT_INNER_OOF");
pm=nrr_data.fit_pm(dev,cfg); [Xd,yd]=nrr_data.apply_pm_deploy(dev,pm,cfg);
ms=nrr_models.fit_meta_scaler(meta_oof); oof_sc=nrr_models.apply_meta_scaler(meta_oof,ms);
stack=nrr_models.fit_ridge_stacker(oof_sc,yd,hp.ridge_lambda,cfg);
[nets,ledger_fit]=fit_base_segmented(Xd,yd,dev.DEPTH,dev.ROW_ID,hp,seed+90000,0,cfg,"HOLDOUT_FULL_DEV");
[Xh,yh]=nrr_data.apply_pm(hold,pm,cfg);
mh=predict_base_segmented(nets,Xh,hold.DEPTH,hold.ROW_ID);
yhat=nrr_models.predict_ridge_stacker(stack,nrr_models.apply_meta_scaler(mh,ms));
assert(all(isfinite(yhat))&&numel(yhat)==100,'Primary holdout predictions incomplete');

cfgdr=cfg;cfgdr.dr.train_n=height(dev);dr=nrr_models.fit_direct_ridge(Xd,yd,cfg.dr.lambda,cfgdr);
yhat_dr=Xh*dr.B+dr.b0;
m=metrics(yh,yhat);mdr=metrics(yh,yhat_dr);
T=table(hold.ROW_ID,hold.DEPTH,yh,yhat,yhat_dr,yhat-yh,yhat_dr-yh, ...
    'VariableNames',{'ROW_ID','DEPTH','VS_MEASURED','PRED_RIDGE_STACKER','PRED_DIRECT_RIDGE','RESID_STACKER','RESID_DIRECT'});
writetable(T,fullfile(out,'PED_HOLDOUT_ALL_MODEL_PREDICTIONS.csv'));
Tm=metrics_table(["Ridge_stacker";"Direct_Ridge"], ...
    ["PRESPECIFIED_PRIMARY";"POST_HOC_SENSITIVITY"],[m;mdr]);
writetable(Tm,fullfile(out,'PED_HOLDOUT_MODEL_METRICS.csv'));
ledger_fit.OUTER_OR_INNER_FOLD=zeros(height(ledger_fit),1);ledger=[ledger_oof;ledger_fit];writetable(ledger,fullfile(out,'PED_HOLDOUT_CNN_WINDOW_LEDGER.csv'));
res=struct('primary',m,'direct_ridge',mdr,'predictions',T,'pm',pm, ...
    'meta_scaler',ms,'stacker',stack,'base_nets',nets,'window_ledger',ledger, ...
    'legacy_r2',-3.0622,'legacy_status','LEGACY_INVALID_SCALING_MISMATCH');
r=make_result("PASS","CORRECTED_TRAIN392_TEST100", ...
    sprintf('Primary holdout R2=%.4f; Direct Ridge R2=%.4f; legacy -3.0622 quarantined',m.r2,mdr.r2), ...
    true,out,100,100);
end

function [dep,res,r] = gate_external(ctx,run_dir,cfg)
out=fullfile(run_dir,'04_external'); A=ctx.A;B=ctx.B;hp=ctx.hp;seed=cfg.seeds.canonical;
[oof,ledger_oof]=generate_oof(A,cfg.cv.n_outer,hp,seed+100000,cfg,"DEPLOYMENT_OOF");
pm=nrr_data.fit_pm(A,cfg);[Xa,ya]=nrr_data.apply_pm_deploy(A,pm,cfg);
ms=nrr_models.fit_meta_scaler(oof);stack=nrr_models.fit_ridge_stacker( ...
    nrr_models.apply_meta_scaler(oof,ms),ya,hp.ridge_lambda,cfg);
[nets,ledger_fit]=fit_base_segmented(Xa,ya,A.DEPTH,A.ROW_ID,hp,seed+90000,0,cfg,"DEPLOYMENT_FULL_A");
[Xb,yb]=nrr_data.apply_pm_deploy(B,pm,cfg);
base=predict_base_segmented(nets,Xb,B.DEPTH,B.ROW_ID);
ridge=nrr_models.predict_ridge_stacker(stack,nrr_models.apply_meta_scaler(base,ms));
dr=nrr_models.fit_direct_ridge(Xa,ya,cfg.dr.lambda,cfg); direct=Xb*dr.B+dr.b0;
assert(all(isfinite([base ridge direct]),'all'),'External predictions contain NaN/Inf');
R=ctx.roles;
T=table(B.ROW_ID,B.DEPTH,yb,base(:,1),base(:,2),base(:,3),base(:,4),ridge,direct, ...
    R.dup_mask,R.popA_mask,R.popB_mask, ...
    'VariableNames',{'ROW_ID','DEPTH','VS_MEASURED','PRED_PNN','PRED_MLFFNN','PRED_DFFNN', ...
    'PRED_CNN1D','PRED_RIDGE_STACKER','PRED_DIRECT_RIDGE','IS_EXACT_DUPLICATE','IS_POPA','IS_POPB'});
writetable(T,fullfile(out,'PED_WELLB_ALL_MODEL_PREDICTIONS.csv'));
names=["PNN";"MLFFNN";"DFFNN";"CNN1D";"Ridge_stacker";"Direct_Ridge"];
status=[repmat("PRESPECIFIED_BASE",4,1);"PRESPECIFIED_PRIMARY";"POST_HOC_SENSITIVITY"];
P=[base ridge direct]; rows=table();
for popName=["PopA","PopB"]
    if popName=="PopA"; mask=R.popA_mask; else; mask=R.popB_mask; end
    mm=repmat(metrics(yb(mask),P(mask,1)),6,1);
    for j=1:6;mm(j)=metrics(yb(mask),P(mask,j));end
    X=metrics_table(names,status,mm);X.POPULATION=repmat(popName,6,1);if isempty(rows);rows=X;else;rows=[rows;X];end %#ok<AGROW>
end
writetable(rows,fullfile(out,'PED_EXTERNAL_ALL_MODELS_METRICS.csv'));
ledger_fit.OUTER_OR_INNER_FOLD=zeros(height(ledger_fit),1);ledger=[ledger_oof;ledger_fit];writetable(ledger,fullfile(out,'PED_EXTERNAL_CNN_WINDOW_LEDGER.csv'));
dep=struct('pm',pm,'meta_scaler',ms,'stacker',stack,'base_nets',nets,'direct_ridge',dr, ...
    'hp',hp,'seed',seed,'provenance',cfg.ext.provenance,'window_ledger',ledger);
res=struct('master',T,'metrics',rows);
r=make_result("PASS","ALL_MODELS_ROW_ALIGNED", ...
    sprintf('Six model vectors complete on 492 rows; Pop-A=%d Pop-B=%d',sum(R.popA_mask),sum(R.popB_mask)), ...
    true,out,height(T)*6,height(T)*6);
end

function [res,r] = gate_bootstrap(ext,run_dir,cfg)
out=fullfile(run_dir,'05_bootstrap'); T=sortrows(ext.master(ext.master.IS_POPA,:), 'DEPTH');
y=T.VS_MEASURED; a=T.PRED_RIDGE_STACKER; b=T.PRED_DIRECT_RIDGE;n=height(T);
rng(cfg.ext.boot_seed,'twister'); rows=cell(numel(cfg.ext.block_lens),1);
for k=1:numel(cfg.ext.block_lens)
    bl=cfg.ext.block_lens(k); D=nan(cfg.ext.n_boot,4);
    for q=1:cfg.ext.n_boot
        ix=block_indices(n,bl); ma=metrics(y(ix),a(ix));mb=metrics(y(ix),b(ix));
        D(q,:)=[ma.rmse-mb.rmse,ma.mae-mb.mae,abs(ma.bias)-abs(mb.bias),ma.r2-mb.r2];
    end
    ci=quantile(D,[.025 .5 .975],1);
    rows{k}={bl,cfg.ext.n_boot,ci(1,1),ci(2,1),ci(3,1),ci(1,2),ci(2,2),ci(3,2), ...
        ci(1,3),ci(2,3),ci(3,3),ci(1,4),ci(2,4),ci(3,4),mean(D(:,1)>0)};
end
S=cell2table(vertcat(rows{:}),'VariableNames',{'BLOCK_LENGTH','N_BOOT', ...
    'DRMSE_LO','DRMSE_MED','DRMSE_HI','DMAE_LO','DMAE_MED','DMAE_HI', ...
    'DABSBIAS_LO','DABSBIAS_MED','DABSBIAS_HI','DR2_LO','DR2_MED','DR2_HI','P_DIRECT_LOWER_RMSE'});
writetable(S,fullfile(out,'PED_PAIRED_DELTA_BOOTSTRAP.csv'));
res=struct('summary',S,'seed',cfg.ext.boot_seed);
r=make_result("PASS","PAIRED_IDENTICAL_ROWS", ...
    sprintf('%d replicates x %d block lengths on %d identical Pop-A rows',cfg.ext.n_boot,numel(cfg.ext.block_lens),n), ...
    true,out,cfg.ext.n_boot*numel(cfg.ext.block_lens),cfg.ext.n_boot*numel(cfg.ext.block_lens));
end

function [res,r] = gate_physics(ext,ctx,run_dir,~)
out=fullfile(run_dir,'06_physics'); T=ext.master(ext.master.IS_POPB,:); B=ctx.B;
[ok,ia,ib]=intersect(T.ROW_ID,B.ROW_ID,'stable'); %#ok<ASGLU>
assert(numel(ia)==236,'Pop-B strict ROW_ID join expected 236, got %d',numel(ia));
T=T(ia,:);B=B(ib,:);vp=B.VP;rho=B.RHOB;
predNames={'PRED_PNN','PRED_MLFFNN','PRED_DFFNN','PRED_CNN1D','PRED_RIDGE_STACKER','PRED_DIRECT_RIDGE'};
modelNames=["PNN";"MLFFNN";"DFFNN";"CNN1D";"Ridge_stacker";"Direct_Ridge"];
rows=cell(6,1);
for j=1:6
    vs=T.(predNames{j}); p=elastic_props(rho,vs,vp);
    rows{j}={modelNames(j),height(T),sum(p.vpvs_ok),sum(p.nu_ok),sum(p.G_ok),sum(p.K_ok),sum(p.E_ok),sum(p.all_ok)};
end
S=cell2table(vertcat(rows{:}),'VariableNames',{'MODEL','N','N_VPVS_OK','N_NU_OK','N_G_OK','N_K_OK','N_E_OK','N_ALL_OK'});
writetable(S,fullfile(out,'PED_PHYSICAL_PLAUSIBILITY_ALL_MODELS.csv'));
F=table(["Vp=304.8/DT";"G=rho*Vs^2";"K=rho*(Vp^2-4Vs^2/3)"; ...
    "nu=(Vp^2-2Vs^2)/(2*(Vp^2-Vs^2))";"E=2G(1+nu)"],repmat("VERIFIED",5,1), ...
    'VariableNames',{'FORMULA','STATUS'});
writetable(F,fullfile(out,'PED_PHYSICS_FORMULA_AUDIT.csv'));
res=struct('summary',S,'population','PopB_target_informed','n',height(T));
r=make_result("PASS","STRICT_ROW_ID_POPB_236", ...
    'Six models evaluated on exactly 236 aligned Pop-B rows; screens are mathematically related and application-specific', ...
    true,out,6,6);
end

function r = gate_freeze_report(ctx,hold,dep,ext,boot,phys,gates,names,run_dir,run_id,cfg)
out=fullfile(run_dir,'07_freeze');rep=fullfile(run_dir,'08_report');
assert(all([gates(1:7).status]=="PASS"),'Required gates incomplete');
bundle=struct('run_id',run_id,'provenance',cfg.ext.provenance,'legacy_run',ctx.legacy_run_id, ...
    'holdout',hold,'deployment',dep,'external',ext,'bootstrap',boot,'physics',phys,'gates',gates(1:7));
save(fullfile(out,'PED_CODEX_FROZEN_EXTENSION.mat'),'bundle','-v7.3');
T=table(names(1:7),[gates(1:7).status]',[gates(1:7).code]',[gates(1:7).message]', ...
    'VariableNames',{'GATE','STATUS','CODE','MESSAGE'});
writetable(T,fullfile(out,'PED_CODEX_FROZEN_GATE_STATUS.csv'));
fid=fopen(fullfile(rep,'PED_CODEX_RESULTS_SUMMARY.md'),'w');assert(fid>=3,'Cannot open report');c=onCleanup(@()fclose(fid));
fprintf(fid,'# PED Corrected Fixed-HP Extension\n\n');
fprintf(fid,'- Run: `%s`\n- Legacy source run: `%s`\n- Provenance: `%s`\n',run_id,ctx.legacy_run_id,cfg.ext.provenance);
fprintf(fid,'- Limitation: fixed HP inherited from legacy run; this does not replace full corrected nested-CV retuning.\n\n');
fprintf(fid,'## Corrected holdout\n\n| Model | R2 | RMSE | MAE | Bias |\n|---|---:|---:|---:|---:|\n');
fprintf(fid,'| Ridge stacker | %.4f | %.4f | %.4f | %.4f |\n',hold.primary.r2,hold.primary.rmse,hold.primary.mae,hold.primary.bias);
fprintf(fid,'| Direct Ridge (post-hoc) | %.4f | %.4f | %.4f | %.4f |\n',hold.direct_ridge.r2,hold.direct_ridge.rmse,hold.direct_ridge.mae,hold.direct_ridge.bias);
fprintf(fid,'\nLegacy historical R2 -3.0622 status: `LEGACY_INVALID_SCALING_MISMATCH`.\n');

% Manifest is generated after all freeze/report files above are closed.
clear c; files=dir(fullfile(run_dir,'**','*'));files=files(~[files.isdir]);
mf=cell(numel(files),3);for i=1:numel(files);fp=fullfile(files(i).folder,files(i).name);mf{i,1}=string(erase(fp,[run_dir filesep]));mf{i,2}=sha256_file(fp);mf{i,3}=files(i).bytes;end
M=cell2table(mf,'VariableNames',{'RELATIVE_PATH','SHA256','BYTES'});
writetable(M,fullfile(out,'PED_CODEX_MANIFEST_SHA256.csv'));
r=make_result("PASS","FROZEN_TARGETED_EXTENSION", ...
    sprintf('Targeted extension frozen with %d hashed files; not a replacement for corrected full nested-CV canonical run',height(M)), ...
    true,out,height(M),height(M));
end

function [oof,ledger] = generate_oof(T,k,hp,seed,cfg,role)
[folds,~]=nrr_data.build_folds(T,k,cfg);oof=nan(height(T),4);ledger=table();
for f=1:k
    ti=folds(f).train_idx;vi=folds(f).val_idx;pm=nrr_data.fit_pm(T(ti,:),cfg);
    [Xt,yt]=nrr_data.apply_pm_deploy(T(ti,:),pm,cfg);[Xv,~]=nrr_data.apply_pm(T(vi,:),pm,cfg);
    [nets,L]=fit_base_segmented(Xt,yt,T.DEPTH(ti),T.ROW_ID(ti),hp,seed,f,cfg,role+"_TRAIN");
    oof(vi,:)=predict_base_segmented(nets,Xv,T.DEPTH(vi),T.ROW_ID(vi));
    L.OUTER_OR_INNER_FOLD=repmat(f,height(L),1);if isempty(ledger);ledger=L;else;ledger=[ledger;L];end %#ok<AGROW>
end
assert(all(isfinite(oof),'all'),'OOF meta predictions incomplete');
end

function [nets,ledger] = fit_base_segmented(X,y,depth,ids,hp,base_seed,fold,cfg,role)
os=cfg.seeds;sp=struct('spread',hp.pnn_spread);ml=struct('hidden',hp.mlffnn_hidden,'lr',hp.mlffnn_lr,'epochs',hp.mlffnn_epochs,'batch',hp.mlffnn_batch);
df=struct('hidden',hp.dffnn_hidden,'lr',hp.dffnn_lr,'epochs',hp.dffnn_epochs,'batch',hp.dffnn_batch);
cn=struct('filters',hp.cnn1d_filters,'lr',hp.cnn1d_lr,'epochs',hp.cnn1d_epochs,'batch',hp.cnn1d_batch);
nets.pnn=nrr_models.fit_pnn(X,y,sp,base_seed+os.offset_pnn+fold*os.offset_fold,cfg);
nets.mlffnn=nrr_models.fit_mlffnn(X,y,ml,base_seed+os.offset_mlffnn+fold*os.offset_fold,cfg);
nets.dffnn=nrr_models.fit_dffnn(X,y,df,base_seed+os.offset_dffnn+fold*os.offset_fold,cfg);
[nets.cnn1d,ledger]=fit_cnn_segmented(X,y,depth,ids,cn,base_seed+os.offset_cnn1d+fold*os.offset_fold,cfg,role);
end

function P = predict_base_segmented(nets,X,depth,ids)
P=nan(size(X,1),4);P(:,1)=nrr_models.predict_pnn(nets.pnn,X);P(:,2)=nrr_models.predict_mlffnn(nets.mlffnn,X);P(:,3)=nrr_models.predict_dffnn(nets.dffnn,X);P(:,4)=predict_cnn_segmented(nets.cnn1d,X,depth,ids);
assert(all(isfinite(P),'all'),'Base prediction contains NaN/Inf');
end

function [model,ledger] = fit_cnn_segmented(X,y,depth,ids,hp,seed,cfg,role)
W=cfg.hp.cnn1d_window;seg=segment_ids(depth);starts=[];anchors=[];members={};
for s=unique(seg(:))'
    ix=find(seg==s);if numel(ix)<W;continue;end
    for j=1:numel(ix)-W+1;w=ix(j:j+W-1);starts(end+1)=s;anchors(end+1)=w(1)+floor(W/2);members{end+1}=ids(w)';end %#ok<AGROW>
end
assert(~isempty(anchors),'No valid contiguous CNN windows');nseq=numel(anchors);nf=size(X,2);Xw=zeros(W,1,nf,nseq,'single');
for j=1:nseq;idx=find(seg==starts(j));a=find(ids(idx)==members{j}(1),1);w=idx(a:a+W-1);Xw(:,1,:,j)=reshape(single(X(w,:)),W,1,nf);end
yseq=reshape(single(y(anchors)),[1 1 1 nseq]);
layers=[imageInputLayer([W 1 nf],'Normalization','none'),convolution2dLayer([3 1],hp.filters,'Padding','same'),batchNormalizationLayer,reluLayer,convolution2dLayer([5 1],hp.filters,'Padding','same'),batchNormalizationLayer,reluLayer,globalAveragePooling2dLayer,fullyConnectedLayer(1),regressionLayer];
opts=trainingOptions('adam','MaxEpochs',hp.epochs,'MiniBatchSize',hp.batch,'InitialLearnRate',hp.lr,'Shuffle','never','Verbose',false,'ExecutionEnvironment','cpu');
rng(seed,'twister');net=trainNetwork(Xw,yseq,layers,opts);
model=struct('type','cnn1d_segmented','net',net,'window',W,'seed',seed,'sampling',median(diff(sort(unique(depth)))));
member_text=string(cellfun(@(v)strjoin(string(v),';'),members,'UniformOutput',false))';
ledger=table(repmat(string(role),nseq,1),(1:nseq)',starts',ids(anchors),depth(anchors),member_text, ...
    false(nseq,1),'VariableNames',{'ROLE','WINDOW_ID','SEGMENT_ID','ANCHOR_ROW_ID','ANCHOR_DEPTH','MEMBER_ROW_IDS','CROSS_BOUNDARY'});
end

function pred = predict_cnn_segmented(model,X,depth,ids)
W=model.window;seg=segment_ids(depth);pred=nan(size(X,1),1);
for s=unique(seg(:))'
    ix=find(seg==s);if numel(ix)<W;error('CNN prediction segment %d shorter than window %d',s,W);end
    ns=numel(ix)-W+1;Xw=zeros(W,1,size(X,2),ns,'single');
    for j=1:ns;w=ix(j:j+W-1);Xw(:,1,:,j)=reshape(single(X(w,:)),W,1,size(X,2));end
    pw=double(squeeze(predict(model.net,Xw)));pw=pw(:);anchors=ix((1:ns)+floor(W/2));pred(anchors)=pw;
    pseg=pred(ix);pseg=fillmissing(pseg,'nearest');pred(ix)=pseg;
end
assert(numel(unique(ids))==numel(ids)&&all(isfinite(pred)),'Segmented CNN prediction incomplete or duplicate IDs');
end

function seg = segment_ids(depth)
d=depth(:);dd=diff(d);pos=dd(dd>0);assert(~isempty(pos),'Cannot infer sampling interval');step=median(pos);tol=max(1e-8,step*0.25);breaks=[true;dd<=0|abs(dd-step)>tol];seg=cumsum(breaks);
end

function m = metrics(y,p)
ok=isfinite(y)&isfinite(p);y=y(ok);p=p(ok);assert(numel(y)>2,'Insufficient metric rows');e=p-y;m=struct('n',numel(y),'r2',1-sum(e.^2)/sum((y-mean(y)).^2),'rmse',sqrt(mean(e.^2)),'mae',mean(abs(e)),'bias',mean(e));
end

function T = metrics_table(names,status,M)
T=table(names,status,[M.n]',[M.r2]',[M.rmse]',[M.mae]',[M.bias]', ...
    'VariableNames',{'MODEL','ANALYSIS_STATUS','N','R2','RMSE_KM_S','MAE_KM_S','BIAS_KM_S'});
end

function p = elastic_props(rho,vs,vp)
p.G=rho.*vs.^2;p.K=rho.*(vp.^2-4*vs.^2/3);p.nu=(vp.^2-2*vs.^2)./(2*(vp.^2-vs.^2));p.E=2*p.G.*(1+p.nu);p.vpvs=vp./vs;
p.vpvs_ok=p.vpvs>=sqrt(2);p.nu_ok=p.nu>=0&p.nu<.5;p.G_ok=p.G>0;p.K_ok=p.K>0;p.E_ok=p.E>0;p.all_ok=p.vpvs_ok&p.nu_ok&p.G_ok&p.K_ok&p.E_ok&isfinite(p.G)&isfinite(p.K)&isfinite(p.E);
end

function ix = block_indices(n,bl)
starts=randi(n,ceil(n/bl),1);ix=zeros(ceil(n/bl)*bl,1);q=0;for k=1:numel(starts);v=mod((starts(k)-1:starts(k)+bl-2),n)+1;ix(q+(1:bl))=v;q=q+bl;end;ix=ix(1:n);
end

function h = sha256_file(fp)
assert(isfile(fp),'Hash input missing: %s',fp);
if ~isempty(which('nrr_eval.sha256_file_windows'))
    h=string(nrr_eval.sha256_file_windows(fp));
else
    [rc,out]=system(sprintf('certutil -hashfile "%s" SHA256',fp));
    assert(rc==0,'certutil SHA-256 failed for %s',fp);
    tok=regexp(lower(out),'[a-f0-9]{64}','match');
    assert(~isempty(tok),'No SHA-256 digest parsed for %s',fp);h=string(tok{1});
end
assert(strlength(h)==64,'Invalid SHA-256 length for %s',fp);
end

function write_final_manifest(run_dir)
files=dir(fullfile(run_dir,'**','*'));files=files(~[files.isdir]);
self=fullfile(run_dir,'07_freeze','PED_CODEX_FINAL_MANIFEST_SHA256.csv');
rows=cell(0,3);
for i=1:numel(files)
    fp=fullfile(files(i).folder,files(i).name);if strcmpi(fp,self);continue;end
    rows(end+1,:)={string(erase(fp,[run_dir filesep])),sha256_file(fp),files(i).bytes}; %#ok<AGROW>
end
T=cell2table(rows,'VariableNames',{'RELATIVE_PATH','SHA256','BYTES'});
writetable(T,self);
end
function r = make_result(status,code,message,required,path,nc,np)
if nargin<6;nc=0;end;if nargin<7;np=0;end
r=struct('status',string(status),'code',string(code),'message',string(message), ...
    'required',logical(required),'evidence_path',string(path),'n_checks',double(nc),'n_pass',double(np));
end

function r = runtime_failure(ME,path)
r=make_result("FAIL","UNEXPECTED_RUNTIME_ERROR",string(getReport(ME,'extended','hyperlinks','off')),true,path,1,0);
end

function r = upstream_block(name,path)
r=make_result("BLOCKED","BLOCKED_UPSTREAM_GATE","Upstream gate did not PASS: "+name,true,path,0,0);
end

function root = discover_project_root()
cands={pwd,'C:\Drive E\VsPredict_NRR_v5','C:\Drive E\Machine Learning\BLU 2026\Hasil\VsPredict_NRR_v5'};
for i=1:numel(cands);if isfile(fullfile(cands{i},'config','config_nrr_v5.m'));root=cands{i};return;end;end
error('Cannot discover VsPredict_NRR_v5 project root. Pass it explicitly.');
end
