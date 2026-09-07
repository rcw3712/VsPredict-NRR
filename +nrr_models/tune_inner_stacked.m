function [best_hp, hp_log] = tune_inner_stacked(T_otr, inner_folds, base_seed, outer_fold_id, cfg)
% NRR_MODELS.TUNE_INNER_STACKED  Grid search using full stacked pipeline.
%   P0-3 fix: lambda is tuned on base_predictions -> y, not X -> y.
%   For each candidate lambda:
%     1. Generate inner OOF base predictions (4 learners)
%     2. Fit meta_scaler on training OOF
%     3. Fit Ridge stacker on scaled OOF
%     4. Predict held-out inner block via predict_ridge_stacker API
%     5. Compute RMSE
%   All NN HP use FIRST_IMPLEMENTATION policy (see audit Q2 response).
%
%   Output hp_log matches INNER_CV_HYPERPARAMETER_RESULTS.csv schema.

n_inner   = cfg.cv.n_inner;
best_rmse = inf;
best_lam  = cfg.hp.ridge_lambda_grid(1);
best_spread = cfg.hp.pnn_spread_grid(1);
hp_log = {};

%% Step 1: tune PNN spread independently (fast, no NN training)
for sp = cfg.hp.pnn_spread_grid
    rmse_k = nan(n_inner,1); fail=false;
    for fi = 1:n_inner
        ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
        pm=nrr_data.fit_pm(T_otr(ti,:),cfg);
        [Xi,yi]=nrr_data.apply_pm_deploy(T_otr(ti,:),pm,cfg);
        [Xv,yv]=nrr_data.apply_pm(T_otr(vi,:),pm,cfg);
        seed_i=base_seed+cfg.seeds.offset_pnn+fi*cfg.seeds.offset_fold;
        try
            mdl=nrr_models.fit_pnn(Xi,yi,struct('spread',sp,'silent',true),seed_i,cfg);
            yp=nrr_models.predict_pnn(mdl,Xv);
            ok_v=~isnan(yv); rmse_k(fi)=sqrt(mean((yv(ok_v)-yp(ok_v)).^2));
        catch; rmse_k(fi)=Inf; fail=true; end
    end
    cv_rmse=mean(rmse_k,'omitnan'); cv_sd=std(rmse_k,'omitnan');
    sel=(cv_rmse<inf && cv_rmse<best_rmse);
    hp_log{end+1}={outer_fold_id,'pnn',sp,NaN,cv_rmse,cv_sd,sel,fail,...
        'min_cv_rmse','FIRST_IMPLEMENTATION','PNN_INNER_CV'};
    if sel; best_spread=sp; best_rmse=cv_rmse; end
end
best_rmse=inf;   % reset for stacked lambda tuning

%% Step 2: tune stacker lambda using full stacked pipeline (P0-3)
% For each lambda candidate, run a mini nested CV:
%   - use a 2-fold split of the inner training to avoid fitting stacker on
%     the same data used to generate OOF (cross-fitting)
%   - train all 4 base learners on one half, get OOF on the other
%   - fit meta_scaler + stacker, predict held-out half
%   This is computationally feasible because it uses only inner folds.

for lam = cfg.hp.ridge_lambda_grid
    rmse_lam = nan(n_inner,1);
    for fi = 1:n_inner
        ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
        T_it=T_otr(ti,:); T_iv=T_otr(vi,:);
        pm_it=nrr_data.fit_pm(T_it,cfg);

        % Generate OOF for stacker training via leave-one-inner-out
        % Use 2-fold cross-fitting on ti to separate OOF from stacker fit
        n_ti=numel(ti); half=floor(n_ti/2);
        oof_half=nan(n_ti,4);
        for half_fi=1:2
            if half_fi==1; tr2=ti(half+1:end); va2=ti(1:half);
            else;          tr2=ti(1:half);     va2=ti(half+1:end); end
            pm_h=nrr_data.fit_pm(T_otr(tr2,:),cfg);
            [Xh,yh]=nrr_data.apply_pm_deploy(T_otr(tr2,:),pm_h,cfg);
            [Xv2,~]=nrr_data.apply_pm(T_otr(va2,:),pm_h,cfg);
            seed_h=base_seed+cfg.seeds.offset_cnn1d+fi*cfg.seeds.offset_fold+half_fi;
            hp_tmp=nrr_models.default_hp(cfg);
            hp_tmp.pnn_spread=best_spread;
            [bn_h,~]=nrr_models.fit_base_set(Xh,yh,hp_tmp,seed_h,fi*100+half_fi,cfg);
            oof_half(va2-ti(1)+1,:)=nrr_models.predict_base_set(bn_h,Xv2);
        end

        % Fit meta_scaler on the cross-fit OOF
        y_ti=T_otr.(cfg.data.target)(ti);
        ms_tmp=nrr_models.fit_meta_scaler(oof_half);
        oof_sc_tmp=nrr_models.apply_meta_scaler(oof_half,ms_tmp);
        stk_tmp=nrr_models.fit_ridge_stacker(oof_sc_tmp,y_ti,lam,cfg);

        % Train base learners on T_it, predict T_iv (inner-val)
        hp_full=nrr_models.default_hp(cfg);
        hp_full.pnn_spread=best_spread;
        [Xi_it,yi_it]=nrr_data.apply_pm_deploy(T_it,pm_it,cfg);
        [Xi_iv,yi_iv]=nrr_data.apply_pm(T_iv,pm_it,cfg);
        seed_iv=base_seed+cfg.seeds.offset_mlffnn+fi*cfg.seeds.offset_fold;
        [bn_iv,~]=nrr_models.fit_base_set(Xi_it,yi_it,hp_full,seed_iv,fi,cfg);
        meta_iv=nrr_models.predict_base_set(bn_iv,Xi_iv);
        meta_iv_sc=nrr_models.apply_meta_scaler(meta_iv,ms_tmp);
        yp_iv=nrr_models.predict_ridge_stacker(stk_tmp,meta_iv_sc);

        ok_v=~isnan(yi_iv);
        rmse_lam(fi)=sqrt(mean((yi_iv(ok_v)-yp_iv(ok_v)).^2));
    end

    cv_rmse=mean(rmse_lam,'omitnan'); cv_sd=std(rmse_lam,'omitnan');
    sel=(isfinite(cv_rmse) && cv_rmse<best_rmse);
    hp_log{end+1}={outer_fold_id,'stacker_lambda',NaN,lam,cv_rmse,cv_sd,sel,false,...
        'min_cv_rmse_stacked_pipeline','INNER_CV_TUNED_STACKED','STACKER_LAMBDA'};
    if sel; best_lam=lam; best_rmse=cv_rmse; end
end

%% Assemble best HP
best_hp = nrr_models.default_hp(cfg);
best_hp.pnn_spread   = best_spread;
best_hp.ridge_lambda = best_lam;
best_hp.hp_status    = 'INNER_CV_TUNED_STACKED';   % honest label (P0-3)
best_hp.nn_hp_status = 'FIRST_IMPLEMENTATION';       % honest label (Q2)
best_hp.note = 'PNN spread and Ridge lambda tuned via stacked inner CV; NN HP from first implementation';

hp_log = cell2table(vertcat(hp_log{:}),'VariableNames',...
    {'OUTER_FOLD','MODEL','SPREAD','LAMBDA','CV_RMSE','CV_RMSE_SD','SELECTED',...
     'HAD_FAILURE','SELECTION_RULE','HP_STATUS','TUNED_PARAM'});
end
