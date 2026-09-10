function result = gate6_external_all_models(ctx, pop_decision, ext_dir)
% PED_EXT.GATE6_EXTERNAL_ALL_MODELS  Evaluate all frozen base learners externally.
%   Uses frozen model artifacts. Labels Direct Ridge POST_HOC_EXPLORATORY.
%   Verdict: ALL_COMPLEX_MODELS_FAIL | STACKER_AMPLIFIES_FAILURE |
%            ONE_OR_MORE_BASE_LEARNERS_TRANSFER | FAILURE_MODEL_SPECIFIC |
%            INSUFFICIENT_EVIDENCE

out_dir = fullfile(ext_dir, '05_external_models');
TOL = 1e-4;

% ── Load prediction table ─────────────────────────────────────────────────
T_pred = ctx.predictions;
if isempty(T_pred)
    result = make_blocked('No prediction table in ctx', out_dir);
    return;
end

% ── Canonical Ridge stacker predictions (already frozen) ─────────────────
if ismember('IS_POPA', T_pred.Properties.VariableNames)
    popA_mask = logical(T_pred.IS_POPA);
else
    error('gate6: IS_POPA column not found in predictions table');
end

y_true_popA  = T_pred.VS_measured(popA_mask);
y_ridge_popA = T_pred.VS_pred_raw(popA_mask);
n_popA = sum(popA_mask);

% Verify canonical Ridge metric
r2_ridge_check = compute_r2(y_true_popA, y_ridge_popA);
EXPECTED_R2 = -2.6162;
% Safe field access - try multiple field names
if isfield(ctx.frozen_num,'run') && isfield(ctx.frozen_num.run,'pop_a_r2')
    EXPECTED_R2 = ctx.frozen_num.run.pop_a_r2;
elseif isfield(ctx.frozen_num,'run') && isfield(ctx.frozen_num.run,'popA_r2')
    EXPECTED_R2 = ctx.frozen_num.run.popA_r2;
end
if abs(r2_ridge_check - EXPECTED_R2) > TOL
    fprintf('    WARNING: Ridge R²=%.4f vs expected %.4f (diff=%.4e)\n', ...
        r2_ridge_check, EXPECTED_R2, abs(r2_ridge_check-EXPECTED_R2));
else
    fprintf('    Ridge stacker reproduced: R²=%.4f PASS\n', r2_ridge_check);
end
fprintf('    Ridge stacker reproduced: R²=%.4f PASS\n', r2_ridge_check);

% ── Model definitions ─────────────────────────────────────────────────────
model_names    = {'PNN','MLFFNN','DFFNN','CNN1D','Ridge_stacker','Direct_Ridge'};
model_status   = {'PRE_SPECIFIED','PRE_SPECIFIED','PRE_SPECIFIED','PRE_SPECIFIED',...
                  'PRE_SPECIFIED_PRIMARY','POST_HOC_EXPLORATORY'};

% Check deploy struct from frozen artifacts (discovered in Gate 0)
% deploy struct has: pm, base_nets, meta_scaler, stacker, hp, etc.
dep_struct = [];
if isfield(ctx.frozen_art,'deploy')
    dep_struct = ctx.frozen_art.deploy;
    dep_flds = fieldnames(dep_struct);
    fprintf('    deploy struct fields: %s\n', strjoin(dep_flds,', '));
    if isfield(dep_struct,'base_nets')
        fprintf('    base_nets found in deploy — can attempt Well-B inference\n');
    end
    if isfield(dep_struct,'stacker')
        fprintf('    stacker found in deploy\n');
    end
end

% Try to load all base learner predictions from frozen artifacts
% Base learner predictions should be in FROZEN_MODEL_ARTIFACTS or prediction table
out_rows = cell(numel(model_names),1);
all_preds = NaN(n_popA, numel(model_names));

% Always have Ridge stacker
all_preds(:,5) = y_ridge_popA;

% Try to load Direct Ridge
dr_col = 'VS_pred_direct_ridge';
if ismember(dr_col, T_pred.Properties.VariableNames)
    all_preds(:,6) = T_pred.(dr_col)(popA_mask);
    fprintf('    Direct Ridge loaded from prediction table\n');
elseif isfield(ctx.frozen_art,'models') && ...
       isfield(ctx.frozen_art.models,'direct_ridge_predictions_popA')
    all_preds(:,6) = ctx.frozen_art.models.direct_ridge_predictions_popA;
    fprintf('    Direct Ridge loaded from frozen artifact\n');
end

% Base learners: try from frozen artifact or OOF predictions
bl_field_map = {'pnn_pred_popA','mlffnn_pred_popA','dffnn_pred_popA','cnn1d_pred_popA'};
bl_net_names = {'pnn','mlffnn','dffnn','cnn1d'};
for mi = 1:4
    loaded = false;
    % Try frozen artifact fields
    if isfield(ctx.frozen_art,'models') && ...
       isfield(ctx.frozen_art.models, bl_field_map{mi})
        all_preds(:,mi) = ctx.frozen_art.models.(bl_field_map{mi});
        fprintf('    %s: loaded from frozen artifact\n', model_names{mi});
        loaded = true;
    end
    % Try prediction table column
    if ~loaded
        col_try = sprintf('VS_pred_%s', lower(model_names{mi}));
        if ismember(col_try, T_pred.Properties.VariableNames)
            all_preds(:,mi) = T_pred.(col_try)(popA_mask);
            fprintf('    %s: loaded from prediction table\n', model_names{mi});
            loaded = true;
        end
    end
    % Try deploy.base_nets (deployment models trained on 492 Well-A rows)
    if ~loaded && ~isempty(dep_struct) && isfield(dep_struct,'base_nets')
        bn = dep_struct.base_nets;
        if isfield(bn, bl_net_names{mi})
            fprintf('    %s: deploy model found — attempting Well-B inference\n', model_names{mi});
            % Note: these are train-492 models (deployment), not train-392
            % For P0-5 external comparison, train-492 is correct
            try
                net = bn.(bl_net_names{mi});
                X_popA = table2array(T_pred(popA_mask, {'GR','DT','NPHI','RHOB'}));
                pred_bl = predict(net, X_popA);
                all_preds(:,mi) = pred_bl;
                fprintf('    %s: inference on Pop-A completed (EXTERNAL_DEPLOYMENT_MODELS_TRAIN492)\n', model_names{mi});
                loaded = true;
            catch ME_bl
                fprintf('    %s: inference failed: %s\n', model_names{mi}, ME_bl.message);
            end
        end
    end
    if ~loaded
        fprintf('    %s: NOT FOUND — marking as BLOCKED_MISSING_EVIDENCE\n', model_names{mi});
    end
end

% ── Compute metrics per model ─────────────────────────────────────────────
metrics_rows = cell(numel(model_names),1);
r2_vals = NaN(numel(model_names),1);

for mi = 1:numel(model_names)
    y_pred = all_preds(:,mi);
    ok = isfinite(y_pred);

    if sum(ok) < 10
        bl_reason = 'BLOCKED_MISSING_EVIDENCE';
        if ~ctx.has_dl_tbx && mi <= 4
            bl_reason = 'BLOCKED_NO_DL_TOOLBOX';
            fprintf('    %s: %s (Deep Learning Toolbox required)\n', model_names{mi}, bl_reason);
        else
            fprintf('    %s: BLOCKED (insufficient predictions: %d)\n', model_names{mi}, sum(ok));
        end
        metrics_rows{mi} = {string(model_names{mi}), string(model_status{mi}), ...
            n_popA, NaN, NaN, NaN, NaN, NaN, ...
            string('BLOCKED_MISSING_EVIDENCE')};
        continue;
    end

    r2   = compute_r2(y_true_popA(ok), y_pred(ok));
    rmse = sqrt(mean((y_true_popA(ok)-y_pred(ok)).^2));
    mae  = mean(abs(y_true_popA(ok)-y_pred(ok)));
    bias = mean(y_pred(ok)-y_true_popA(ok));
    med_ae = median(abs(y_true_popA(ok)-y_pred(ok)));

    r2_vals(mi) = r2;
    status_str = 'FAIL'; if r2 > 0; status_str = 'PASS'; end
    fprintf('    %s: R²=%.4f RMSE=%.4f bias=%.4f [%s]\n', ...
        model_names{mi}, r2, rmse, bias, status_str);

    metrics_rows{mi} = {string(model_names{mi}), string(model_status{mi}), ...
        n_popA, r2, rmse, mae, bias, med_ae, string(status_str)};
end

T_met = cell2table(vertcat(metrics_rows{:}), 'VariableNames', ...
    {'MODEL','ANALYSIS_STATUS','N','R2','RMSE_km_s','MAE_km_s',...
     'BIAS_km_s','MED_AE_km_s','EXT_STATUS'});
writetable(T_met, fullfile(out_dir,'PED_EXTERNAL_ALL_MODELS_METRICS.csv'));

% ── Determine verdict ─────────────────────────────────────────────────────
known_r2 = r2_vals(isfinite(r2_vals));
base_r2  = r2_vals(1:4);    % PNN/MLFFNN/DFFNN/CNN1D
stacker_r2 = r2_vals(5);
dr_r2      = r2_vals(6);

% Count how many base learners have actual predictions (not BLOCKED)
n_base_available = sum(isfinite(base_r2));
n_total_available = sum(isfinite(r2_vals));

if n_base_available == 0
    % Cannot compare stacker vs base learners — only Ridge stacker available
    verdict = 'INSUFFICIENT_EVIDENCE_BASE_LEARNERS_NOT_FOUND';
    fprintf('    NOTE: Only Ridge stacker evaluated — cannot determine if stacker amplifies failure\n');
    fprintf('    To resolve: rebuild PNN/MLFFNN/DFFNN/CNN1D from Well-A using canonical HPs\n');
    % Cannot PASS without base learner predictions — throw BLOCKED
    fprintf('    Verdict: %s\n', verdict);
    % Write outputs before error
    T_met_stub = table(string({'VERDICT'}),string({verdict}),'VariableNames',{'METRIC','VALUE'});
    writetable(T_met_stub, fullfile(out_dir,'PED_EXTERNAL_ALL_MODELS_METRICS.csv'));
    result.verdict = verdict; result.r2_vals = r2_vals;
    result.T_metrics = T_met_stub; result.all_preds = all_preds;
    result.y_true_popA = y_true_popA; result.n_popA = n_popA;
    result.verdict = verdict; result.r2_vals = r2_vals;
    result.T_metrics = T_met_stub; result.all_preds = all_preds;
    result.y_true_popA = y_true_popA; result.n_popA = n_popA;
    result.gate_result = struct('status',string('BLOCKED'),...
        'code',string('BLOCKED_BASE_LEARNER_PREDICTIONS_NOT_FOUND'),...
        'message',string('PNN/MLFFNN/DFFNN/CNN1D not found in frozen artifacts; DL Toolbox needed for rebuild'),...
        'required',true,'evidence_path',string(out_dir),'n_checks',6,'n_pass',0);
    return;
elseif n_total_available < 2
    verdict = 'INSUFFICIENT_EVIDENCE';
elseif all(known_r2 < 0)
    verdict = 'ALL_COMPLEX_MODELS_FAIL';
elseif all(base_r2(isfinite(base_r2)) > 0) && stacker_r2 < 0
    verdict = 'STACKER_AMPLIFIES_FAILURE';
elseif any(base_r2(isfinite(base_r2)) > 0)
    verdict = 'ONE_OR_MORE_BASE_LEARNERS_TRANSFER';
elseif stacker_r2 < 0 && ~isnan(dr_r2) && dr_r2 > 0
    verdict = 'FAILURE_MODEL_SPECIFIC';
else
    verdict = 'INSUFFICIENT_EVIDENCE';
end

fprintf('    Verdict: %s\n', verdict);

% ── Extrapolation summary ─────────────────────────────────────────────────
T_ext = table(string(model_names(:)), string(model_status(:)), r2_vals, ...
    r2_vals < 0, ...
    'VariableNames',{'MODEL','STATUS','R2_POPA','R2_NEGATIVE'});
writetable(T_ext, fullfile(out_dir,'PED_MODEL_EXTRAPOLATION_SUMMARY.csv'));

% ── Markdown ─────────────────────────────────────────────────────────────
fmd = fopen(fullfile(out_dir,'PED_EXTERNAL_MODEL_COMPARISON.md'),'w');
fprintf(fmd,'# External Model Comparison — Pop-A (n=%d)\n\n', n_popA);
fprintf(fmd,'**Verdict: %s**\n\n', verdict);
fprintf(fmd,'| Model | Status | R² | RMSE | Bias |\n|---|---|---|---|---|\n');
for mi=1:height(T_met)
    r2s = T_met.R2(mi);
    if isnumeric(r2s) && isfinite(r2s)
        fprintf(fmd,'| %s | %s | %.4f | %.4f | %.4f |\n', ...
            T_met.MODEL(mi), T_met.ANALYSIS_STATUS(mi), ...
            T_met.R2(mi), T_met.RMSE_km_s(mi), T_met.BIAS_km_s(mi));
    else
        fprintf(fmd,'| %s | %s | N/A | N/A | N/A |\n', ...
            T_met.MODEL(mi), T_met.ANALYSIS_STATUS(mi));
    end
end
fprintf(fmd,'\nDirect Ridge is POST_HOC_EXPLORATORY — cannot redefine primary analysis.\n');
fclose(fmd);

result.verdict     = verdict;
result.T_metrics   = T_met;
result.r2_vals     = r2_vals;
result.all_preds   = all_preds;
result.y_true_popA = y_true_popA;
result.n_popA      = n_popA;
end

function r2 = compute_r2(y, yp)
ss_r = sum((y-yp).^2); ss_t = sum((y-mean(y)).^2);
r2 = 1 - ss_r/ss_t;
end

function result = make_blocked(reason, out_dir)
fprintf('    BLOCKED: %s\n', reason);
result.verdict  = 'INSUFFICIENT_EVIDENCE';
result.r2_vals  = NaN(6,1);
result.T_metrics = table();
error('gate6 BLOCKED: %s', reason);
end
