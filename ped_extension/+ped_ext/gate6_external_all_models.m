function result = gate6_external_all_models(ctx, pop_decision, ext_dir)
% PED_EXT.GATE6_EXTERNAL_ALL_MODELS  Canonical external inference for all models.
% Uses the frozen train-492 models and the same preprocessing/prediction APIs
% as the corrected canonical pipeline. Direct Ridge remains post-hoc.

out_dir=fullfile(ext_dir,'05_external_models');
T_pred=ctx.predictions;
assert(~isempty(T_pred),'gate6: canonical prediction table unavailable');
assert(all(ismember({'ROW_ID','VS_measured','VS_pred_raw','IS_POPA','IS_POPB'}, ...
    T_pred.Properties.VariableNames)),'gate6: canonical prediction schema incomplete');
assert(isfield(ctx.frozen_art,'deploy') && isfield(ctx.frozen_art,'posthoc'), ...
    'gate6: frozen deploy/posthoc models missing');
assert(isfield(ctx.frozen_num,'run') && isfield(ctx.frozen_num.run,'T_B_raw'), ...
    'gate6: frozen standardized Well-B table missing');

addpath(fullfile(ctx.project_root,'config'));
cfg=config_nrr_v5();
deploy=ctx.frozen_art.deploy;
posthoc=ctx.frozen_art.posthoc;
T_B=ctx.frozen_num.run.T_B_raw;
assert(height(T_B)==height(T_pred),'gate6: Well-B/prediction row count mismatch');
assert(all(double(T_B.ROW_ID)==double(T_pred.ROW_ID)), ...
    'gate6: Well-B/prediction ROW_ID order mismatch');

[X_B,~]=nrr_data.apply_pm_deploy(T_B,deploy.pm,cfg);
seg_B=nrr_data.depth_segment_ids(T_B.(cfg.data.depth_col),cfg);
[P_base,cnn_audit]=nrr_models.predict_base_set(deploy.base_nets,X_B,seg_B);
P_meta=nrr_models.apply_meta_scaler(P_base,deploy.meta_scaler);
y_stack=nrr_models.predict_ridge_stacker(deploy.stacker,P_meta);
assert(isfield(posthoc,'y_pred') && numel(posthoc.y_pred)==height(T_B), ...
    'gate6: frozen Direct Ridge predictions missing');
y_dr=double(posthoc.y_pred(:));
assert(max(abs(y_stack-double(T_pred.VS_pred_raw)))<=ctx.tol, ...
    'gate6: recomputed Ridge stacker differs from frozen row predictions');
assert(cnn_audit.N_RETAINED_CROSS_SEGMENT==0, ...
    'gate6: cross-segment CNN prediction window retained');

P_all=[P_base y_stack y_dr];
names=["PNN";"MLFFNN";"DFFNN";"CNN1D";"Ridge_stacker";"Direct_Ridge"];
statuses=[repmat("PRESPECIFIED_BASE",4,1);"PRESPECIFIED_PRIMARY";"POST_HOC_SENSITIVITY"];
popA=logical(T_pred.IS_POPA); popB=logical(T_pred.IS_POPB);
y=double(T_pred.VS_measured);
rows=cell(numel(names),1); r2vals=nan(numel(names),1);
for mi=1:numel(names)
    m=local_metrics(y(popA),P_all(popA,mi));
    r2vals(mi)=m.r2;
    rows{mi}={names(mi),statuses(mi),sum(popA),m.r2,m.rmse,m.mae,m.bias,m.med_ae, ...
        string(ternary(m.r2>0,'POSITIVE_R2','NEGATIVE_R2'))};
    fprintf('    %s Pop-A: R2=%.4f RMSE=%.4f bias=%+.4f\n',names(mi),m.r2,m.rmse,m.bias);
end
T_met=cell2table(vertcat(rows{:}),'VariableNames', ...
    {'MODEL','ANALYSIS_STATUS','N','R2','RMSE_km_s','MAE_km_s','BIAS_km_s','MED_AE_km_s','EXT_STATUS'});
writetable(T_met,fullfile(out_dir,'PED_EXTERNAL_ALL_MODELS_METRICS.csv'));
writetable(table(T_pred.ROW_ID,T_pred.DEPTH,y,P_all(:,1),P_all(:,2),P_all(:,3), ...
    P_all(:,4),P_all(:,5),P_all(:,6),popA,popB, ...
    'VariableNames',{'ROW_ID','DEPTH','VS_MEASURED','PRED_PNN','PRED_MLFFNN', ...
    'PRED_DFFNN','PRED_CNN1D','PRED_RIDGE_STACKER','PRED_DIRECT_RIDGE','IS_POPA','IS_POPB'}), ...
    fullfile(out_dir,'PED_EXTERNAL_ALL_MODELS_ROW_PREDICTIONS.csv'));
writetable(cnn_audit,fullfile(out_dir,'PED_EXTERNAL_CNN_PREDICTION_AUDIT.csv'));

base_r2=r2vals(1:4); stack_r2=r2vals(5); dr_r2=r2vals(6);
if stack_r2<0 && dr_r2>0 && any(base_r2>0)
    verdict='STACKER_FAILURE_IS_MODEL_SPECIFIC';
elseif stack_r2<0 && dr_r2>0
    verdict='DIRECT_RIDGE_TRANSFERS_WHILE_STACKER_FAILS';
elseif all(base_r2<0) && stack_r2<0
    verdict='ALL_PRESPECIFIED_COMPLEX_MODELS_FAIL';
else
    verdict='MIXED_EXTERNAL_TRANSFER';
end
writetable(table(names,statuses,r2vals,r2vals<0, ...
    'VariableNames',{'MODEL','STATUS','R2_POPA','R2_NEGATIVE'}), ...
    fullfile(out_dir,'PED_MODEL_EXTRAPOLATION_SUMMARY.csv'));

fmd=fopen(fullfile(out_dir,'PED_EXTERNAL_MODEL_COMPARISON.md'),'w');
fprintf(fmd,'# External Model Comparison - Pop-A (n=%d)\n\n',sum(popA));
fprintf(fmd,'**Verdict: %s**\n\n',verdict);
fprintf(fmd,'All predictions use frozen train-492 models and canonical segment-aware inference.\n');
fprintf(fmd,'Direct Ridge is post-hoc sensitivity evidence and cannot redefine the primary analysis.\n');
fclose(fmd);

result.verdict=verdict; result.T_metrics=T_met; result.r2_vals=r2vals;
result.all_preds=P_all(popA,:); result.all_preds_all=P_all;
result.all_preds_popB=P_all(popB,:); result.y_true_popA=y(popA);
result.y_true_popB=y(popB); result.popA_mask=popA; result.popB_mask=popB;
result.n_popA=sum(popA); result.n_popB=sum(popB);
result.gate_result=struct('status',string('PASS'),'code',string('OK'), ...
    'message',string(sprintf('All six frozen-model predictions verified; verdict=%s',verdict)), ...
    'required',true,'evidence_path',string(out_dir),'n_checks',8,'n_pass',8);
end

function m=local_metrics(y,yp)
assert(numel(y)==numel(yp) && all(isfinite(yp)),'gate6: incomplete prediction vector');
m.r2=1-sum((y-yp).^2)/sum((y-mean(y)).^2);
m.rmse=sqrt(mean((y-yp).^2)); m.mae=mean(abs(y-yp));
m.bias=mean(yp-y); m.med_ae=median(abs(y-yp));
end

function s=ternary(tf,a,b)
if tf; s=a; else; s=b; end
end
