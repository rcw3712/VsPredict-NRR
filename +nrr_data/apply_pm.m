function [X, y, ids] = apply_pm(T_raw, pm, cfg)
% NRR_DATA.APPLY_PM  Apply preprocessor WITH anti-leakage assertion.
%   Use for validation/test rows only.
%   Asserts no overlap between T_raw row IDs and pm.train_ids.
ids=T_raw.(cfg.data.id_col);
overlap=intersect(ids,pm.train_ids);
assert(isempty(overlap),...
    'apply_pm: %d rows in both val and train — LEAKAGE DETECTED',numel(overlap));
[X,y]=nrr_data.transform(T_raw,pm,cfg);
end
