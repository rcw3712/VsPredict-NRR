function result = gate5_corrected_holdout(ctx, ext_dir)
% PED_EXT.GATE5_CORRECTED_HOLDOUT  Corrected holdout evaluation.
%   PRIMARY: Ridge stacker (same primary model as v5) fitted on 392 dev rows.
%   ADDITIONAL: Direct Ridge fitted on 392 dev rows (labeled POST_HOC_EXPLORATORY_HOLDOUT).
%   The Ridge stacker OOF meta-features must come from a fold-local refit on dev rows only.
%   HISTORICAL comparison (-3.0622) is ONLY valid vs primary Ridge stacker result.

out_dir = fullfile(ext_dir, '04_holdout');
HIST_R2 = -3.0622;

% ── Load Well-A ────────────────────────────────────────────────────────────
T_A = load_well_A(ctx);
assert(height(T_A) == ctx.n_wellA, 'gate5: Well-A rows %d != %d', height(T_A), ctx.n_wellA);
T_A = sortrows(T_A, 'DEPTH');

T_dev  = T_A(1:ctx.n_dev, :);
T_hold = T_A(ctx.n_dev+1:ctx.n_dev+ctx.n_holdout, :);
assert(height(T_dev)  == ctx.n_dev,     'gate5: dev split error');
assert(height(T_hold) == ctx.n_holdout, 'gate5: holdout split error');
assert(min(T_hold.DEPTH) > max(T_dev.DEPTH), 'gate5: holdout not below dev (depth order)');

fprintf('    Dev: [%.2f,%.2f]m | Holdout: [%.2f,%.2f]m\n',...
    min(T_dev.DEPTH),max(T_dev.DEPTH),min(T_hold.DEPTH),max(T_hold.DEPTH));

% ── Detect feature and target columns ────────────────────────────────────
feat_cols = intersect({'GR','DT','NPHI','RHOB'}, T_A.Properties.VariableNames, 'stable');
assert(numel(feat_cols)==4, 'gate5: feature columns missing. Found: %s',...
    strjoin(T_A.Properties.VariableNames,','));

tgt_col = '';
for tc = {'VS','Vs','DTS','DTs'}
    if ismember(tc{1},T_A.Properties.VariableNames); tgt_col=tc{1}; break; end
end
assert(~isempty(tgt_col), 'gate5: no VS/DTS column found');

% Convert DTS to Vs if needed
X_dev  = table2array(T_dev(:,feat_cols));
X_hold = table2array(T_hold(:,feat_cols));
if any(strcmpi(tgt_col,{'DTS','DTs'}))
    y_dev  = 304.8 ./ T_dev.(tgt_col);
    y_hold = 304.8 ./ T_hold.(tgt_col);
    fprintf('    Target: %s → Vs=304.8/%s (km/s)\n', tgt_col, tgt_col);
else
    y_dev  = T_dev.(tgt_col);
    y_hold = T_hold.(tgt_col);
    fprintf('    Target: %s (km/s)\n', tgt_col);
end
assert(all(isfinite(y_dev)),  'gate5: NaN in dev target');
assert(all(isfinite(y_hold)), 'gate5: NaN in holdout target');

% ── Z-score scaler fitted on dev rows ONLY ────────────────────────────────
mu_dev = mean(X_dev);
sd_dev = std(X_dev);
sd_dev(sd_dev < 1e-10) = 1;
X_dev_s  = (X_dev  - mu_dev) ./ sd_dev;
X_hold_s = (X_hold - mu_dev) ./ sd_dev;

% ── PRIMARY: Ridge stacker simulation on dev rows ─────────────────────────
% The true Ridge stacker requires OOF meta-features from base learners.
% Without Deep Learning Toolbox, we cannot refit PNN/MLFFNN/DFFNN/CNN1D.
% Therefore: attempt to use frozen OOF predictions from canonical run if available.
% If not available: BLOCKED — do NOT substitute a different model.

primary_r2   = NaN;
primary_rmse = NaN;
primary_classification = 'BLOCKED_PRIMARY_MODEL_NOT_AVAILABLE';
primary_note = '';

% Try to load frozen OOF predictions for dev rows (if they exist in artifacts)
% Check frozen artifact variables (from gate0 whos output)
% FROZEN_MODEL_ARTIFACTS.mat has: deploy[1x1], posthoc[1x1]
% Neither is a train-392 holdout model — need to check deploy struct fields
oof_loaded = false;
fprintf('    Checking frozen artifact variables: %s\n', ...
    strjoin(ctx.frozen_art_vars, ', '));
% Check if deploy struct has OOF predictions (train-392)
if isfield(ctx.frozen_art,'deploy')
    dep = ctx.frozen_art.deploy;
    dep_fields = fieldnames(dep);
    fprintf('    deploy struct fields: %s\n', strjoin(dep_fields, ', '));
end
if isfield(ctx.frozen_art,'oof_predictions') || isfield(ctx.frozen_art,'dev_oof')
    fprintf('    Attempting to load frozen OOF predictions...\n');
    fld = 'oof_predictions';
    if ~isfield(ctx.frozen_art,fld); fld='dev_oof'; end
    oof_preds = ctx.frozen_art.(fld);
    % Apply frozen Ridge stacker to OOF meta-features
    if isfield(ctx.frozen_art,'ridge_weights') || isfield(ctx.frozen_art,'stacker_coef')
        oof_loaded = true;
        fprintf('    Frozen OOF + Ridge weights loaded — can evaluate holdout\n');
        % TODO: apply stacker to holdout meta-features
        % This requires holdout OOF which doesn't exist — holdout was never in OOF loop
        % So even with frozen weights, we cannot repredict holdout via Ridge stacker
        % without running the base learners on holdout rows
        oof_loaded = false;
        primary_note = 'Ridge stacker holdout requires base-learner inference on holdout rows (DL Toolbox needed)';
    end
end

% Verify DL Toolbox availability with functional smoke test
dl_functional = false;
try
    % Functional test: can we create a simple feedforward net?
    test_net = feedforwardnet(2);
    dl_functional = true;
    fprintf('    DL Toolbox functional test: feedforwardnet OK\n');
catch
    try
        % Try training a tiny network
        test_net = newpnn([0;1],[1,0]);
        dl_functional = true;
        fprintf('    DL Toolbox functional test: newpnn OK\n');
    catch
        fprintf('    DL Toolbox functional test: FAILED — cannot create network objects\n');
    end
end
ctx.has_dl_tbx = dl_functional;
fprintf('    DL Toolbox usable: %d\n', dl_functional);

if ~ctx.has_dl_tbx && ~oof_loaded
    fprintf('    PRIMARY (Ridge stacker): BLOCKED — Deep Learning Toolbox not available\n');
    fprintf('    Cannot refit PNN/MLFFNN/DFFNN/CNN1D on dev rows to generate meta-features\n');
    fprintf('    Cannot apply Ridge stacker to holdout without base learner predictions\n');
    primary_classification = 'BLOCKED_NO_DL_TOOLBOX';
    primary_note = 'Deep Learning Toolbox required to refit base learners and apply Ridge stacker';
end

% ── ADDITIONAL: Direct Ridge on dev rows (POST_HOC_EXPLORATORY_HOLDOUT) ──
lambda_dr = 1.0;
n_f = size(X_dev_s,2);
X_aug_dev  = [ones(ctx.n_dev,1), X_dev_s];
X_aug_hold = [ones(ctx.n_holdout,1), X_hold_s];
I_aug = eye(n_f+1); I_aug(1,1)=0;
beta_dr = (X_aug_dev'*X_aug_dev + lambda_dr*I_aug) \ (X_aug_dev'*y_dev);
y_pred_dr_hold = X_aug_hold * beta_dr;

dr_r2   = 1-sum((y_hold-y_pred_dr_hold).^2)/sum((y_hold-mean(y_hold)).^2);
dr_rmse = sqrt(mean((y_hold-y_pred_dr_hold).^2));
dr_bias = mean(y_pred_dr_hold-y_hold);
dr_mae  = mean(abs(y_hold-y_pred_dr_hold));
fprintf('    ADDITIONAL (Direct Ridge, 392-only fit, POST_HOC_EXPLORATORY_HOLDOUT):\n');
fprintf('      R²=%.4f | RMSE=%.4f | MAE=%.4f | Bias=%.4f\n',dr_r2,dr_rmse,dr_mae,dr_bias);
fprintf('    Historical holdout R²=%.4f (Ridge stacker, different model — NOT directly comparable)\n',HIST_R2);

% ── Write predictions CSV ─────────────────────────────────────────────────
if ismember('ROW_ID',T_hold.Properties.VariableNames)
    row_ids = T_hold.ROW_ID;
else
    row_ids = (ctx.n_dev+1:ctx.n_dev+ctx.n_holdout)';
end
T_pred = table(row_ids, T_hold.DEPTH, y_hold, y_pred_dr_hold,...
    y_pred_dr_hold-y_hold,...
    repmat(string('DIRECT_RIDGE_392_DEV_ONLY_POST_HOC_EXPLORATORY'),ctx.n_holdout,1),...
    'VariableNames',{'ROW_ID','DEPTH','VS_MEASURED','VS_PREDICTED','RESIDUAL','MODEL_STATUS'});
writetable(T_pred, fullfile(out_dir,'PED_HOLDOUT_CORRECTED_PREDICTIONS.csv'));

% ── Metrics CSV ───────────────────────────────────────────────────────────
T_met = table(...
    string({'PRIMARY_RIDGE_STACKER_R2','PRIMARY_RIDGE_STACKER_STATUS',...
            'DR_R2','DR_RMSE_km_s','DR_MAE_km_s','DR_BIAS_km_s',...
            'DR_STATUS','HISTORICAL_R2','HISTORICAL_MODEL','COMPARABLE'}),...
    string({num2str(primary_r2,'%.4f'), primary_classification,...
            num2str(dr_r2,'%.4f'), num2str(dr_rmse,'%.4f'),...
            num2str(dr_mae,'%.4f'), num2str(dr_bias,'%.4f'),...
            'POST_HOC_EXPLORATORY_HOLDOUT', num2str(HIST_R2,'%.4f'),...
            'Ridge_stacker','NO_DIFFERENT_MODELS'}),...
    'VariableNames',{'METRIC','VALUE'});
writetable(T_met, fullfile(out_dir,'PED_HOLDOUT_CORRECTED_METRICS.csv'));

% ── Reconciliation MD ─────────────────────────────────────────────────────
fmd = fopen(fullfile(out_dir,'PED_HOLDOUT_RECONCILIATION.md'),'w');
fprintf(fmd,'# Holdout Reconciliation\n\n');
fprintf(fmd,'## Primary Ridge Stacker\n');
fprintf(fmd,'**Status: %s**\n\n%s\n\n',primary_classification,primary_note);
fprintf(fmd,'## Direct Ridge (POST_HOC_EXPLORATORY_HOLDOUT)\n');
fprintf(fmd,'R²=%.4f | RMSE=%.4f | Bias=%.4f\n\n',dr_r2,dr_rmse,dr_bias);
fprintf(fmd,'## Historical Comparison\n');
fprintf(fmd,'Historical holdout R²=%.4f was from the **Ridge stacker** pipeline.\n',HIST_R2);
fprintf(fmd,'The Direct Ridge result (%.4f) is from a **different model** and ',dr_r2);
fprintf(fmd,'**cannot reconcile** the historical value.\n\n');
fprintf(fmd,'**To reconcile P0-2, the primary Ridge stacker must be applied to holdout rows.**\n');
fprintf(fmd,'This requires Deep Learning Toolbox to refit PNN/MLFFNN/DFFNN/CNN1D.\n');
fclose(fmd);

% Return primary status
result.r2             = dr_r2;   % Only result available
result.rmse           = dr_rmse;
result.mae            = dr_mae;
result.bias           = dr_bias;
result.classification = 'DR_POST_HOC_ONLY_PRIMARY_BLOCKED';
result.primary_status = primary_classification;
result.historical_r2  = HIST_R2;
result.T_predictions  = T_pred;
fprintf('    NOTE: P0-2 (historical holdout reconciliation) UNRESOLVED — requires DL Toolbox\n');
% Gate cannot PASS when primary Ridge stacker holdout is unavailable
% Direct Ridge result is exploratory only and does not resolve P0-2
result.gate_result = struct('status',string('BLOCKED'),...
    'code',string('BLOCKED_PRIMARY_RIDGE_STACKER_HOLDOUT_NOT_AVAILABLE'),...
    'message',string('DL Toolbox required: cannot refit PNN/MLFFNN/DFFNN/CNN1D on 392 dev rows'),...
    'required',true,'evidence_path',string(out_dir),'n_checks',1,'n_pass',0);
end

function T = load_well_A(ctx)
candidates = {
    fullfile(ctx.project_root,'data','Well-A.xlsx');
    fullfile(ctx.project_root,'data','well_a.csv');
};
for i=1:numel(candidates)
    if isfile(candidates{i})
        [~,~,ext_]=fileparts(candidates{i});
        if strcmpi(ext_,'.xlsx')
            T = readtable(candidates{i},'VariableNamingRule','preserve');
        else
            T = readtable(candidates{i},'TextType','string');
        end
        T.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '),...
            T.Properties.VariableNames,'UniformOutput',false);
        T = sortrows(T,'DEPTH');
        if ~ismember('ROW_ID',T.Properties.VariableNames)
            T.ROW_ID=(1:height(T))';
        end
        return;
    end
end
error('gate5: Well-A data not found');
end
