function sc = apply_meta_scaler(meta_raw, ms)
% NRR_MODELS.APPLY_META_SCALER  Apply fitted meta scaler to raw meta-features.
%   Uses mu and sg from fit_meta_scaler — never recomputes them.
%   NaN OOF values imputed with column mean before scaling.

assert(strcmp(ms.input_space,'raw_meta'), ...
    'apply_meta_scaler: scaler expects raw_meta input');
assert(size(meta_raw,2) == numel(ms.mu), ...
    'apply_meta_scaler: column mismatch (%d vs %d)', size(meta_raw,2), numel(ms.mu));

sc = meta_raw;
for ci = 1:size(sc,2)
    nan_m = isnan(sc(:,ci));
    if any(nan_m); sc(nan_m,ci) = ms.mu(ci); end   % impute with training mean
    sc(:,ci) = (sc(:,ci) - ms.mu(ci)) / ms.sg(ci);
end
sc(~isfinite(sc)) = 0;

assert(all(isfinite(sc(:))), 'apply_meta_scaler: NaN/Inf in scaled output');
end
