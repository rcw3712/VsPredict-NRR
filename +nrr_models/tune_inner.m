function [best_hp, hp_log] = tune_inner(T_otr, inner_folds, base_seed, outer_fold_id, cfg)
% NRR_MODELS.TUNE_INNER  Grid search within inner CV — results never leave outer boundary.
%   Tunes: PNN spread, Ridge lambda.
%   NN (MLFFNN/DFFNN/CNN1D) HP fixed from grid position 1 to avoid
%   inner-CV NN training overhead (documented limitation per audit).
%   Saves INNER_CV_HYPERPARAMETER_RESULTS.csv rows per candidate.
%   Metric: mean inner-CV RMSE. Tie-break: lower lambda, lower spread.

n_inner = cfg.cv.n_inner;
hp_log  = {};

%% Tune PNN spread
best_spread=cfg.hp.pnn_spread_grid(1); best_pnn_rmse=inf;
for sp=cfg.hp.pnn_spread_grid
    rmse_k=nan(n_inner,1); fail=false;
    for fi=1:n_inner
        ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
        pm=nrr_data.fit_pm(T_otr(ti,:),cfg);
        [Xi,yi]=nrr_data.apply_pm_deploy(T_otr(ti,:),pm,cfg);
        [Xv,yv]=nrr_data.apply_pm(T_otr(vi,:),pm,cfg);
        ok=~isnan(yi); seed_i=base_seed+cfg.seeds.offset_pnn+fi*cfg.seeds.offset_fold;
        try
            mdl=nrr_models.fit_pnn(Xi,yi,struct('spread',sp,'silent',true),seed_i,cfg);
            yp=nrr_models.predict_pnn(mdl,Xv);
            ok_v=~isnan(yv); rmse_k(fi)=sqrt(mean((yv(ok_v)-yp(ok_v)).^2));
        catch; rmse_k(fi)=Inf; fail=true; end
    end
    cv_rmse=mean(rmse_k,'omitnan'); cv_sd=std(rmse_k,'omitnan');
    selected = cv_rmse<best_pnn_rmse;
    if selected; best_pnn_rmse=cv_rmse; best_spread=sp; end
    hp_log{end+1}={'pnn',outer_fold_id,base_seed,sp,NaN,NaN,NaN,...
        cv_rmse,cv_sd,selected,fail,'pnn_spread','min_cv_rmse'};
end

%% Tune Ridge lambda (fast linear proxy, intercept not penalized)
best_lambda=cfg.hp.ridge_lambda_grid(1); best_lam_rmse=inf;
for lam=cfg.hp.ridge_lambda_grid
    rmse_k=nan(n_inner,1);
    for fi=1:n_inner
        ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
        pm=nrr_data.fit_pm(T_otr(ti,:),cfg);
        [Xi,yi]=nrr_data.apply_pm_deploy(T_otr(ti,:),pm,cfg);
        [Xv,yv]=nrr_data.apply_pm(T_otr(vi,:),pm,cfg);
        ok=~isnan(yi);
        % Intercept NOT penalized: center X and y
        mu_x=mean(Xi(ok,:)); mu_y=mean(yi(ok));
        Xc=Xi(ok,:)-mu_x; yc=yi(ok)-mu_y;
        B=(Xc'*Xc+lam*eye(size(Xc,2)))\(Xc'*yc);
        b0=mu_y-mu_x*B;
        ok_v=~isnan(yv); yp=Xv(ok_v,:)*B+b0;
        rmse_k(fi)=sqrt(mean((yv(ok_v)-yp).^2));
    end
    cv_rmse=mean(rmse_k,'omitnan'); cv_sd=std(rmse_k,'omitnan');
    selected = cv_rmse<best_lam_rmse;
    if selected; best_lam_rmse=cv_rmse; best_lambda=lam; end
    hp_log{end+1}={'ridge',outer_fold_id,base_seed,NaN,lam,NaN,NaN,...
        cv_rmse,cv_sd,selected,false,'ridge_lambda','min_cv_rmse'};
end

%% Assemble best HP (NN HP from grid[1] — documented)
best_hp.pnn_spread     = best_spread;
best_hp.ridge_lambda   = best_lambda;
best_hp.mlffnn_hidden  = cfg.hp.mlffnn_hidden_grid{1};
best_hp.mlffnn_lr      = cfg.hp.mlffnn_lr_grid(1);
best_hp.mlffnn_epochs  = cfg.hp.mlffnn_epochs;
best_hp.mlffnn_batch   = cfg.hp.mlffnn_batch;
best_hp.dffnn_hidden   = cfg.hp.dffnn_hidden_grid{1};
best_hp.dffnn_lr       = cfg.hp.dffnn_lr_grid(1);
best_hp.dffnn_epochs   = cfg.hp.dffnn_epochs;
best_hp.dffnn_batch    = cfg.hp.dffnn_batch;
best_hp.cnn1d_filters  = cfg.hp.cnn1d_filters_grid(1);
best_hp.cnn1d_lr       = cfg.hp.cnn1d_lr;
best_hp.cnn1d_epochs   = cfg.hp.cnn1d_epochs;
best_hp.cnn1d_batch    = cfg.hp.cnn1d_batch;
best_hp.note           = 'NN HP from grid[1]; PNN and Ridge tuned via inner CV';

hp_log=cell2table(vertcat(hp_log{:}),'VariableNames',...
    {'MODEL','OUTER_FOLD','BASE_SEED','SPREAD','LAMBDA',...
     'FILTERS','HIDDEN_DIM1','CV_RMSE','CV_RMSE_SD',...
     'SELECTED','HAD_FAILURE','TUNED_PARAM','TIE_BREAK'});
end
