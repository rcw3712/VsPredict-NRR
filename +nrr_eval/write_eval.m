function write_eval(m, model, status, fpath)
% Assert Direct Ridge never labeled primary/confirmatory in reports
if strcmp(model,'direct_ridge')
    assert(~strcmp(status,'primary'),'write_eval: DR cannot be primary');
    assert(~strcmp(status,'confirmatory'),'write_eval: DR cannot be confirmatory');
end
writetable(table({model},{status},m.n,m.r2,m.rmse,m.bias,m.mae,...
    'VariableNames',{'MODEL','STATUS','N','R2','RMSE','BIAS','MAE'}),fpath);
end
