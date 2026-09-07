function run = gate11_freeze_deployment(run, cfg)
% GATE 11: Freeze primary deployment via single fit_frozen_deployment call.
%   Gate 16 seed=42 must produce bit-identical result to this gate.

fprintf('[G11] Freezing deployment (n=%d, seed=%d, lambda=%.4f)...\n',...
    height(run.T_A_raw), run.seed, run.canon_hp.ridge_lambda);

% Single function — identical call signature as Gate 16 seed=42
deploy = nrr_eval.fit_frozen_deployment(...
    run.T_A_raw, run.canon_hp, run.seed, cfg);

% Verify HP hash
assert(strcmp(deploy.hp_hash, run.canon_hp_hash),...
    '[G11] deploy.hp_hash mismatch');

% Store
run.deploy = deploy;

% Save seed ledger to 00_environment
env_dir = fullfile(run.folder, '00_environment');
ledger_path = fullfile(env_dir,'SEED_LEDGER.csv');
if isfile(ledger_path)
    T_ex = readtable(ledger_path);
    T_new = deploy.seed_ledger;
    % Normalize all numeric columns in both tables (cell -> double)
    num_cols = {'BASE_SEED','DERIVED_SEED','FOLD_ID'};
    for ci = 1:numel(num_cols)
        col = num_cols{ci};
        if ismember(col,T_ex.Properties.VariableNames) && iscell(T_ex.(col))
            T_ex.(col) = cellfun(@(x) double(x), T_ex.(col));
        end
        if ismember(col,T_new.Properties.VariableNames) && iscell(T_new.(col))
            T_new.(col) = cellfun(@(x) double(x), T_new.(col));
        end
    end
    writetable([T_ex; T_new], ledger_path);
else
    writetable(deploy.seed_ledger, ledger_path);
end

% MODEL_ARCHITECTURE_MANIFEST.csv
out3 = fullfile(run.folder,'03_models');
hp = run.canon_hp;
hp_status     = 'INNER_CV_TUNED_STACKED';
nn_hp_status  = 'FIRST_IMPLEMENTATION';
arch_rows = {
    'pnn',          'pnn',          sprintf('spread=%.2f [%s]',hp.pnn_spread,hp_status);
    'mlffnn',       'mlffnn',       sprintf('hidden=[%s] lr=%.0e [%s]',num2str(hp.mlffnn_hidden),hp.mlffnn_lr,nn_hp_status);
    'dffnn',        'dffnn',        sprintf('hidden=[%s] lr=%.0e [%s]',num2str(hp.dffnn_hidden),hp.dffnn_lr,nn_hp_status);
    'cnn1d',        'cnn1d',        sprintf('filters=%d W=%d lr=%.0e [%s]',hp.cnn1d_filters,cfg.hp.cnn1d_window,hp.cnn1d_lr,nn_hp_status);
    'ridge_stacker','ridge_stacker',sprintf('lambda=%.4f intercept_not_penalized [INNER_CV_TUNED_STACKED]',hp.ridge_lambda)
};
writetable(cell2table(arch_rows,'VariableNames',{'MODEL','TYPE','HP_SUMMARY'}),...
    fullfile(out3,'MODEL_ARCHITECTURE_MANIFEST.csv'));

save(fullfile(out3,'FROZEN_PRIMARY_MODEL.mat'),'run','-v7.3');

%% Reload round-trip test — clean load via struct field (no warning)
tmp_f = fullfile(tempdir,'deploy_roundtrip_test.mat');
deploy = run.deploy;
save(tmp_f, 'deploy', '-v7.3');
S = load(tmp_f, 'deploy');
assert(isfield(S,'deploy'), '[G11] Round-trip file missing deploy variable');
deploy_rt = S.deploy;
delete(tmp_f);

pred_before = nrr_eval.predict_frozen_deployment(run.deploy, run.T_B_raw, cfg);
pred_after  = nrr_eval.predict_frozen_deployment(deploy_rt, run.T_B_raw, cfg);
max_rt_diff = max(abs(pred_before - pred_after));
assert(max_rt_diff < 1e-10, '[G11] Reload round-trip FAIL: max diff=%.2e > 1e-10', max_rt_diff);
fprintf('[G11] Reload round-trip PASS: max_diff=%.2e\n', max_rt_diff);

run.gate.GATE_11 = 'PASS';
fprintf('[G11] PASS — oof_fold_hash=%s rt_rmse=%.4f\n',...
    deploy.oof_fold_hash, deploy.roundtrip_rmse);
end
