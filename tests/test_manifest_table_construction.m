function result = test_manifest_table_construction()
% TEST: cell2table with 4-column rows must succeed.
rows = {{'file1.m',repmat('a',1,64),'source_m',double(1024)};
        {'file2.csv',repmat('b',1,64),'output',double(512)}};
ncols=cellfun(@numel,rows);
assert(all(ncols==4));
try
    raw=vertcat(rows{:});
    T=cell2table(raw,'VariableNames',{'FILE','SHA256','CATEGORY','BYTES'});
    T.BYTES=str2double(string(T.BYTES));
    assert(height(T)==2 && all(isfinite(T.BYTES)));
    result=struct('name','test_manifest_table_construction','status','PASS',...
        'message',sprintf('%d rows constructed',height(T)));
catch e
    result=struct('name','test_manifest_table_construction','status','FAIL',...
        'message',e.message);
end
end
