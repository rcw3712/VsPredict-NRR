function result = test_sha256_mutation()
% TEST: changing one byte changes the hash.
fp = nrr_eval.write_temp_abc();
h1 = nrr_eval.sha256_file_windows(fp);
% Overwrite with 'abd'
fid=fopen(fp,'wb'); fwrite(fid,uint8('abd'),'uint8'); fclose(fid);
h2 = nrr_eval.sha256_file_windows(fp);
delete(fp);
if ~strcmp(h1,h2)
    result=struct('name','test_sha256_mutation','status','PASS',...
        'message','hash changed on mutation');
else
    result=struct('name','test_sha256_mutation','status','FAIL',...
        'message','hash did NOT change on mutation');
end
end
