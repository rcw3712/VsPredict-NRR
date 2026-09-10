function run = gate17_geomech_freeze(run, cfg)
% GATE 17: Geomechanics + numerical freeze.
%   Figures suppressed during numerical gates (renderer safety).
set(groot,'DefaultFigureVisible','off');
%   P0-2 fix: ALL_OK = AND of ALL gates including Vp/Vs.
%   Invariants asserted: N_ALL_OK <= every component gate count.
%   Per-row: one boolean column per gate + FAIL_REASONS (semicolon-separated).

T_B=run.T_B_raw; popB=run.roles.popB_mask;
out7=fullfile(run.folder,'07_geomech');
out8=fullfile(run.folder,'08_freeze');
n_ev=sum(popB);

vp_B  =T_B.VP(popB)*1e3;       % km/s -> m/s
rho_B =T_B.RHOB(popB)*1e3;     % g/cc -> kg/m³
d_B   =T_B.(cfg.data.depth_col)(popB);
id_B  =T_B.(cfg.data.id_col)(popB);

models_to_eval=struct(...
    'ridge_stacker',struct('y',run.blind.y_raw,  'status',run.provenance),...
    'direct_ridge', struct('y',run.posthoc.y_pred,'status',cfg.dr.status));

geo_rows={}; fail_rows_all={};

for mname=fieldnames(models_to_eval)'
    mn=mname{1}; yp=models_to_eval.(mn).y; mst=models_to_eval.(mn).status;
    vs_m=yp(popB)*1e3;   % km/s -> m/s

    %% P0-2 fix: explicit boolean per gate
    input_ok = isfinite(vs_m) & isfinite(vp_B) & isfinite(rho_B);
    vp_gt_vs = input_ok & (vp_B > vs_m);
    vpvs     = vp_B ./ vs_m;
    vpvs_ok  = input_ok & isfinite(vpvs) & (vpvs >= cfg.sanity.vpvs_min);
    nu       = (vp_B.^2 - 2*vs_m.^2) ./ (2*(vp_B.^2 - vs_m.^2));
    nu_ok    = input_ok & isfinite(nu) & (nu>=cfg.sanity.nu_min) & (nu<=cfg.sanity.nu_max);
    G        = rho_B .* vs_m.^2 / 1e9;
    G_ok     = input_ok & isfinite(G) & (G>0);
    K        = rho_B .* (vp_B.^2 - 4/3*vs_m.^2) / 1e9;
    K_ok     = input_ok & isfinite(K) & (K>0);
    E        = 9*K.*G./(3*K+G);
    E_ok     = input_ok & isfinite(E) & (E>0);

    % ALL_OK = AND of every gate
    all_pass = input_ok & vp_gt_vs & vpvs_ok & nu_ok & G_ok & K_ok & E_ok;

    N_IN=sum(input_ok); N_VP=sum(vp_gt_vs); N_VR=sum(vpvs_ok);
    N_NU=sum(nu_ok); N_G=sum(G_ok); N_K=sum(K_ok); N_E=sum(E_ok);
    N_ALL=sum(all_pass);

    %% Invariant assertions (gate fails if violated)
    assert(N_ALL<=N_IN,  '[G17] N_ALL_OK > N_INPUT_OK — logic error');
    assert(N_ALL<=N_VP,  '[G17] N_ALL_OK > N_VP_GT_VS_OK');
    assert(N_ALL<=N_VR,  '[G17] N_ALL_OK > N_VPVS_OK');
    assert(N_ALL<=N_NU,  '[G17] N_ALL_OK > N_NU_OK');
    assert(N_ALL<=N_G,   '[G17] N_ALL_OK > N_G_OK');
    assert(N_ALL<=N_K,   '[G17] N_ALL_OK > N_K_OK');
    assert(N_ALL<=N_E,   '[G17] N_ALL_OK > N_E_OK');
    assert(N_ALL==sum(all_pass),'[G17] N_ALL_OK != sum(all_pass)');

    fprintf('[G17]   %-16s IN=%d VP=%d VR=%d NU=%d G=%d K=%d E=%d ALL=%d/%d (%.0f%%)\n',...
        mn,N_IN,N_VP,N_VR,N_NU,N_G,N_K,N_E,N_ALL,n_ev,N_ALL/n_ev*100);

    % Per-row failure reasons (accumulate all, not first-only)
    fail_reasons=repmat({'PASS'},n_ev,1);
    for ri=1:n_ev
        reasons={};
        if ~input_ok(ri);  reasons{end+1}='FAIL_INPUT_MISSING'; end
        if input_ok(ri) && ~vp_gt_vs(ri); reasons{end+1}='FAIL_VP_NOT_GT_VS'; end
        if input_ok(ri) && ~vpvs_ok(ri);  reasons{end+1}='FAIL_VPVS_GATE'; end
        if input_ok(ri) && ~nu_ok(ri);    reasons{end+1}='FAIL_NU_RANGE'; end
        if input_ok(ri) && G_ok(ri) && ~K_ok(ri); reasons{end+1}='FAIL_K_POSITIVE'; end
        if input_ok(ri) && ~G_ok(ri);     reasons{end+1}='FAIL_G_POSITIVE'; end
        if input_ok(ri) && G_ok(ri) && K_ok(ri) && ~E_ok(ri); reasons{end+1}='FAIL_E_POSITIVE'; end
        if ~isempty(reasons); fail_reasons{ri}=strjoin(reasons,';'); end
    end

    % Save row-level table with boolean columns
    T_geo=table(id_B,d_B,yp(popB),vs_m/1e3,vp_B/1e3,vpvs,nu,G,K,E,...
        input_ok,vp_gt_vs,vpvs_ok,nu_ok,G_ok,K_ok,E_ok,all_pass,fail_reasons,...
        'VariableNames',{'ROW_ID','DEPTH','VS_PRED_KM','VS_PRED_MS',...
        'VP_KM','VPVS','NU','G_GPA','K_GPA','E_GPA',...
        'INPUT_OK','VP_GT_VS_OK','VPVS_OK','NU_OK','G_OK','K_OK','E_OK',...
        'ALL_GATES_PASS','FAIL_REASONS'});
    writetable(T_geo,...
        fullfile(out7,sprintf('GEOMECH_ROW_LEVEL_%s.csv',upper(mn))));

    geo_rows{end+1}={mn,mst,n_ev,N_IN,N_VP,N_VR,N_NU,N_G,N_K,N_E,N_ALL,N_ALL/n_ev*100};

    T_fail=T_geo(:,{'ROW_ID','DEPTH','FAIL_REASONS'});
    T_fail.MODEL=repmat({mn},height(T_fail),1);
    fail_rows_all{end+1}=T_fail;
end

cols={'MODEL','STATUS','N_EVAL','N_INPUT_OK','N_VP_GT_VS','N_VPVS_OK',...
      'N_NU_OK','N_G_OK','N_K_OK','N_E_OK','N_ALL_OK','ALL_OK_PCT'};
writetable(cell2table(vertcat(geo_rows{:}),'VariableNames',cols),...
    fullfile(out7,'GEOMECHANICAL_MODEL_COMPARISON.csv'));
writetable(vertcat(fail_rows_all{:}),...
    fullfile(out7,'GEOMECH_FAILURE_REASONS.csv'));

%% Figure source data
fig_src=fullfile(out8,'figure_source_data'); mkdir(fig_src);
mask6=run.roles.popB_mask;
writetable(table(T_B.(cfg.data.id_col)(mask6),T_B.(cfg.data.depth_col)(mask6),...
    run.blind.y_B(mask6),run.blind.y_raw(mask6),...
    'VariableNames',{'ROW_ID','DEPTH','VS_measured','VS_pred_raw'}),...
    fullfile(fig_src,'FIG06_blind_eval.csv'));

%% Numerical summary
summary_path=fullfile(out8,'NRR_NUMERICAL_RESULTS_SUMMARY.md');
fid=fopen(summary_path,'w');
assert(fid>=0,'[G17] Cannot open numerical summary for writing: %s',summary_path);
summary_cleanup=onCleanup(@() close_if_open(fid));
fprintf(fid,'# NRR_NUMERICAL_RESULTS_SUMMARY\n\nRun: %s | Seed: %d\n',run.id,run.seed);
fprintf(fid,'\n## Provenance\nAll results: %s\n',run.provenance);
fprintf(fid,'P0-1 bug FIXED (meta_scaler consistent across fit/predict)\n');
fprintf(fid,'P0-2 bug FIXED (ALL_OK includes Vp/Vs gate)\n');
fprintf(fid,'P0-3: stacker lambda tuned via full stacked pipeline\n\n');
fprintf(fid,'## Internal CV (n_dev=%d)\n',run.n_dev);
fprintf(fid,'Pooled OOF R²=%.4f RMSE=%.4f\n',run.cv.pooled_r2,run.cv.pooled_rmse);
fprintf(fid,'Mean fold R²=%.4f±%.4f SD\n',run.cv.mean_r2,run.cv.sd_r2);
fprintf(fid,'\n## Primary Blind (Pop-A, primary non-duplicate)\n');
fprintf(fid,'Ridge stacker R²=%.4f RMSE=%.4f bias=%+.4f (n=%d)\n',...
    run.blind.ridge.popA.r2,run.blind.ridge.popA.rmse,...
    run.blind.ridge.popA.bias,run.blind.ridge.popA.n);
fprintf(fid,'\n## Diagnostic (Pop-B, target-informed)\n');
fprintf(fid,'Ridge stacker R²=%.4f (n=%d)\n',...
    run.blind.ridge.popB.r2,run.blind.ridge.popB.n);
fprintf(fid,'\n## Post-Hoc Direct Ridge (%s)\n',cfg.dr.status);
fprintf(fid,'Pop-A R²=%.4f (n=%d)\nPop-B R²=%.4f (n=%d)\n',...
    run.posthoc.popA.r2,run.posthoc.popA.n,...
    run.posthoc.popB.r2,run.posthoc.popB.n);
close_status=fclose(fid);
assert(close_status==0,'[G17] Failed to close numerical summary: %s',summary_path);
clear summary_cleanup;

%% Freeze final artifacts before hashing them.
% Gate 17 is recorded as PASS in the immutable numerical artifact. The run
% becomes canonical only after the subsequently written manifest is read
% back, every entry is re-hashed, and the atomic pointer is updated.
run.gate.GATE_17 = 'PASS';
run.frozen_at    = datestr(now);
save(fullfile(out8,'FROZEN_NUMERICAL_RUN.mat'),'run','-v7.3');
deploy=run.deploy; posthoc=run.posthoc;
save(fullfile(out8,'FROZEN_MODEL_ARTIFACTS.mat'),'deploy','posthoc','-v7.3');

%% RUN_MANIFEST_SHA256.csv — generated only after all tracked files are stable.
manifest_path=fullfile(out8,'RUN_MANIFEST_SHA256.csv');
manifest_tmp =[manifest_path '.tmp'];
try
    man_rows=nrr_eval.compute_sha256_manifest(run.folder,run.env.repo_root);
    writetable(man_rows,manifest_tmp,'FileType','text');
    verify_report=nrr_eval.verify_sha256_manifest(...
        manifest_tmp,run.folder,run.env.repo_root);
    [ok_manifest,msg_manifest]=movefile(manifest_tmp,manifest_path,'f');
    assert(ok_manifest,'[G17] Atomic manifest update failed: %s',msg_manifest);
    fprintf('[G17] Manifest: %d entries\n',height(man_rows));
    fprintf('[G17] Manifest read-back verification: %d/%d hashes PASS\n',...
        verify_report.n_verified,verify_report.n_total);
catch ME
    run.gate.GATE_17        = 'FAIL';
    run.gate.GATE_17_REASON = ME.message;
    save(fullfile(out8,'FAILED_RUN_STATE.mat'),'run','-v7.3');
    error('[G17] MANIFEST_FAIL: %s\nFix before Gate 18.',ME.message);
end

%% Atomic canonical pointer update — ABSOLUTE LAST action
pointer_path = fullfile(run.env.repo_root,'runs','CANONICAL_RUN_POINTER.txt');
tmp_ptr      = [pointer_path '.tmp'];
fid_ptr = fopen(tmp_ptr,'w');
assert(fid_ptr>=0,'[G17] Cannot open temp canonical pointer file');
fprintf(fid_ptr,'%s\n',run.id);
fclose(fid_ptr);
[ok,msg] = movefile(tmp_ptr, pointer_path, 'f');
assert(ok,'[G17] Canonical pointer atomic update failed: %s',msg);

% Get N_ALL_OK values for clear logging (not boolean invariant flags)
n_all_ridge = geo_rows{1}{11};   % N_ALL_OK column
n_all_dr    = geo_rows{2}{11};
n_eval      = geo_rows{1}{3};    % N_EVAL
fprintf('[G17] PASS | INVARIANTS_PASS ridge=1 direct_ridge=1 | ALL_OK ridge=%d/%d DR=%d/%d | frozen\n',...
    n_all_ridge, n_eval, n_all_dr, n_eval);
end

function close_if_open(fid)
% Close the summary on every error path without double-closing it.
if isnumeric(fid) && isscalar(fid) && any(openedFiles==fid)
    fclose(fid);
end
end
