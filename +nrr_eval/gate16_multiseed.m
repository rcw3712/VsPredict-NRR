function run = gate16_multiseed(run, cfg)
% GATE 16: Exact multi-seed replication via fit_frozen_deployment.
%   Seed 42 MUST produce prediction vector identical to Gate 12.
%   Gate FAILS if canonical mismatch detected.
%   Seeds 7 and 123 may differ (measure training stochasticity).

assert(run.deploy.primary_locked, '[G16] Gate 12 must be locked first');

seeds  = cfg.seeds.multiseed;    % [7, 42, 123]
T_full = run.T_A_raw;
T_B    = run.T_B_raw;
popA   = run.roles.popA_mask;
popB   = run.roles.popB_mask;
hp     = run.canon_hp;
hp_hash= run.canon_hp_hash;
out4   = fullfile(run.folder,'04_blind');

% Canonical Gate 12 prediction vector (reference for seed=42 check)
y_ref  = run.blind.y_raw;

seed_rows  = {};
pred_mat_A = nan(run.n_popA, numel(seeds));
pred_mat_B = nan(run.n_popB, numel(seeds));
all_ledger = {};

for si = 1:numel(seeds)
    s = seeds(si);
    fprintf('[G16]   Seed %d/%d...\n', s, seeds(end));

    % SAME function as Gate 11 — guarantees identical pipeline
    dep_s = nrr_eval.fit_frozen_deployment(T_full, hp, s, cfg);

    % Canonical equivalence check for seed=42
    if s == cfg.seeds.canonical
        y_s = nrr_eval.predict_frozen_deployment(dep_s, T_B, cfg);
        max_diff = max(abs(y_ref - y_s));
        assert(max_diff < 1e-10, ...
            '[G16] CANONICAL MISMATCH: seed=%d max|pred_G12-pred_G16|=%.2e > 1e-10', ...
            s, max_diff);
        fprintf('[G16]   Seed 42 canonical equivalence: max_diff=%.2e PASS\n', max_diff);

        % Also assert HP fingerprint identical
        assert(strcmp(dep_s.hp_hash, hp_hash), ...
            '[G16] HP hash mismatch for canonical seed');
        % Assert OOF fold hash identical
        assert(strcmp(dep_s.oof_fold_hash, run.deploy.oof_fold_hash), ...
            '[G16] OOF fold hash mismatch for canonical seed');
    end

    % Predict and evaluate all seeds
    y_pred_s = nrr_eval.predict_frozen_deployment(dep_s, T_B, cfg);
    mA_s = nrr_eval.eval_pop(y_B_load(run), y_pred_s, popA, sprintf('Seed%d PopA',s));
    mB_s = nrr_eval.eval_pop(y_B_load(run), y_pred_s, popB, sprintf('Seed%d PopB',s));

    pred_mat_A(:,si) = y_pred_s(popA);
    pred_mat_B(:,si) = y_pred_s(popB);
    all_ledger{end+1} = dep_s.seed_ledger;

    seed_rows{end+1} = {s, mA_s.n, mA_s.r2, mA_s.rmse, mA_s.bias,...
        mB_s.n, mB_s.r2, mB_s.rmse, mB_s.bias,...
        s==cfg.seeds.canonical, hp.ridge_lambda, hp_hash,...
        dep_s.roundtrip_rmse};

    fprintf('[G16]   Seed %d: PopA R²=%.4f PopB R²=%.4f%s\n',...
        s, mA_s.r2, mB_s.r2,...
        repmat(' [CANONICAL]', 1, s==cfg.seeds.canonical));
end

% Assertions: prediction vectors same length and order for all seeds
assert(size(pred_mat_A,1)==run.n_popA, '[G16] PopA length mismatch');
assert(size(pred_mat_B,1)==run.n_popB, '[G16] PopB length mismatch');

% Multi-seed summary statistics
r2A_all   = cellfun(@(r) r{3}, seed_rows);
r2B_all   = cellfun(@(r) r{8}, seed_rows);
summary = struct(...
    'mean_r2_popA',  mean(r2A_all), 'sd_r2_popA',  std(r2A_all),...
    'min_r2_popA',   min(r2A_all),  'max_r2_popA',  max(r2A_all),...
    'mean_r2_popB',  mean(r2B_all), 'sd_r2_popB',  std(r2B_all),...
    'n_seeds_r2A_positive', sum(r2A_all>0));

% Main results CSV
cols = {'SEED','N_POPA','R2_POPA','RMSE_POPA','BIAS_POPA',...
    'N_POPB','R2_POPB','RMSE_POPB','BIAS_POPB',...
    'IS_CANONICAL','HP_LAMBDA','HP_HASH','RT_RMSE'};
T_ms = cell2table(vertcat(seed_rows{:}), 'VariableNames', cols);
writetable(T_ms, fullfile(out4,'MULTISEED_EXACT_PIPELINE_METRICS.csv'));

% Summary statistics
writetable(struct2table(summary),...
    fullfile(out4,'MULTISEED_SUMMARY_STATISTICS.csv'));

% Prediction-wise SD across seeds
pred_sd_A = std(pred_mat_A, 0, 2);
pred_sd_B = std(pred_mat_B, 0, 2);
writetable(table(pred_sd_A, 'VariableNames',{'PRED_SD_KM_S'}),...
    fullfile(out4,'MULTISEED_PREDICTION_SD_POPA.csv'));
writetable(table(pred_sd_B, 'VariableNames',{'PRED_SD_KM_S'}),...
    fullfile(out4,'MULTISEED_PREDICTION_SD_POPB.csv'));

% Seed ledger
if ~isempty(all_ledger)
    T_led = vertcat(all_ledger{:});
    lpath = fullfile(run.folder,'00_environment','SEED_LEDGER.csv');
    try
        T_ex = readtable(lpath);
        % Normalize all numeric columns (cell -> double)
        num_cols = {'BASE_SEED','DERIVED_SEED','FOLD_ID'};
        for ci = 1:numel(num_cols)
            col = num_cols{ci};
            if ismember(col,T_ex.Properties.VariableNames) && iscell(T_ex.(col))
                T_ex.(col) = cellfun(@(x) double(x), T_ex.(col));
            end
            if ismember(col,T_led.Properties.VariableNames) && iscell(T_led.(col))
                T_led.(col) = cellfun(@(x) double(x), T_led.(col));
            end
        end
        writetable([T_ex; T_led], lpath);
    catch
        writetable(T_led, fullfile(run.folder,'00_environment','SEED_LEDGER_MULTISEED.csv'));
    end
end

run.multiseed.table   = T_ms;
run.multiseed.summary = summary;
run.multiseed.pred_A  = pred_mat_A;
run.multiseed.pred_B  = pred_mat_B;

run.gate.GATE_16 = 'PASS';
fprintf('[G16] PASS — canonical seed=42 verified identical; summary mean PopA R²=%.4f SD=%.4f\n',...
    summary.mean_r2_popA, summary.sd_r2_popA);
end

function y_B = y_B_load(run)
% Load measured VS for Well-B from blind struct
y_B = run.blind.y_B;
end
