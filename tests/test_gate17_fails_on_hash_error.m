function result = test_gate17_fails_on_hash_error()
% TEST: sha256_file_windows must throw on nonexistent file.
try
    nrr_eval.sha256_file_windows('/nonexistent/path/file.m');
    result=struct('name','test_gate17_fails_on_hash_error','status','FAIL',...
        'message','Expected error for nonexistent file — none thrown');
catch
    result=struct('name','test_gate17_fails_on_hash_error','status','PASS',...
        'message','Correctly threw on nonexistent file');
end
end
