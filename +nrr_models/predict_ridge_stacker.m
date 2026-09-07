function y_pred = predict_ridge_stacker(stacker, meta_sc)
% NRR_MODELS.PREDICT_RIDGE_STACKER  Single deployment prediction API.
%   meta_sc MUST be standardized_meta (output of apply_meta_scaler).
%   P0-1 fix: all prediction paths use this function — never manual formula.

assert(strcmp(stacker.input_space,'standardized_meta'), ...
    'predict_ridge_stacker: stacker expects standardized_meta input');
assert(isequal(size(meta_sc,2), numel(stacker.B)), ...
    'predict_ridge_stacker: column mismatch (%d vs %d)', size(meta_sc,2), numel(stacker.B));
assert(all(isfinite(meta_sc(:))), ...
    'predict_ridge_stacker: NaN/Inf in input meta_sc');

y_pred = meta_sc * stacker.B + stacker.b0;

assert(all(isfinite(y_pred)), ...
    'predict_ridge_stacker: NaN/Inf in output predictions');

% Range sanity — error (not warning) if median is outside physical VS range
VS_MIN = 0.5; VS_MAX = 4.0;
if median(y_pred) < VS_MIN || median(y_pred) > VS_MAX
    error('predict_ridge_stacker: prediction median=%.3f outside physical VS range [%.1f,%.1f]; check scaling/model', ...
        median(y_pred), VS_MIN, VS_MAX);
end
end
