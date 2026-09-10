function run = run_nested_cv(run, cfg)
% NRR_EVAL.RUN_NESTED_CV  Gates 6-8: true nested depth-blocked CV.
%   P0-1 fix: meta_scaler fitted on training OOF only;
%             stacker fitted on scaled OOF;
%             prediction via predict_ridge_stacker API only.
%   P0-3 fix: lambda tuned using full stacked pipeline in inner loop.

T_dev=run.T_A_raw(run.roles.dev_mask,:);
k=cfg.cv.n_outer; n_dev=height(T_dev);
out2=fullfile(run.folder,'02_cv');

oof_pred=nan(n_dev,1); oof_true=nan(n_dev,1); oof_ids=zeros(n_dev,1);
base_oof=nan(n_dev,4);
fold_metrics=repmat(struct('r2',NaN,'rmse',NaN,'mae',NaN,'bias',NaN,'n',0),k,1);
fold_hp=cell(k,1);
hp_log_all={}; seed_ledger={}; inner_fold_log={};

fprintf('[G6-8] True nested CV (outer=%d inner=%d)...\n',k,cfg.cv.n_inner);

for fo=1:k
    vi=run.outer_folds(fo).val_idx;
    ti=run.outer_folds(fo).train_idx;
    T_otr=T_dev(ti,:); T_ov=T_dev(vi,:);

    %% Gate 6: inner HP tuning — full stacked pipeline (P0-3)
    inner_folds=nrr_data.build_folds(T_otr,cfg.cv.n_inner,cfg);
    [best_hp,hp_log]=nrr_models.tune_inner_stacked(T_otr,inner_folds,...
        cfg.seeds.canonical,fo,cfg);
    fold_hp{fo}=best_hp;
    hp_log_all{end+1}=hp_log;

    fprintf('[G6-8]   Fold %d/%d: spread=%.2f lambda=%.4f\n',...
        fo,k,best_hp.pnn_spread,best_hp.ridge_lambda);

    %% Gate 7: outer-fold fitting from raw tables
    % 7a: inner OOF meta-features for stacker training
    [oof_meta,ledger]=nrr_models.generate_inner_oof(T_otr,inner_folds,best_hp,...
        cfg.seeds.canonical,fo,cfg);
    seed_ledger{end+1}=ledger;

    for fi2=1:cfg.cv.n_inner
        vi_i=inner_folds(fi2).val_idx;
        inner_fold_log{end+1}={fo,fi2,...
            T_otr.(cfg.data.id_col)(vi_i),...
            T_otr.(cfg.data.depth_col)(vi_i)};
    end

    % 7b: full base learners on outer-train
    pm_otr=nrr_data.fit_pm(T_otr,cfg);
    [X_otr,y_otr]=nrr_data.apply_pm_deploy(T_otr,pm_otr,cfg);
    seg_otr=nrr_data.depth_segment_ids(T_otr.(cfg.data.depth_col),cfg);
    [base_nets,led2]=nrr_models.fit_base_set(X_otr,y_otr,best_hp,...
        cfg.seeds.canonical,fo,cfg,seg_otr);
    assert(all(led2.N_RETAINED_CROSS_SEGMENT==0), ...
        '[G7] cross-segment CNN training window retained');
    seed_ledger{end+1}=led2;

    % 7c: fit meta_scaler on inner OOF (training data only — P0-1)
    meta_scaler=nrr_models.fit_meta_scaler(oof_meta);
    oof_sc=nrr_models.apply_meta_scaler(oof_meta,meta_scaler);

    % 7d: fit stacker on SCALED OOF (P0-1 fix)
    stacker=nrr_models.fit_ridge_stacker(oof_sc,y_otr,best_hp.ridge_lambda,cfg);
    assert(strcmp(stacker.input_space,'standardized_meta'),...
        '[G7] stacker.input_space must be standardized_meta');

    % 7e: predict outer-val using single API (P0-1 fix)
    [X_ov,y_ov]=nrr_data.apply_pm(T_ov,pm_otr,cfg);
    seg_ov=nrr_data.depth_segment_ids(T_ov.(cfg.data.depth_col),cfg);
    [meta_ov,pred_audit]=nrr_models.predict_base_set(base_nets,X_ov,seg_ov);
    assert(pred_audit.N_RETAINED_CROSS_SEGMENT==0, ...
        '[G7] cross-segment CNN validation window retained');
    meta_ov_sc=nrr_models.apply_meta_scaler(meta_ov,meta_scaler);  % same scaler
    y_pred_ov=nrr_models.predict_ridge_stacker(stacker,meta_ov_sc);% single API

    oof_ids(vi)=T_ov.(cfg.data.id_col);
    oof_pred(vi)=y_pred_ov;
    oof_true(vi)=y_ov;
    base_oof(vi,:)=meta_ov;

    ok_v=~isnan(y_ov)&~isnan(y_pred_ov);
    fold_metrics(fo)=nrr_eval.metrics(y_ov(ok_v),y_pred_ov(ok_v));
    fprintf('[G6-8]   Fold %d: R²=%.4f RMSE=%.4f\n',fo,...
        fold_metrics(fo).r2,fold_metrics(fo).rmse);
end

%% Gate 8: validate OOF assembly
assert(numel(unique(oof_ids))==n_dev&&~any(oof_ids==0),...
    '[G8] Not all dev rows have exactly one OOF prediction');
assert(all(isfinite(oof_pred)),'[G8] NaN/Inf in OOF predictions');

ok_all=~isnan(oof_true)&~isnan(oof_pred);
run.cv.pooled_r2   =nrr_eval.r2(oof_true(ok_all),oof_pred(ok_all));
run.cv.pooled_rmse =sqrt(mean((oof_true(ok_all)-oof_pred(ok_all)).^2));
run.cv.mean_r2     =mean([fold_metrics.r2]);
run.cv.sd_r2       =std([fold_metrics.r2]);
run.cv.mean_rmse   =mean([fold_metrics.rmse]);
run.cv.sd_rmse     =std([fold_metrics.rmse]);
run.cv.fold_metrics=fold_metrics; run.cv.fold_hp=fold_hp;
run.cv.oof_pred=oof_pred; run.cv.oof_true=oof_true; run.cv.oof_ids=oof_ids;
run.cv.base_oof=base_oof;
run.cv.cnn_window_status='PASS_ZERO_RETAINED_CROSS_SEGMENT';

writetable(table(oof_ids,oof_true,oof_pred,'VariableNames',...
    {'ROW_ID','VS_measured','VS_pred_OOF'}),...
    fullfile(out2,'NESTED_CV_OUTER_OOF_PREDICTIONS.csv'));
writetable(array2table(base_oof,'VariableNames',{'PNN','MLFFNN','DFFNN','CNN1D'}),...
    fullfile(out2,'BASE_MODEL_OUTER_OOF_PREDICTIONS.csv'));

T_fm=struct2table(fold_metrics); T_fm.FOLD=(1:k)';
T_fm.HP_SPREAD=cellfun(@(h)h.pnn_spread,fold_hp);
T_fm.HP_LAMBDA=cellfun(@(h)h.ridge_lambda,fold_hp);
writetable(T_fm,fullfile(out2,'NESTED_CV_OUTER_FOLD_METRICS.csv'));

if ~isempty(hp_log_all)
    writetable(vertcat(hp_log_all{:}),...
        fullfile(out2,'INNER_CV_HYPERPARAMETER_RESULTS.csv'));
end

% Inner fold assignments
inner_rows={};
for k2=1:numel(inner_fold_log)
    e=inner_fold_log{k2};
    ids=e{3}; dep=e{4};
    for ri=1:numel(ids)
        inner_rows{end+1}={e{1},e{2},ids(ri),dep(ri)};
    end
end
if ~isempty(inner_rows)
    writetable(cell2table(vertcat(inner_rows{:}),'VariableNames',...
        {'OUTER_FOLD','INNER_FOLD','ROW_ID','DEPTH'}),...
        fullfile(out2,'INNER_FOLD_ASSIGNMENTS.csv'));
end

if ~isempty(seed_ledger)
    writetable(vertcat(seed_ledger{:}),...
        fullfile(run.folder,'00_environment','SEED_LEDGER.csv'));
end

fid=fopen(fullfile(out2,'NESTED_CV_SUMMARY.txt'),'w');
fprintf(fid,'Pooled OOF R2=%.4f RMSE=%.4f\n',run.cv.pooled_r2,run.cv.pooled_rmse);
fprintf(fid,'Mean fold R2=%.4f+/-%.4f SD\n',run.cv.mean_r2,run.cv.sd_r2);
fprintf(fid,'NOTE: Pooled weights folds by size. Both reported per audit.\n');
fclose(fid);

run.gate.GATE_6='PASS'; run.gate.GATE_7='PASS'; run.gate.GATE_8='PASS';
fprintf('[G6-8] PASS — pooled R²=%.4f | mean fold R²=%.4f±%.4f\n',...
    run.cv.pooled_r2,run.cv.mean_r2,run.cv.sd_r2);
end
