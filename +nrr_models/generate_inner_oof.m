function [oof_meta, ledger_all] = generate_inner_oof(T_otr, inner_folds, hp, base_seed, outer_fold_id, cfg)
% NRR_MODELS.GENERATE_INNER_OOF  Fold-local, segment-aware OOF features.

n=height(T_otr); oof_meta=nan(n,4); ledger_parts=cell(cfg.cv.n_inner,1);
for fi=1:cfg.cv.n_inner
    ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
    T_train=T_otr(ti,:); T_val=T_otr(vi,:);
    pm=nrr_data.fit_pm(T_train,cfg);
    [Xi,yi]=nrr_data.apply_pm_deploy(T_train,pm,cfg);
    [Xv,~]=nrr_data.apply_pm(T_val,pm,cfg);
    seg_train=nrr_data.depth_segment_ids(T_train.(cfg.data.depth_col),cfg);
    seg_val=nrr_data.depth_segment_ids(T_val.(cfg.data.depth_col),cfg);
    [bn,led]=nrr_models.fit_base_set(Xi,yi,hp,base_seed, ...
        outer_fold_id*100+fi,cfg,seg_train);
    [oof_meta(vi,:),pa]=nrr_models.predict_base_set(bn,Xv,seg_val);
    led.OUTER_FOLD=repmat(outer_fold_id,height(led),1);
    led.INNER_FOLD=repmat(fi,height(led),1);
    led.PRED_RETAINED_CROSS_SEGMENT=zeros(height(led),1);
    led.PRED_RETAINED_CROSS_SEGMENT(led.MODEL=="cnn1d")= ...
        pa.N_RETAINED_CROSS_SEGMENT;
    ledger_parts{fi}=led;
end
ledger_all=vertcat(ledger_parts{:});
assert(all(isfinite(oof_meta),'all'), ...
    'generate_inner_oof: OOF matrix incomplete');
assert(all(ledger_all.N_RETAINED_CROSS_SEGMENT==0) && ...
    all(ledger_all.PRED_RETAINED_CROSS_SEGMENT==0), ...
    'generate_inner_oof: cross-segment window retained');
end
