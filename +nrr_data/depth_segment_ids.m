function [segment_ids, audit] = depth_segment_ids(depth, cfg)
% NRR_DATA.DEPTH_SEGMENT_IDS  Fail-closed segmentation from physical depth.
% Rows must be depth ordered. A new segment begins when depth does not
% increase or the increment departs materially from nominal sampling.

d = double(depth(:));
assert(~isempty(d) && all(isfinite(d)), ...
    'depth_segment_ids: depth must be finite and nonempty');
if isscalar(d)
    segment_ids = 1;
    audit = table(1,1,NaN,0,'VariableNames', ...
        {'N_ROWS','N_SEGMENTS','NOMINAL_STEP','BREAK_TOLERANCE'});
    return
end

dd = diff(d);
positive = dd(dd > 0 & isfinite(dd));
assert(~isempty(positive), ...
    'depth_segment_ids: cannot infer a positive sampling interval');
nominal = median(positive);
relative_tolerance = 0.25;
if isfield(cfg,'cnn') && isfield(cfg.cnn,'gap_relative_tolerance')
    relative_tolerance = cfg.cnn.gap_relative_tolerance;
end
tol = max(1e-8, relative_tolerance * nominal);
is_break = dd <= 0 | abs(dd - nominal) > tol;
segment_ids = cumsum([true; is_break]);
assert(numel(segment_ids)==numel(d) && all(segment_ids>=1), ...
    'depth_segment_ids: invalid segmentation result');
audit = table(numel(d),max(segment_ids),nominal,tol, ...
    'VariableNames',{'N_ROWS','N_SEGMENTS','NOMINAL_STEP','BREAK_TOLERANCE'});
end
