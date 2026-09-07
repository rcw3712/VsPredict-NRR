function h = sha256_file_windows(fp)
% NRR_EVAL.SHA256_FILE_WINDOWS  SHA-256 via pure MATLAB (no shell, no Java).
%   Reads file with fread, computes SHA-256 via sha256_bytes.m (FIPS 180-4).
%   No path quoting issues, no signed-byte conversion, no shell dependency.

fp = char(fp);
assert(isfile(fp), 'sha256_file_windows: file not found: %s', fp);

fid = fopen(fp, 'rb');
assert(fid > 0, 'sha256_file_windows: cannot open file: %s', fp);
data = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);

h = nrr_eval.sha256_bytes(data(:));

assert(numel(h)==64 && isempty(regexp(h,'[^a-f0-9]','once')), ...
    'sha256_file_windows: invalid hash format: "%s"', h);
assert(~strcmp(h, repmat('0',1,64)), ...
    'sha256_file_windows: zero-sentinel hash for %s', fp);
end
