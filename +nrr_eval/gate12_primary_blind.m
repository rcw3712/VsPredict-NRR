function run = gate12_primary_blind(run, cfg)
% GATE 12: Primary blind evaluation via single predict_frozen_deployment API.
%   Raw metrics before clipping. Pop-B labeled TARGET_INFORMED_DIAGNOSTIC.

T_B = run.T_B_raw;

% Single prediction API — same as Gate 16 canonical prediction
y_raw = nrr_eval.predict_frozen_deployment(run.deploy, T_B, cfg);

% Clip AFTER computing primary metrics
y_clip = max(cfg.sanity.VS(1), min(cfg.sanity.VS(2), y_raw));
y_B    = nrr_data.apply_pm_deploy(T_B, run.deploy.pm, cfg);
[~, y_B] = nrr_data.apply_pm_deploy(T_B, run.deploy.pm, cfg);

out4 = fullfile(run.folder,'04_blind');

% Row predictions
writetable(table(T_B.(cfg.data.id_col), T_B.(cfg.data.depth_col),...
    y_B, y_raw, y_clip,...
    run.roles.popA_mask, run.roles.popB_mask,...
    'VariableNames',{'ROW_ID','DEPTH','VS_measured',...
    'VS_pred_raw','VS_pred_clipped','IS_POPA','IS_POPB'}),...
    fullfile(out4,'PRIMARY_BLIND_ROW_PREDICTIONS.csv'));

% Evaluate populations
mA = nrr_eval.eval_pop(y_B, y_raw, run.roles.popA_mask, 'Pop-A [primary]');
mB = nrr_eval.eval_pop(y_B, y_raw, run.roles.popB_mask, ...
    'Pop-B [TARGET_INFORMED_DIAGNOSTIC]');

nrr_eval.write_eval(mA,'ridge_stacker','V5_CORRECTED_REANALYSIS',...
    fullfile(out4,'PRIMARY_BLIND_EVALUATION_POP_A.csv'));
nrr_eval.write_eval(mB,'ridge_stacker','TARGET_INFORMED_DIAGNOSTIC_SUBSET',...
    fullfile(out4,'DIAGNOSTIC_BLIND_EVALUATION_POP_B.csv'));

writetable(table({'ridge_stacker'},{'V5_CORRECTED_REANALYSIS'},...
    mA.r2, mA.rmse, mA.bias, mB.r2, mB.rmse, mB.bias,...
    'VariableNames',{'MODEL','PROVENANCE_CLASS',...
    'POPA_R2','POPA_RMSE','POPA_BIAS','POPB_R2','POPB_RMSE','POPB_BIAS'}),...
    fullfile(out4,'PRIMARY_STATUS.csv'));

run.blind.y_B    = y_B;
run.blind.y_raw  = y_raw;
run.blind.y_clip = y_clip;
run.blind.ridge.popA = mA;
run.blind.ridge.popB = mB;
run.deploy.primary_locked = true;

run.gate.GATE_12 = 'PASS';
fprintf('[G12] LOCKED | Pop-A R²=%.4f (n=%d) | Pop-B R²=%.4f (n=%d, diagnostic)\n',...
    mA.r2, mA.n, mB.r2, mB.n);
end
