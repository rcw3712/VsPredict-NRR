function run = gate9_provenance(run, cfg)
% NRR_EVAL.GATE9_PROVENANCE  Gate 9: historical provenance labeling.
%   Per audit P1.2: labels Ridge stacker as V5_CORRECTED_REANALYSIS.
%   Does NOT claim historical selection reproduced — only designates model family.

T_dev =run.T_A_raw(run.roles.dev_mask,:);
T_hold=run.T_A_raw(run.roles.hold_mask,:);
out3  =fullfile(run.folder,'03_models');
hp    =run.cv.fold_hp{end};   % use last outer fold HP as representative

pm_dev=nrr_data.fit_pm(T_dev,cfg);
[X_d,y_d]=nrr_data.apply_pm_deploy(T_dev,pm_dev,cfg);
[X_h,y_h]=nrr_data.apply_pm(T_hold,pm_dev,cfg);

% Fit and predict on holdout (Level-1 selection set)
[inner_f,~]=nrr_data.build_folds(T_dev,cfg.cv.n_inner,cfg);
[oof_m,~]=nrr_models.generate_inner_oof(T_dev,inner_f,hp,...
    cfg.seeds.canonical,0,cfg);
stacker=nrr_models.fit_ridge_stacker(oof_m,y_d,hp.ridge_lambda,cfg);
[base_nets,~]=nrr_models.fit_base_set(X_d,y_d,hp,cfg.seeds.canonical,0,cfg);
meta_h=nrr_models.predict_base_set(base_nets,X_h);
mu_m=nanmean(oof_m); sg_m=nanstd(oof_m); sg_m(sg_m<1e-9)=1;
meta_h_sc=(meta_h-mu_m)./sg_m; meta_h_sc(isnan(meta_h_sc))=0;
y_pred_h=meta_h_sc*stacker.B+stacker.b0;
ok_h=~isnan(y_h); h_r2=nrr_eval.r2(y_h(ok_h),y_pred_h(ok_h));

% HISTORICAL_PROVENANCE_STATUS.csv — V5_CORRECTED_REANALYSIS
writetable(table({'ridge_stacker'},...
    {'V5_CORRECTED_REANALYSIS'},...
    h_r2,...
    {sprintf('holdout_fold_%d_n%d',cfg.cv.holdout_fold,run.n_hold)},...
    {'model_family_designated_in_v4_refit_with_v5_leakage_free_pipeline'},...
    'VariableNames',{'MODEL','PROVENANCE_CLASS','HOLDOUT_R2',...
    'SELECTION_SET','NOTE'}),...
    fullfile(out3,'HISTORICAL_PROVENANCE_STATUS.csv'));

run.hist.model='ridge_stacker';
run.hist.holdout_r2=h_r2;
run.hist.hp=hp;
run.hist.provenance='V5_CORRECTED_REANALYSIS';
run.hist.selection_set=sprintf('holdout_fold_%d_n%d',cfg.cv.holdout_fold,run.n_hold);

run.gate.GATE_9='PASS';
fprintf('[G9] PASS — Ridge stacker holdout R²=%.4f | V5_CORRECTED_REANALYSIS\n',h_r2);
end
