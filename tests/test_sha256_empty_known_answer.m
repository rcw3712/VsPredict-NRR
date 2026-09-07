function result = test_sha256_empty_known_answer()
% TEST: SHA-256(empty) = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
fp = [tempname() '.bin'];
fid=fopen(fp,'wb'); fclose(fid);
h  = nrr_eval.sha256_file_windows(fp);
delete(fp);
expected = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
if strcmp(h, expected)
    result=struct('name','test_sha256_empty_known_answer','status','PASS',...
        'message',sprintf('hash=%s',h));
else
    result=struct('name','test_sha256_empty_known_answer','status','FAIL',...
        'message',sprintf('got=%s expected=%s',h,expected));
end
end
