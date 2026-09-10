function hash = sha256_file(filepath)
% VALIDATION.SHA256_FILE  Compute SHA-256 hex digest of a file.
%   Tries: (1) MATLAB built-in, (2) Java MessageDigest, (3) system certutil/sha256sum.

hash = '';

% ── Method 1: MATLAB built-in (R2023a+) ─────────────────────────────────
try
    hash = lower(matlab.security.crypto.hash('SHA-256', filepath, 'file'));
    return;
catch
end

% ── Method 2: Java MessageDigest ─────────────────────────────────────────
try
    md  = java.security.MessageDigest.getInstance('SHA-256');
    fis = java.io.FileInputStream(java.io.File(filepath));
    buf = javaArray('byte', 8192);
    n   = fis.read(buf);
    while n > 0
        md.update(buf, 0, n);
        n = fis.read(buf);
    end
    fis.close();
    digest_bytes = md.digest();
    % Convert signed Java bytes to hex string
    nb = numel(digest_bytes);
    hex_parts = cell(nb, 1);
    for i = 1:nb
        b = double(digest_bytes(i));
        if b < 0; b = b + 256; end
        hex_parts{i} = sprintf('%02x', b);
    end
    hash = lower(strjoin(hex_parts, ''));
    return;
catch
end

% ── Method 3: System command ──────────────────────────────────────────────
try
    if ispc
        [rc, out] = system(sprintf('certutil -hashfile "%s" SHA256 2>nul', filepath));
        if rc == 0
            lines = strtrim(strsplit(strtrim(out), newline));
            % certutil output: line 1 = header, line 2 = hash, line 3 = "CertUtil..."
            for li = 1:numel(lines)
                ln = strtrim(lines{li});
                if numel(ln) == 64 && all(ismember(lower(ln), '0123456789abcdef'))
                    hash = lower(ln);
                    return;
                end
            end
        end
    else
        [rc, out] = system(sprintf('sha256sum "%s" 2>/dev/null', filepath));
        if rc == 0
            parts = strsplit(strtrim(out), ' ');
            if ~isempty(parts) && numel(strtrim(parts{1})) == 64
                hash = lower(strtrim(parts{1}));
                return;
            end
        end
    end
catch
end

% ── Fallback: return empty (caller handles gracefully) ────────────────────
if isempty(hash)
    hash = 'HASH_UNAVAILABLE';
end
end
