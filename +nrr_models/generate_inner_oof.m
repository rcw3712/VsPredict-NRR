function [oof_meta, ledger_all] = generate_inner_oof(T_otr, inner_folds, hp, base_seed, outer_fold_id, cfg)
% NRR_MODELS.GENERATE_INNER_OOF  Generate inner-OOF meta-features for stacker.
%   pm_otr is NOT passed — each inner fold fits its own preprocessor from raw.
%   Returns n_otr × 4 OOF matrix and seed ledger.

n=height(T_otr); oof_meta=nan(n,4); ledger_all={};
for fi=1:cfg.cv.n_inner
    ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
    pm=nrr_data.fit_pm(T_otr(ti,:),cfg);
    [Xi,yi]=nrr_data.apply_pm_deploy(T_otr(ti,:),pm,cfg);  % train rows
    [Xv,~ ]=nrr_data.apply_pm(T_otr(vi,:),pm,cfg);          % val rows
    [bn,led]=nrr_models.fit_base_set(Xi,yi,hp,base_seed,outer_fold_id*100+fi,cfg);
    oof_meta(vi,:)=nrr_models.predict_base_set(bn,Xv);
    ledger_all{end+1}=led;
end
ledger_all=vertcat(ledger_all{:});
end
