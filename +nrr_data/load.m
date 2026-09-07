function [T_A, T_B, hashes] = load(repo_root, cfg)
% NRR_DATA.LOAD  Gate 1: load and standardize Well-A and Well-B.
%   Strips unit suffixes from column names ('DEPTH (M)' -> 'DEPTH').
%   Derives VS = 304.8/DTS, VP = 304.8/DT (km/s).
%   Adds ROW_ID and WELL_ID. Sorts by DEPTH.
%   Well-B target (VS) is loaded but NOT accessed by any Gate <= 11.

data_dir = fullfile(repo_root, 'data');
path_A = fullfile(data_dir, cfg.data.wellA_file);
path_B = fullfile(data_dir, cfg.data.wellB_file);

assert(isfile(path_A), '[G1] Well-A not found: %s', path_A);
assert(isfile(path_B), '[G1] Well-B not found: %s', path_B);

T_A = nrr_data.read_well(path_A, 'A', cfg);
T_B = nrr_data.read_well(path_B, 'B', cfg);

% Data-file hashes for reproducibility checker
hashes.A = nrr_data.file_hash(path_A);
hashes.B = nrr_data.file_hash(path_B);

% Column checks
req_A = [cfg.data.features, {cfg.data.target, cfg.data.depth_col, cfg.data.id_col}];
req_B = [cfg.data.features, {cfg.data.depth_col, cfg.data.id_col}];
for c = req_A
    assert(ismember(c{1}, T_A.Properties.VariableNames),'[G1] Well-A missing: %s',c{1});
end
for c = req_B
    assert(ismember(c{1}, T_B.Properties.VariableNames),'[G1] Well-B missing: %s',c{1});
end

fprintf('[G1] Well-A: %d rows | Well-B: %d rows\n', height(T_A), height(T_B));
end
