function result = test_sha256_known_answer()
% TEST: SHA-256 of ASCII "abc" must match known value.
fp = nrr_eval.write_temp_abc();
h  = nrr_eval.sha256_file_windows(fp);
delete(fp);
expected = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
ok = strcmp(h, expected);
if ok
    result = struct('name','test_sha256_known_answer','status','PASS',...
        'message',sprintf('hash=%s',h));
else
    result = struct('name','test_sha256_known_answer','status','FAIL',...
        'message',sprintf('got=%s expected=%s',h,expected));
end
end
