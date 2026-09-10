function T_out = normalize_table_schema(T_in)
% VALIDATION.NORMALIZE_TABLE_SCHEMA  Fix cell/string type mismatches.
%   Converts all string-like columns to string scalar arrays.
%   Numeric columns remain numeric.
%   Prevents vertcat failures from mixed char/string types.

T_out = T_in;
for ci = 1:width(T_out)
    col = T_out.(ci);
    if iscell(col)
        % Convert cell array to string or double
        if all(cellfun(@(x) ischar(x) || isstring(x), col))
            T_out.(ci) = string(col);
        elseif all(cellfun(@(x) isnumeric(x) && isscalar(x), col))
            T_out.(ci) = cell2mat(col);
        else
            % Mixed: convert to string
            T_out.(ci) = string(col);
        end
    elseif ischar(col)
        T_out.(ci) = string(col);
    end
    % Numeric arrays: leave as-is
end
end
