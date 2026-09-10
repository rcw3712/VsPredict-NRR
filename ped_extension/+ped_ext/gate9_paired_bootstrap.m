function result = gate9_paired_bootstrap(ctx, ext_model_result, pop_decision, ext_dir)
% PED_EXT.GATE9_PAIRED_BOOTSTRAP  Paired moving-block bootstrap on Pop-A.

out_dir=fullfile(ext_dir,'08_bootstrap');
assert(isstruct(ext_model_result) && isfield(ext_model_result,'all_preds'), ...
    'gate9: external model predictions unavailable');
assert(size(ext_model_result.all_preds,2)>=6,'gate9: Direct Ridge comparator missing');
yt=double(ext_model_result.y_true_popA(:));
yr=double(ext_model_result.all_preds(:,5));
yd=double(ext_model_result.all_preds(:,6));
assert(numel(yt)==ctx.n_popA && all(isfinite([yr;yd])), ...
    'gate9: incomplete paired Pop-A vectors');

block_lens=[10 20 30 40]; n_boot=3000; boot_seed=2025;
rng(boot_seed,'twister'); rows={}; contrast_rows={};
for bl=block_lens
    br=nan(n_boot,1); bd=nan(n_boot,1);
    for bi=1:n_boot
        idx=block_resample(numel(yt),bl);
        yb=yt(idx);
        if var(yb)<1e-10; continue; end
        br(bi)=local_r2(yb,yr(idx));
        bd(bi)=local_r2(yb,yd(idx));
    end
    ok=isfinite(br)&isfinite(bd); br=br(ok); bd=bd(ok); delta=bd-br;
    assert(numel(delta)>0.95*n_boot,'gate9: insufficient valid bootstrap replicates');
    cir=quantile(br,[0.025 0.975]); cid=quantile(bd,[0.025 0.975]);
    cix=quantile(delta,[0.025 0.975]); p_le_zero=mean(delta<=0);
    rows(end+1,:)={bl,"Ridge_stacker","PRESPECIFIED_PRIMARY",cir(1),cir(2),numel(br)}; %#ok<AGROW>
    rows(end+1,:)={bl,"Direct_Ridge","POST_HOC_SENSITIVITY",cid(1),cid(2),numel(bd)}; %#ok<AGROW>
    contrast_rows(end+1,:)={bl,"R2_Direct_minus_R2_Stacker",mean(delta),cix(1),cix(2),p_le_zero,numel(delta)}; %#ok<AGROW>
    fprintf('    block=%d: stacker CI=[%.4f,%.4f] | direct CI=[%.4f,%.4f] | delta CI=[%.4f,%.4f]\n', ...
        bl,cir(1),cir(2),cid(1),cid(2),cix(1),cix(2));
end
Tb=cell2table(rows,'VariableNames', ...
    {'BLOCK_LEN','MODEL','STATUS','CI_LO_2p5','CI_HI_97p5','N_VALID'});
Tc=cell2table(contrast_rows,'VariableNames', ...
    {'BLOCK_LEN','CONTRAST','MEAN_DELTA_R2','CI_LO_2p5','CI_HI_97p5','P_DELTA_LE_ZERO','N_VALID'});
writetable(Tb,fullfile(out_dir,'PED_PAIRED_MODEL_BOOTSTRAP.csv'));
writetable(Tc,fullfile(out_dir,'PED_PAIRED_MODEL_BOOTSTRAP_CONTRAST.csv'));

all_positive=all(Tc.CI_LO_2p5>0);
assert(all_positive,'gate9: paired Direct-minus-stacker CI includes zero');
fmd=fopen(fullfile(out_dir,'PED_PAIRED_MODEL_BOOTSTRAP_SUMMARY.md'),'w');
fprintf(fmd,'# Paired Moving-Block Bootstrap - Pop-A R2\n\n');
fprintf(fmd,'Seed %d; %d replicates; block lengths 10, 20, 30, and 40.\n\n',boot_seed,n_boot);
fprintf(fmd,'The paired Direct Ridge minus Ridge-stacker R2 interval is above zero at every block length.\n');
fprintf(fmd,'Direct Ridge remains a post-hoc sensitivity analysis.\n');
fclose(fmd);

result.status=string('PASS'); result.code=string('OK');
result.message=string('Paired moving-block bootstrap completed for Ridge stacker versus Direct Ridge');
result.required=true; result.evidence_path=string(out_dir);
result.n_checks=numel(block_lens); result.n_pass=numel(block_lens);
result.T_bootstrap=Tb; result.T_contrast=Tc;
end

function idx=block_resample(n,bl)
starts=randi(n,ceil(n/bl),1); idx=zeros(ceil(n/bl)*bl,1); pos=1;
for i=1:numel(starts)
    block=mod((starts(i)-1:starts(i)+bl-2),n)+1;
    idx(pos:pos+bl-1)=block(:); pos=pos+bl;
end
idx=idx(1:n);
end

function r=local_r2(y,yp)
r=1-sum((y-yp).^2)/sum((y-mean(y)).^2);
end
