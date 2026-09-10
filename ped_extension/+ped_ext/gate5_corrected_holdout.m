function result = gate5_corrected_holdout(ctx, ext_dir)
% PED_EXT.GATE5_CORRECTED_HOLDOUT  Verify corrected canonical holdout evidence.
% No refit is performed here: the corrected canonical run already executed the
% full train-392 pipeline using fold-local OOF meta-features and scaled meta input.

out_dir = fullfile(ext_dir,'04_holdout');
metrics_path = fullfile(ctx.canonical_dir,'03_models','CORRECTED_HOLDOUT_MODEL_METRICS.csv');
pred_path = fullfile(ctx.canonical_dir,'03_models','CORRECTED_HOLDOUT_ROW_PREDICTIONS.csv');
prov_path = fullfile(ctx.canonical_dir,'03_models','HISTORICAL_PROVENANCE_STATUS.csv');
required = {metrics_path,pred_path,prov_path};
assert(all(cellfun(@isfile,required)), ...
    'gate5: corrected holdout artifacts are incomplete in canonical run');
assert(isfield(ctx.frozen_num,'run') && isfield(ctx.frozen_num.run,'hist'), ...
    'gate5: frozen run.hist evidence missing');

Tm = readtable(metrics_path,'TextType','string');
Tp = readtable(pred_path,'TextType','string');
Tv = readtable(prov_path,'TextType','string');
assert(height(Tp)==ctx.n_holdout,'gate5: expected %d holdout rows, found %d', ...
    ctx.n_holdout,height(Tp));
assert(all(ismember({'VS_MEASURED','PRED_RIDGE_STACKER','PRED_DIRECT_RIDGE'}, ...
    Tp.Properties.VariableNames)),'gate5: required holdout prediction columns missing');

ridge_idx = strcmpi(string(Tm.MODEL),'Ridge_stacker');
dr_idx = strcmpi(string(Tm.MODEL),'Direct_Ridge');
assert(sum(ridge_idx)==1 && sum(dr_idx)==1,'gate5: model rows missing or duplicated');

y = double(Tp.VS_MEASURED);
yr = double(Tp.PRED_RIDGE_STACKER);
yd = double(Tp.PRED_DIRECT_RIDGE);
mr = local_metrics(y,yr);
md = local_metrics(y,yd);
tol = ctx.tol;
assert(abs(mr.r2-double(Tm.R2(ridge_idx)))<=tol,'gate5: Ridge R2 CSV mismatch');
assert(abs(md.r2-double(Tm.R2(dr_idx)))<=tol,'gate5: Direct Ridge R2 CSV mismatch');
assert(abs(mr.r2-ctx.frozen_num.run.hist.holdout_r2)<=tol, ...
    'gate5: frozen run.hist R2 mismatch');
assert(strcmp(string(ctx.frozen_num.run.hist.legacy_status), ...
    "LEGACY_INVALID_RAW_META_SCALING"),'gate5: legacy provenance label mismatch');
assert(all(isfinite([yr;yd])),'gate5: non-finite holdout prediction');

writetable(Tm,fullfile(out_dir,'PED_HOLDOUT_CORRECTED_MODEL_METRICS.csv'));
writetable(Tp,fullfile(out_dir,'PED_HOLDOUT_CORRECTED_PREDICTIONS.csv'));
writetable(Tv,fullfile(out_dir,'PED_HOLDOUT_PROVENANCE_STATUS.csv'));

fmd=fopen(fullfile(out_dir,'PED_HOLDOUT_RECONCILIATION.md'),'w');
fprintf(fmd,'# Corrected Same-Well Holdout Verification\n\n');
fprintf(fmd,'The corrected canonical train-392 Ridge-stacker pipeline was verified from frozen artifacts.\n\n');
fprintf(fmd,'- Ridge stacker: R2 = %.4f, RMSE = %.4f km/s, bias = %.4f km/s\n',mr.r2,mr.rmse,mr.bias);
fprintf(fmd,'- Direct Ridge (post-hoc exploratory): R2 = %.4f, RMSE = %.4f km/s\n',md.r2,md.rmse);
fprintf(fmd,'- Legacy R2 = %.4f is classified as `%s` and must not be reported as a valid result.\n', ...
    ctx.frozen_num.run.hist.legacy_r2,ctx.frozen_num.run.hist.legacy_status);
fclose(fmd);

fprintf('    Corrected frozen holdout verified: Ridge R2=%.4f | Direct Ridge R2=%.4f\n', ...
    mr.r2,md.r2);
result.r2=mr.r2; result.rmse=mr.rmse; result.mae=mr.mae; result.bias=mr.bias;
result.direct_ridge=md; result.historical_r2=ctx.frozen_num.run.hist.legacy_r2;
result.classification='CORRECTED_CANONICAL_RIDGE_STACKER_VERIFIED';
result.T_predictions=Tp; result.T_metrics=Tm;
result.gate_result=struct('status',string('PASS'),'code',string('OK'), ...
    'message',string(sprintf('Corrected canonical holdout verified: Ridge R2=%.4f; legacy result invalidated',mr.r2)), ...
    'required',true,'evidence_path',string(out_dir),'n_checks',6,'n_pass',6);
end

function m=local_metrics(y,yp)
m.r2=1-sum((y-yp).^2)/sum((y-mean(y)).^2);
m.rmse=sqrt(mean((y-yp).^2));
m.mae=mean(abs(y-yp));
m.bias=mean(yp-y);
end
