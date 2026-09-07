function [X, y, ids] = apply_pm_deploy(T_raw, pm, cfg)
% NRR_DATA.APPLY_PM_DEPLOY  Apply preprocessor WITHOUT leakage check.
%   Use for training rows and Well-B deployment.
ids=T_raw.(cfg.data.id_col);
[X,y]=nrr_data.transform(T_raw,pm,cfg);
end
