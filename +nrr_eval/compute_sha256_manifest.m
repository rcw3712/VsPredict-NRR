function T = compute_sha256_manifest(run_folder, repo_root)
% NRR_EVAL.COMPUTE_SHA256_MANIFEST  Build SHA-256 manifest with uniform 4-column schema.
%   Schema: FILE (string, normalized relative path), SHA256 (64-hex lowercase),
%           CATEGORY (string), BYTES (double, non-negative).
%   All rows are 4 elements. vertcat will fail if schema is violated.
%   Excludes: RUN_MANIFEST_SHA256.csv (self), *.tmp files.
%   Gate 17 will FAIL if any hash is zero or invalid.

%% Known-answer test 1: SHA-256('abc')
abc_fp = nrr_eval.write_temp_abc();
h_abc  = nrr_eval.sha256_file_windows(abc_fp);
delete(abc_fp);
exp_abc = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
assert(strcmp(h_abc, exp_abc), ...
    'SHA256 abc KAT FAILED: got %s expected %s', h_abc, exp_abc);

%% Known-answer test 2: SHA-256(empty)
tmp_empty = [tempname() '.bin'];
fid_e = fopen(tmp_empty, 'wb'); fclose(fid_e);
h_empty = nrr_eval.sha256_file_windows(tmp_empty);
delete(tmp_empty);
exp_empty = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
assert(strcmp(h_empty, exp_empty), ...
    'SHA256 empty KAT FAILED: got %s expected %s', h_empty, exp_empty);

fprintf('[SHA256] KAT abc: PASS | KAT empty: PASS\n');

rows = {};   % each element is {FILE, SHA256, CATEGORY, BYTES} — always 4

%% Source .m files (single loop; classify by path)
src = dir(fullfile(repo_root, '**', '*.m'));
for i = 1:numel(src)
    fp  = fullfile(src(i).folder, src(i).name);
    rel = nrr_eval.rel_path(fp, repo_root);
    if startsWith(rel, 'config/')
        cat = 'config';
    elseif startsWith(rel, 'tests/')
        cat = 'test_source';
    else
        cat = 'source_m';
    end
    h = nrr_eval.sha256_file_windows(fp);
    rows{end+1} = {rel, h, cat, double(src(i).bytes)};
end

%% Data files
for df = {'Well-A.xlsx', 'Well-B.xlsx'}
    fp = fullfile(repo_root, 'data', df{1});
    if isfile(fp)
        d  = dir(fp);
        h  = nrr_eval.sha256_file_windows(fp);
        rows{end+1} = {['data/' df{1}], h, 'data', double(d.bytes)};
    end
end

%% Run output files — recursive, excludes self and temps
manifest_self = fullfile(run_folder, '08_freeze', 'RUN_MANIFEST_SHA256.csv');
all_out = dir(fullfile(run_folder, '**', '*'));
all_out = all_out(~[all_out.isdir]);

for di = 1:numel(all_out)
    fp = fullfile(all_out(di).folder, all_out(di).name);
    if strcmp(fp, manifest_self); continue; end
    if endsWith(fp, '.tmp');      continue; end
    rel = nrr_eval.rel_path(fp, run_folder);
    h   = nrr_eval.sha256_file_windows(fp);
    rows{end+1} = {rel, h, 'output', double(all_out(di).bytes)};
end

%% Assert uniform 4-column schema before vertcat
assert(~isempty(rows), 'compute_sha256_manifest: no rows collected');
ncols = cellfun(@numel, rows);
assert(all(ncols == 4), ...
    'Manifest row-width mismatch: expected 4, got %s', mat2str(unique(ncols)));

%% Build table
raw = vertcat(rows{:});
T   = cell2table(raw, 'VariableNames', {'FILE','SHA256','CATEGORY','BYTES'});
T.FILE     = string(T.FILE);
T.SHA256   = lower(string(T.SHA256));
T.CATEGORY = string(T.CATEGORY);
T.BYTES    = str2double(string(T.BYTES));

%% Validate table
assert(all(isfinite(T.BYTES) & T.BYTES >= 0), ...
    'Manifest contains invalid BYTES values');
assert(numel(unique(T.FILE)) == height(T), ...
    'Manifest contains %d duplicate FILE entries', height(T)-numel(unique(T.FILE)));

valid_hash = ~cellfun(@isempty, regexp(cellstr(T.SHA256), '^[a-f0-9]{64}$', 'once'));
assert(all(valid_hash), ...
    'Manifest contains %d invalid SHA256 entries', sum(~valid_hash));

zero_h = string(repmat('0', 1, 64));
assert(~any(strcmpi(T.SHA256, zero_h)), ...
    'Manifest contains zero-placeholder SHA256 hashes — hashing failed');

fprintf('[SHA256] Manifest: %d entries, 0 zeros, 0 invalid, 0 duplicates\n', height(T));
end
