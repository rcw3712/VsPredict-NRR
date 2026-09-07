function [X, y] = transform(T_raw, pm, cfg)
% NRR_DATA.TRANSFORM  Apply scaling and imputation from fitted pm.
feats=pm.feats; n=height(T_raw); X=zeros(n,numel(feats));
for fi=1:numel(feats)
    f=feats{fi}; v=T_raw.(f); miss=isnan(v)|~isfinite(v);
    if any(miss); v(miss)=pm.impute.(f).med; end
    X(:,fi)=(v-pm.scaler.(f).mu)/pm.scaler.(f).sg;
end
if ismember(pm.target,T_raw.Properties.VariableNames)
    y=T_raw.(pm.target);
else
    y=nan(n,1);
end
end
