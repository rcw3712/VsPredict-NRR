function run = gate10_canonical_hp(run, cfg)
% GATE 10: canonical HP policy — retune on full dev with inner CV.
T_dev=run.T_A_raw(run.roles.dev_mask,:);
inner_f=nrr_data.build_folds(T_dev,cfg.cv.n_inner,cfg);
[best_hp,~]=nrr_models.tune_inner(T_dev,inner_f,cfg.seeds.canonical,0,cfg);
run.canon_hp=best_hp;
run.canon_hp_hash=sprintf('spread=%.4f|lambda=%.6f',best_hp.pnn_spread,best_hp.ridge_lambda);
out3=fullfile(run.folder,'03_models');
freq_lam=cellfun(@(f)f.ridge_lambda,run.cv.fold_hp);
T_hp=table(cfg.hp.ridge_lambda_grid(:),...
    arrayfun(@(l)sum(freq_lam==l),cfg.hp.ridge_lambda_grid)',...
    'VariableNames',{'LAMBDA','OUTER_FOLD_FREQUENCY'});
T_hp.IS_CANONICAL=(cfg.hp.ridge_lambda_grid(:)==best_hp.ridge_lambda);
writetable(T_hp,fullfile(out3,'CANONICAL_HYPERPARAMETER_POLICY.csv'));
run.gate.GATE_10='PASS';
fprintf('[G10] PASS — canonical lambda=%.4f spread=%.2f\n',...
    best_hp.ridge_lambda,best_hp.pnn_spread);
end
