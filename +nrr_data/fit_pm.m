function pm = fit_pm(T_raw, cfg)
% NRR_DATA.FIT_PM  Fit fold-local preprocessor from raw training table.
%   Must be called only on training rows.
%   pm stores mu, sigma, imputation median per feature.
feats=cfg.data.features; pm=struct();
pm.feats=feats; pm.target=cfg.data.target;
pm.n_train=height(T_raw); pm.train_ids=T_raw.(cfg.data.id_col);
pm.scaler=struct(); pm.impute=struct();
for fi=1:numel(feats)
    f=feats{fi}; v=T_raw.(f); ok=~isnan(v)&isfinite(v);
    assert(sum(ok)>=2,'fit_pm: %s has <2 valid values',f);
    pm.scaler.(f).mu=mean(v(ok)); pm.scaler.(f).sg=std(v(ok));
    if pm.scaler.(f).sg<1e-9; pm.scaler.(f).sg=1; end
    pm.impute.(f).med=median(v(ok)); pm.impute.(f).n_miss=sum(~ok);
end
pm.hash=sprintf('%s|n=%d|sum_id=%d',strjoin(feats,','),...
    pm.n_train,sum(pm.train_ids));
end
