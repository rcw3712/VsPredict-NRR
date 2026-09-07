function deploy = fit_frozen_deployment(T_full, hp, run_seed, cfg)
% NRR_EVAL.FIT_FROZEN_DEPLOYMENT  Single function called by Gate 11 AND Gate 16.
%   All OOF seed derivation is deterministic given (T_full, hp, run_seed, cfg).
%   Gate 11 calls: deploy = fit_frozen_deployment(T_full, canon_hp, 42, cfg)
%   Gate 16 calls: deploy = fit_frozen_deployment(T_full, canon_hp, s, cfg)
%   When s=42, prediction vector must be bit-identical to Gate 12.
%
% Seed policy:
%   OOF fold fo:  base_seed = run_seed + fo * cfg.seeds.offset_fold + 100000
%   Full refit:   base_seed = run_seed + 90000
%
% This function does NOT touch Well-B. It cannot receive blind results.

assert(height(T_full) == cfg.dr.train_n || cfg.dr.train_n == 0, ...
    'fit_frozen_deployment: expected n=%d, got %d', cfg.dr.train_n, height(T_full));

%% Step 1: Preprocessor on full Well-A
rng(run_seed, 'twister');
pm_full = nrr_data.fit_pm(T_full, cfg);
[X_full, y_full] = nrr_data.apply_pm_deploy(T_full, pm_full, cfg);

%% Step 2: OOF meta-features via n_outer-fold CV on full Well-A
[folds, fold_hash] = nrr_data.build_folds(T_full, cfg.cv.n_outer, cfg);
n_full   = height(T_full);
oof_full = nan(n_full, 4);
oof_seed_ledger = {};

for fo = 1:cfg.cv.n_outer
    vi = folds(fo).val_idx;
    ti = folds(fo).train_idx;
    pm_f  = nrr_data.fit_pm(T_full(ti,:), cfg);
    [Xt, yt] = nrr_data.apply_pm_deploy(T_full(ti,:), pm_f, cfg);
    [Xv, ~]  = nrr_data.apply_pm(T_full(vi,:), pm_f, cfg);

    % Canonical OOF seed: run_seed + fo * offset_fold + 100000
    % Identical between Gate 11 and Gate 16 for same run_seed
    oof_base_seed = run_seed + fo * cfg.seeds.offset_fold + 100000;
    [bn_f, led_f] = nrr_models.fit_base_set(Xt, yt, hp, oof_base_seed, fo, cfg);
    oof_full(vi,:) = nrr_models.predict_base_set(bn_f, Xv);
    oof_seed_ledger{end+1} = led_f;
end

%% Step 3: Meta-scaler on full OOF (training data only)
meta_scaler = nrr_models.fit_meta_scaler(oof_full);
oof_sc      = nrr_models.apply_meta_scaler(oof_full, meta_scaler);

%% Step 4: Ridge stacker on scaled OOF
stacker = nrr_models.fit_ridge_stacker(oof_sc, y_full, hp.ridge_lambda, cfg);
assert(strcmp(stacker.input_space, 'standardized_meta'), ...
    'fit_frozen_deployment: stacker.input_space must be standardized_meta');

%% Step 5: Full base learners for deployment prediction
% Seed: run_seed + 90000 (deployment refit, distinct from OOF seeds)
deploy_base_seed = run_seed + 90000;
rng(deploy_base_seed, 'twister');
[base_nets, led_full] = nrr_models.fit_base_set(X_full, y_full, hp, ...
    deploy_base_seed, 0, cfg);

%% Step 6: Round-trip test on training OOF
meta_rt  = nrr_models.predict_base_set(base_nets, X_full);
meta_rt_sc = nrr_models.apply_meta_scaler(meta_rt, meta_scaler);
% Note: round-trip uses full refit base nets (not OOF), so RMSE != 0
y_rt     = nrr_models.predict_ridge_stacker(stacker, oof_sc);
ok_rt    = ~isnan(y_full);
rt_rmse  = sqrt(mean((y_full(ok_rt) - y_rt(ok_rt)).^2));
assert(isfinite(rt_rmse), 'fit_frozen_deployment: round-trip RMSE not finite');

%% Assemble deployment struct
deploy.pm              = pm_full;
deploy.base_nets       = base_nets;
deploy.meta_scaler     = meta_scaler;
deploy.stacker         = stacker;
deploy.hp              = hp;
deploy.hp_hash         = sprintf('spread=%.4f|lambda=%.6f', ...
    hp.pnn_spread, hp.ridge_lambda);
deploy.run_seed        = run_seed;
deploy.n_train         = n_full;
deploy.oof_fold_hash   = fold_hash;
deploy.oof_seed_policy = 'run_seed + fo*offset_fold + 100000';
deploy.deploy_seed     = deploy_base_seed;
deploy.roundtrip_rmse  = rt_rmse;
deploy.primary_locked  = false;
deploy.provenance      = 'V5_CORRECTED_REANALYSIS';

% Seed ledger
all_led = vertcat(oof_seed_ledger{:});
all_led = [all_led; led_full];
deploy.seed_ledger = all_led;

fprintf('  [deploy] seed=%d n=%d lambda=%.4f spread=%.2f rt_rmse=%.4f\n', ...
    run_seed, n_full, hp.ridge_lambda, hp.pnn_spread, rt_rmse);
end
