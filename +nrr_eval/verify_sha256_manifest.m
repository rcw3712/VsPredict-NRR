function report = verify_sha256_manifest(manifest_path, run_folder, repo_root)
% NRR_EVAL.VERIFY_SHA256_MANIFEST  Fail-closed read-back verification.
%   Re-reads the serialized manifest and checks existence, byte count, and
%   SHA-256 for every source, data, and output entry.

assert(isfile(manifest_path),...
    'verify_sha256_manifest:MANIFEST_MISSING: %s',manifest_path);

T=readtable(manifest_path,'FileType','text','TextType','string');
required={'FILE','SHA256','CATEGORY','BYTES'};
assert(all(ismember(required,T.Properties.VariableNames)),...
    'verify_sha256_manifest:SCHEMA_INVALID');
assert(height(T)>0,'verify_sha256_manifest:MANIFEST_EMPTY');
assert(numel(unique(T.FILE))==height(T),...
    'verify_sha256_manifest:DUPLICATE_PATHS');

valid_hash=~cellfun(@isempty,regexp(cellstr(lower(T.SHA256)),...
    '^[a-f0-9]{64}$','once'));
assert(all(valid_hash),'verify_sha256_manifest:INVALID_HASH_FORMAT');

for i=1:height(T)
    rel=char(T.FILE(i));
    rel_native=strrep(rel,'/',filesep);
    if strcmpi(char(T.CATEGORY(i)),'output')
        fp=fullfile(run_folder,rel_native);
    else
        fp=fullfile(repo_root,rel_native);
    end
    assert(isfile(fp),...
        'verify_sha256_manifest:FILE_MISSING: %s',rel);
    d=dir(fp);
    expected_bytes=double(T.BYTES(i));
    assert(double(d.bytes)==expected_bytes,...
        'verify_sha256_manifest:BYTE_MISMATCH: %s expected=%g actual=%g',...
        rel,expected_bytes,double(d.bytes));
    actual=nrr_eval.sha256_file_windows(fp);
    assert(strcmpi(actual,char(T.SHA256(i))),...
        'verify_sha256_manifest:HASH_MISMATCH: %s',rel);
end

report=struct('status','PASS','n_verified',height(T),'n_total',height(T));
end
