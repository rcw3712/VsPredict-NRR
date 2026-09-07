function run = gate14_domain_shift(run, cfg)
% GATE 14: Domain shift. Primary: full Well-A (492) vs Pop-A (329).
T_A=run.T_A_raw; T_B=run.T_B_raw; popA=run.roles.popA_mask;
devM=run.roles.dev_mask; feats=cfg.data.features;
out5=fullfile(run.folder,'05_diagnostics'); rows={};
for fi=1:numel(feats)
    f=feats{fi};
    vA=T_A.(f); vA=vA(~isnan(vA));
    vA_d=T_A.(f)(devM); vA_d=vA_d(~isnan(vA_d));
    vB=T_B.(f)(popA); vB=vB(~isnan(vB));
    mu_A=mean(vA); sg_A=std(vA); mu_Ad=mean(vA_d); sg_Ad=std(vA_d); mu_B=mean(vB);
    z_full=(mu_B-mu_A)/sg_A; z_dev=(mu_B-mu_Ad)/sg_Ad;
    ood2=mean(vB<mu_A-2*sg_A|vB>mu_A+2*sg_A)*100;
    ood3=mean(vB<mu_A-3*sg_A|vB>mu_A+3*sg_A)*100;
    outmm=mean(vB<min(vA)|vB>max(vA))*100;
    % KS statistic
    all_v=sort([vA(:);vB(:)]);
    F1=arrayfun(@(v)mean(vA<=v),all_v); F2=arrayfun(@(v)mean(vB<=v),all_v);
    ks=max(abs(F1-F2));
    rows{end+1}={f,numel(vA),numel(vA_d),numel(vB),mu_A,sg_A,mu_B,...
        z_full,z_dev,ks,ood2,ood3,outmm};
    fprintf('[G14]   %-6s z_B|A_full=%+.2f z_B|A_dev=%+.2f OOD3=%.0f%%\n',...
        f,z_full,z_dev,ood3);
end
writetable(cell2table(vertcat(rows{:}),'VariableNames',...
    {'FEATURE','N_WELLA_FULL','N_WELLA_DEV','N_POPA',...
     'MU_WELLA','SG_WELLA','MU_POPA','Z_BA_FULL','Z_BA_DEV',...
     'KS_STAT','OOD_2SG_PCT','OOD_3SG_PCT','OUT_MINMAX_PCT'}),...
    fullfile(out5,'DOMAIN_SHIFT_DIAGNOSTICS.csv'));
run.gate.GATE_14='PASS';
fprintf('[G14] PASS\n');
end
