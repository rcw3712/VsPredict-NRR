function result = test_manifest_all_rows_four_columns()
% TEST: all manifest rows must have exactly 4 columns.
rows = {{'a.m',repmat('a',1,64),'source_m',100};
        {'b.csv',repmat('b',1,64),'output',200}};
ncols = cellfun(@numel,rows);
if all(ncols==4)
    result=struct('name','test_manifest_all_rows_four_columns','status','PASS',...
        'message','All rows 4 columns');
else
    result=struct('name','test_manifest_all_rows_four_columns','status','FAIL',...
        'message',sprintf('Row widths: %s',mat2str(ncols)));
end
end
