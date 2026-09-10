function [best_hp, hp_log] = tune_inner_stacked(T_otr, inner_folds, base_seed, outer_fold_id, cfg)
% NRR_MODELS.TUNE_INNER_STACKED  Segment-aware stacked inner-CV tuning.
% PNN spread and stacker lambda are selected within the outer-training set.
% CNN segment IDs are derived from physical depth for every training and
% prediction call; no implicit single-segment fallback exists.

n_inner=cfg.cv.n_inner; best_pnn_rmse=inf;
best_spread=cfg.hp.pnn_spread_grid(1); hp_log={};

for sp=cfg.hp.pnn_spread_grid
    rmse_k=nan(n_inner,1); fail=false;
    for fi=1:n_inner
        ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
        pm=nrr_data.fit_pm(T_otr(ti,:),cfg);
        [Xi,yi]=nrr_data.apply_pm_deploy(T_otr(ti,:),pm,cfg);
        [Xv,yv]=nrr_data.apply_pm(T_otr(vi,:),pm,cfg);
        seed_i=base_seed+cfg.seeds.offset_pnn+fi*cfg.seeds.offset_fold;
        try
            mdl=nrr_models.fit_pnn(Xi,yi,struct('spread',sp,'silent',true),seed_i,cfg);
            yp=nrr_models.predict_pnn(mdl,Xv);
            rmse_k(fi)=sqrt(mean((yv-yp).^2,'omitnan'));
        catch
            rmse_k(fi)=Inf; fail=true;
        end
    end
    cv_rmse=mean(rmse_k,'omitnan'); cv_sd=std(rmse_k,'omitnan');
    selected=isfinite(cv_rmse) && cv_rmse<best_pnn_rmse;
    hp_log{end+1}={outer_fold_id,'pnn',sp,NaN,cv_rmse,cv_sd, ...
        selected,fail,'min_cv_rmse','INNER_CV_TUNED','PNN_SPREAD'}; %#ok<AGROW>
    if selected; best_pnn_rmse=cv_rmse; best_spread=sp; end
end

best_lambda=cfg.hp.ridge_lambda_grid(1); best_lam_rmse=inf;
for lam=cfg.hp.ridge_lambda_grid
    rmse_lam=nan(n_inner,1);
    for fi=1:n_inner
        ti=inner_folds(fi).train_idx; vi=inner_folds(fi).val_idx;
        T_it=T_otr(ti,:); T_iv=T_otr(vi,:);

        % Two-fold cross-fitting is indexed locally within T_it. This avoids
        % the invalid global-index arithmetic used by the legacy routine.
        half_folds=nrr_data.build_folds(T_it,2,cfg);
        oof_half=nan(height(T_it),4);
        for hf=1:2
            tr=half_folds(hf).train_idx; va=half_folds(hf).val_idx;
            T_htr=T_it(tr,:); T_hva=T_it(va,:);
            pm_h=nrr_data.fit_pm(T_htr,cfg);
            [Xh,yh]=nrr_data.apply_pm_deploy(T_htr,pm_h,cfg);
            [Xv2,~]=nrr_data.apply_pm(T_hva,pm_h,cfg);
            hp_tmp=nrr_models.default_hp(cfg);
            hp_tmp.pnn_spread=best_spread;
            seed_h=base_seed+cfg.seeds.offset_cnn1d+ ...
                fi*cfg.seeds.offset_fold+hf;
            seg_htr=nrr_data.depth_segment_ids(T_htr.(cfg.data.depth_col),cfg);
            seg_hva=nrr_data.depth_segment_ids(T_hva.(cfg.data.depth_col),cfg);
            [bn_h,led_h]=nrr_models.fit_base_set(Xh,yh,hp_tmp,seed_h, ...
                fi*100+hf,cfg,seg_htr);
            assert(all(led_h.N_RETAINED_CROSS_SEGMENT==0), ...
                'tune_inner_stacked: retained cross-segment training window');
            [oof_half(va,:),pa_h]=nrr_models.predict_base_set(bn_h,Xv2,seg_hva);
            assert(pa_h.N_RETAINED_CROSS_SEGMENT==0, ...
                'tune_inner_stacked: retained cross-segment prediction window');
        end
        assert(all(isfinite(oof_half),'all'), ...
            'tune_inner_stacked: cross-fit OOF incomplete');
        y_ti=T_it.(cfg.data.target);
        ms=nrr_models.fit_meta_scaler(oof_half);
        oof_sc=nrr_models.apply_meta_scaler(oof_half,ms);
        stk=nrr_models.fit_ridge_stacker(oof_sc,y_ti,lam,cfg);

        pm_it=nrr_data.fit_pm(T_it,cfg);
        [Xi_it,yi_it]=nrr_data.apply_pm_deploy(T_it,pm_it,cfg);
        [Xi_iv,yi_iv]=nrr_data.apply_pm(T_iv,pm_it,cfg);
        hp_full=nrr_models.default_hp(cfg); hp_full.pnn_spread=best_spread;
        seg_it=nrr_data.depth_segment_ids(T_it.(cfg.data.depth_col),cfg);
        seg_iv=nrr_data.depth_segment_ids(T_iv.(cfg.data.depth_col),cfg);
        seed_iv=base_seed+cfg.seeds.offset_mlffnn+fi*cfg.seeds.offset_fold;
        [bn_iv,led_iv]=nrr_models.fit_base_set(Xi_it,yi_it,hp_full, ...
            seed_iv,fi,cfg,seg_it);
        assert(all(led_iv.N_RETAINED_CROSS_SEGMENT==0), ...
            'tune_inner_stacked: retained cross-segment full-inner window');
        meta_iv=nrr_models.predict_base_set(bn_iv,Xi_iv,seg_iv);
        yp_iv=nrr_models.predict_ridge_stacker(stk, ...
            nrr_models.apply_meta_scaler(meta_iv,ms));
        rmse_lam(fi)=sqrt(mean((yi_iv-yp_iv).^2,'omitnan'));
    end
    cv_rmse=mean(rmse_lam,'omitnan'); cv_sd=std(rmse_lam,'omitnan');
    selected=isfinite(cv_rmse) && cv_rmse<best_lam_rmse;
    hp_log{end+1}={outer_fold_id,'stacker_lambda',NaN,lam,cv_rmse,cv_sd, ...
        selected,false,'min_cv_rmse_stacked_pipeline', ...
        'INNER_CV_TUNED_STACKED','STACKER_LAMBDA'}; %#ok<AGROW>
    if selected; best_lambda=lam; best_lam_rmse=cv_rmse; end
end

best_hp=nrr_models.default_hp(cfg);
best_hp.pnn_spread=best_spread;
best_hp.ridge_lambda=best_lambda;
best_hp.hp_status='INNER_CV_TUNED_STACKED';
best_hp.nn_hp_status='FIRST_IMPLEMENTATION';
best_hp.note=['PNN spread and stacker lambda tuned within outer training; ' ...
    'all CNN calls use physical-depth segments'];
hp_log=cell2table(vertcat(hp_log{:}),'VariableNames', ...
    {'OUTER_FOLD','MODEL','SPREAD','LAMBDA','CV_RMSE','CV_RMSE_SD', ...
    'SELECTED','HAD_FAILURE','SELECTION_RULE','HP_STATUS','TUNED_PARAM'});
end
