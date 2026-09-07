function fp = write_temp_abc()
% NRR_EVAL.WRITE_TEMP_ABC  Write temp file with exactly 3 bytes: 0x61 0x62 0x63 (abc).
%   SHA-256(abc) = ba7816bf8f01cfea414140de5dae2ec73b00361a396177a9cb410ff61f20015ad
fp = [tempname() '.bin'];
fid = fopen(fp, 'wb');
assert(fid > 0, 'write_temp_abc: cannot open temp file');
fwrite(fid, uint8([97 98 99]), 'uint8');   % 'a','b','c' — no newline, no BOM
fclose(fid);
% Verify file size is exactly 3 bytes
d = dir(fp);
assert(d.bytes == 3, 'write_temp_abc: expected 3 bytes, got %d', d.bytes);
end
