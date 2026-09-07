function out = nrr_clean_string_column(col)
% NRR_CLEAN_STRING_COLUMN  Normalize column to cellstr safely.
%   Handles: char, string, cellstr, categorical, double.
if iscell(col)
    out = cellfun(@(x) char(string(x)), col, 'UniformOutput', false);
elseif isstring(col)
    out = cellstr(col);
elseif iscategorical(col)
    out = cellstr(col);
elseif isnumeric(col)
    out = arrayfun(@(x) num2str(x), col, 'UniformOutput', false);
else
    out = cellstr(string(col));
end
end
