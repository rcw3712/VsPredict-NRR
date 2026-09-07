function run = gate13_direct_ridge(run, cfg)
% GATE 13: Direct Ridge post-hoc. STATUS=POST_HOC_SENSITIVITY, immutable.
assert(run.deploy.primary_locked,'[G13] Gate 12 must be locked first');
T_full=run.T_A_raw;
assert(height(T_full)==cfg.dr.train_n,...
    '[G13] Direct Ridge must train on n=%d, got %d',cfg.dr.train_n,height(T_full));

pm_dr=nrr_data.fit_pm(T_full,cfg);
[X_d,y_d]=nrr_data.apply_pm_deploy(T_full,pm_dr,cfg);
dr_model=nrr_models.fit_direct_ridge(X_d,y_d,cfg.dr.lambda,cfg);

T_B=run.T_B_raw;
[X_B,y_B]=nrr_data.apply_pm_deploy(T_B,pm_dr,cfg);
y_dr=X_B*dr_model.B+dr_model.b0;

mA=nrr_eval.eval_pop(y_B,y_dr,run.roles.popA_mask,'Pop-A [DR post-hoc]');
mB=nrr_eval.eval_pop(y_B,y_dr,run.roles.popB_mask,'Pop-B [DR post-hoc]');

% Assertions: Direct Ridge cannot redefine primary analysis
assert(~strcmp(dr_model.status,'primary'),'[G13] DR cannot be primary');

out4=fullfile(run.folder,'04_blind');
% POST_HOC_MODEL_STATUS.csv
writetable(table({'direct_ridge'},{cfg.dr.status},cfg.dr.lambda,...
    {'cannot_redefine_primary_analysis'},...
    {'requires_independent_third_well_confirmation'},...
    'VariableNames',{'MODEL','STATUS','LAMBDA','CONSTRAINT','NOTE'}),...
    fullfile(out4,'POST_HOC_MODEL_STATUS.csv'));

% BLIND_MODEL_COMPARISON — assembled after both Gate 12 and Gate 13
rows={'ridge_stacker','V5_CORRECTED_REANALYSIS',...
    run.blind.ridge.popA.n,run.blind.ridge.popA.r2,...
    run.blind.ridge.popA.rmse,run.blind.ridge.popA.bias;
      'direct_ridge',cfg.dr.status,...
    mA.n,mA.r2,mA.rmse,mA.bias};
writetable(cell2table(rows,'VariableNames',...
    {'MODEL','STATUS','N','R2','RMSE','BIAS'}),...
    fullfile(out4,'BLIND_MODEL_COMPARISON_POP_A.csv'));
rows_b={'ridge_stacker','V5_CORRECTED_REANALYSIS',...
    run.blind.ridge.popB.n,run.blind.ridge.popB.r2,...
    run.blind.ridge.popB.rmse,run.blind.ridge.popB.bias;
         'direct_ridge',cfg.dr.status,...
    mB.n,mB.r2,mB.rmse,mB.bias};
writetable(cell2table(rows_b,'VariableNames',...
    {'MODEL','STATUS','N','R2','RMSE','BIAS'}),...
    fullfile(out4,'BLIND_MODEL_COMPARISON_POP_B.csv'));

run.posthoc.dr=dr_model; run.posthoc.pm=pm_dr;
run.posthoc.y_pred=y_dr;
run.posthoc.popA=mA; run.posthoc.popB=mB;

run.gate.GATE_13='PASS';
fprintf('[G13] DR Pop-A R²=%.4f | Pop-B R²=%.4f [POST-HOC ONLY]\n',mA.r2,mB.r2);
end
