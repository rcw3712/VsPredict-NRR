function T = nrr_strip_units(T)
% NRR_STRIP_UNITS  Strip unit suffix from column names: 'DEPTH (M)' -> 'DEPTH'.
cols = T.Properties.VariableNames;
T.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '), cols, 'UniformOutput', false);
end
