function run = gate10_canonical_hp(run, cfg)
% GATE 10: select canonical HP on full development set using the same
% corrected segment-aware stacked inner-CV objective as outer-fold tuning.
T_dev=run.T_A_raw(run.roles.dev_mask,:);
inner_f=nrr_data.build_folds(T_dev,cfg.cv.n_inner,cfg);
[best_hp,hp_log]=nrr_models.tune_inner_stacked(T_dev,inner_f, ...
    cfg.seeds.canonical,0,cfg);
run.canon_hp=best_hp;
run.canon_hp_hash=sprintf('spread=%.4f|lambda=%.6f', ...
    best_hp.pnn_spread,best_hp.ridge_lambda);
out3=fullfile(run.folder,'03_models');
freq_lam=cellfun(@(f)f.ridge_lambda,run.cv.fold_hp);
T_hp=table(cfg.hp.ridge_lambda_grid(:), ...
    arrayfun(@(l)sum(freq_lam==l),cfg.hp.ridge_lambda_grid)', ...
    'VariableNames',{'LAMBDA','OUTER_FOLD_FREQUENCY'});
T_hp.IS_CANONICAL=(cfg.hp.ridge_lambda_grid(:)==best_hp.ridge_lambda);
T_hp.CANONICAL_SPREAD=repmat(best_hp.pnn_spread,height(T_hp),1);
T_hp.POLICY=repmat("FULL_DEV_SEGMENT_AWARE_STACKED_INNER_CV",height(T_hp),1);
writetable(T_hp,fullfile(out3,'CANONICAL_HYPERPARAMETER_POLICY.csv'));
writetable(hp_log,fullfile(out3,'CANONICAL_HYPERPARAMETER_TUNING.csv'));
run.gate.GATE_10='PASS';
fprintf('[G10] PASS - canonical lambda=%.4f spread=%.2f [segment-aware stacked]\n', ...
    best_hp.ridge_lambda,best_hp.pnn_spread);
end
