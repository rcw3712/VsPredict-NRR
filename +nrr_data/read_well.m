function T = read_well(path, well_label, cfg)
% NRR_DATA.READ_WELL  Read Excel, normalize column names, derive VS and VP.
%   'DEPTH (M)' -> 'DEPTH', 'GR (API)' -> 'GR', etc.
%   VS [km/s] = 304.8 / DTS [us/ft]
%   VP [km/s] = 304.8 / DT  [us/ft]
%   VPVS = VP / VS

T = readtable(path, 'VariableNamingRule', 'preserve');

% Normalize: strip everything from first space onward
raw = T.Properties.VariableNames;
clean = cellfun(@(s) strsplit(strtrim(s),' '), raw, 'UniformOutput', false);
clean = cellfun(@(c) c{1}, clean, 'UniformOutput', false);
T.Properties.VariableNames = clean;

% Derive VS from DTS
if ~ismember('VS', T.Properties.VariableNames) && ismember('DTS', T.Properties.VariableNames)
    T.VS = 304.8 ./ T.DTS;   % km/s
end
% Derive VP from DT
if ~ismember('VP', T.Properties.VariableNames) && ismember('DT', T.Properties.VariableNames)
    T.VP = 304.8 ./ T.DT;    % km/s
end
% Compute VPVS
if ismember('VP', T.Properties.VariableNames) && ismember('VS', T.Properties.VariableNames)
    T.VPVS = T.VP ./ T.VS;
end

% Sort by depth first, then assign ROW_ID
T = sortrows(T, cfg.data.depth_col);
if ~ismember(cfg.data.id_col, T.Properties.VariableNames)
    T.(cfg.data.id_col) = (1:height(T))';
end
if ~ismember(cfg.data.wellid_col, T.Properties.VariableNames)
    T.(cfg.data.wellid_col) = repmat({['Well-' well_label]}, height(T), 1);
end

cols = T.Properties.VariableNames;
fprintf('[load]   %s: %d rows | cols: %s\n', well_label, height(T), strjoin(cols,', '));
end
