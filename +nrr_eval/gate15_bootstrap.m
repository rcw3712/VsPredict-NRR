function run = gate15_bootstrap(run, cfg)
% GATE 15: Moving-block bootstrap. Ridge and Direct Ridge separate columns.
rng(cfg.seeds.bootstrap,'twister');
out6=fullfile(run.folder,'06_bootstrap');
y_B=run.blind.y_B; yp_R=run.blind.y_raw; yp_DR=run.posthoc.y_pred;
popA=run.roles.popA_mask; popB=run.roles.popB_mask;
B=cfg.boot.n_rep; ci=cfg.boot.ci;
sumrows={}; blrows={};
for pname={'Pop_A','Pop_B'}
    if strcmp(pname{1},'Pop_A'); mask=popA; else; mask=popB; end
    yt=y_B(mask); yr=yp_R(mask); yd=yp_DR(mask);
    ok=isfinite(yt)&isfinite(yr)&isfinite(yd);
    yt=yt(ok); yr=yr(ok); yd=yd(ok); n=numel(yt);
    for bl=cfg.boot.block_lens
        r2R=nan(B,1); r2D=nan(B,1); rmseR=nan(B,1); n_inv=0;
        for bi=1:B
            nb=ceil(n/bl); st=randi(n,nb,1); idx=[];
            for bj=1:nb; blk=mod((st(bj):st(bj)+bl-1)-1,n)+1; idx=[idx,blk]; end
            idx=idx(1:n); ys=yt(idx); rs=yr(idx); ds=yd(idx);
            ss=sum((ys-mean(ys)).^2);
            if ss<eps; n_inv=n_inv+1; continue; end
            r2R(bi)=1-sum((ys-rs).^2)/ss;
            r2D(bi)=1-sum((ys-ds).^2)/ss;
            rmseR(bi)=sqrt(mean((ys-rs).^2));
        end
        ok_b=isfinite(r2R); nv=sum(ok_b); prim=(bl==cfg.boot.primary_bl);
        q_r2R=quantile(r2R(ok_b),ci); q_r2D=quantile(r2D(ok_b),ci);
        q_rmR=quantile(rmseR(ok_b),ci);
        blrows{end+1}={pname{1},bl,n,nv,n_inv,...
            q_r2R(1),q_r2R(2),q_r2D(1),q_r2D(2),...
            q_rmR(1),q_rmR(2),cfg.seeds.bootstrap,prim};
        if prim
            sumrows{end+1}={pname{1},bl,n,nv,n_inv,...
                q_r2R(1),q_r2R(2),q_r2D(1),q_r2D(2)};
            fprintf('[G15]   %-6s BL=%2d Ridge[%.3f,%.3f] DR[%.3f,%.3f] inv=%d\n',...
                pname{1},bl,q_r2R(1),q_r2R(2),q_r2D(1),q_r2D(2),n_inv);
        end
    end
end
sc={'POPULATION','BLOCK_LEN','N_TOTAL','N_VALID','N_INVALID',...
    'RIDGE_R2_LO','RIDGE_R2_HI','DR_R2_LO','DR_R2_HI'};
writetable(cell2table(vertcat(sumrows{:}),'VariableNames',sc),...
    fullfile(out6,'BLOCK_BOOTSTRAP_SUMMARY.csv'));
bl_c=[sc,{'RIDGE_RMSE_LO','RIDGE_RMSE_HI','BOOT_SEED','IS_PRIMARY_BL'}];
writetable(cell2table(vertcat(blrows{:}),'VariableNames',bl_c),...
    fullfile(out6,'BLOCK_LENGTH_SENSITIVITY.csv'));
run.gate.GATE_15='PASS';
fprintf('[G15] PASS\n');
end
