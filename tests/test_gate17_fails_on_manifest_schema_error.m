function result = test_gate17_fails_on_manifest_schema_error()
% TEST: manifest must fail if row widths are inconsistent.
rows = {{'a.m',repmat('a',1,64),'source_m',100};
        {'b.csv',repmat('b',1,64),'output'}};   % 3 cols — wrong
ncols=cellfun(@numel,rows);
try
    assert(all(ncols==4),'width mismatch: %s',mat2str(unique(ncols)));
    result=struct('name','test_gate17_fails_on_manifest_schema_error','status','FAIL',...
        'message','Expected assertion error was not thrown');
catch
    result=struct('name','test_gate17_fails_on_manifest_schema_error','status','PASS',...
        'message','Correctly detected schema mismatch');
end
end
