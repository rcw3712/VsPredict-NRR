function h = file_hash(path)
% NRR_DATA.FILE_HASH  Compute simple hash of file bytes for reproducibility.
try
    fid=fopen(path,'rb'); raw=fread(fid); fclose(fid);
    h=num2str(sum(double(raw)));
catch
    h='hash_unavailable';
end
end
