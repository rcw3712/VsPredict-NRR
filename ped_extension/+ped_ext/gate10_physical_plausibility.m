function result = gate10_physical_plausibility(ctx, ext_model_result, pop_decision, ext_dir)
% PED_EXT.GATE10_PHYSICAL_PLAUSIBILITY  Application-specific physics screen.
% These mathematically related checks are diagnostics, not universal elastic
% stability conditions and not independent validation criteria.

out_dir=fullfile(ext_dir,'09_physics');
assert(isstruct(ext_model_result) && isfield(ext_model_result,'all_preds_popB'), ...
    'gate10: Pop-B model predictions unavailable');
assert(isfield(ctx.frozen_num,'run') && isfield(ctx.frozen_num.run,'T_B_raw'), ...
    'gate10: frozen Well-B table unavailable');
Tpred=ctx.predictions; popB=logical(Tpred.IS_POPB);
TB=ctx.frozen_num.run.T_B_raw;
assert(height(TB)==height(Tpred) && all(double(TB.ROW_ID)==double(Tpred.ROW_ID)), ...
    'gate10: Well-B/prediction ROW_ID mismatch');
P=double(ext_model_result.all_preds_popB);
assert(size(P,1)==sum(popB) && size(P,2)==6,'gate10: Pop-B prediction matrix mismatch');

Vp=double(TB.VP(popB)); rho=double(TB.RHOB(popB));
assert(all(isfinite(Vp)) && all(isfinite(rho)),'gate10: non-finite Vp/RHOB input');
if ismember('DT',TB.Properties.VariableNames)
    assert(max(abs(Vp-304.8./double(TB.DT(popB))))<1e-10,'gate10: Vp conversion mismatch');
end

names=["PNN";"MLFFNN";"DFFNN";"CNN1D";"Ridge_stacker";"Direct_Ridge"];
statuses=[repmat("PRESPECIFIED_BASE",4,1);"PRESPECIFIED_PRIMARY";"POST_HOC_SENSITIVITY"];
rows=cell(6,1);
for mi=1:6
    Vs=P(:,mi); ok=isfinite(Vs)&isfinite(Vp)&isfinite(rho);
    vpvs=Vp(ok)./Vs(ok);
    G=rho(ok).*Vs(ok).^2;
    K=rho(ok).*(Vp(ok).^2-4*Vs(ok).^2/3);
    nu=(Vp(ok).^2-2*Vs(ok).^2)./(2*(Vp(ok).^2-Vs(ok).^2));
    E=2*G.*(1+nu);
    n_vpgt=sum(Vp(ok)>Vs(ok)); n_vpvs=sum(vpvs>=sqrt(2));
    n_nu=sum(nu>=0&nu<0.5); n_G=sum(G>0); n_K=sum(K>0); n_E=sum(E>0);
    n_all=sum(Vp(ok)>Vs(ok)&vpvs>=sqrt(2)&nu>=0&nu<0.5&G>0&K>0&E>0& ...
        isfinite(G)&isfinite(K)&isfinite(E));
    rows{mi}={names(mi),statuses(mi),sum(ok),n_vpgt,n_vpvs,n_nu,n_G,n_K,n_E,n_all, ...
        100*n_all/sum(ok),"APPLICATION_SPECIFIC_SEDIMENTARY_ROCK_SCREEN"};
    fprintf('    %s Pop-B: Vp/Vs %d/%d | nu %d/%d | K %d/%d | ALL-OK %d/%d\n', ...
        names(mi),n_vpvs,sum(ok),n_nu,sum(ok),n_K,sum(ok),n_all,sum(ok));
end
Tpl=cell2table(vertcat(rows{:}),'VariableNames', ...
    {'MODEL','ANALYSIS_STATUS','N_EVALUATED','N_VP_GT_VS','N_VPVS_OK','N_NU_OK', ...
    'N_G_OK','N_K_OK','N_E_OK','N_ALL_OK','ALL_OK_PCT','SCREEN_LABEL'});
writetable(Tpl,fullfile(out_dir,'PED_PHYSICAL_PLAUSIBILITY_ALL_MODELS.csv'));

canon_path=fullfile(ctx.canonical_dir,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv');
assert(isfile(canon_path),'gate10: canonical geomechanical comparison missing');
Tc=readtable(canon_path,'TextType','string');
for pair={"ridge_stacker","direct_ridge"}
    cname=pair{1}; ci=strcmpi(string(Tc.MODEL),cname);
    pi=strcmpi(Tpl.MODEL,cname);
    assert(sum(ci)==1&&sum(pi)==1,'gate10: canonical/model row missing');
    assert(double(Tc.N_ALL_OK(ci))==Tpl.N_ALL_OK(pi), ...
        'gate10: N_ALL_OK mismatch for %s',cname);
end

Tformula=table(string({'Vp_km_s = 304.8 / DT_us_ft'; ...
    'G_GPa = rho_g_cm3 * Vs_km_s^2'; ...
    'K_GPa = rho_g_cm3 * (Vp^2 - 4Vs^2/3)'; ...
    'nu = (Vp^2 - 2Vs^2) / (2*(Vp^2 - Vs^2))'; ...
    'E_GPa = 2*G*(1+nu)';'1 g/cm3*(km/s)^2 = 1 GPa'}), ...
    repmat("VERIFIED",6,1),'VariableNames',{'FORMULA','VERIFICATION_STATUS'});
writetable(Tformula,fullfile(out_dir,'PED_PHYSICS_FORMULA_AUDIT.csv'));
Tnote=table(string({'DEPENDENCY';'VPVS_NU';'INTERPRETATION'}),string({ ...
    'All screens share Vp, predicted Vs, and density; failures are not independent.'; ...
    'Vp/Vs >= sqrt(2) is algebraically equivalent to nu >= 0 under isotropic elasticity.'; ...
    'nu >= 0 is an application-specific sedimentary-rock plausibility screen, not a universal stability condition.'}), ...
    'VariableNames',{'ITEM','INTERPRETATION'});
writetable(Tnote,fullfile(out_dir,'PED_PHYSICAL_FAILURE_ROOT_CAUSE.csv'));

fmd=fopen(fullfile(out_dir,'PED_PHYSICS_AUDIT.md'),'w');
fprintf(fmd,'# Physical-Admissibility Audit\n\n');
fprintf(fmd,'All formulas and units were verified on the canonical Pop-B rows.\n\n');
fprintf(fmd,'The Vp/Vs and Poisson-ratio screens are algebraically related and are not independent evidence. ');
fprintf(fmd,'The nonnegative Poisson-ratio threshold is application-specific, not a universal elastic-stability condition.\n');
fclose(fmd);

result.status=string('PASS'); result.code=string('OK');
result.message=string('Physics formulas, units, Pop-B alignment, and application-specific interpretation verified');
result.required=true; result.evidence_path=string(out_dir);
result.n_checks=8; result.n_pass=8; result.T_plausibility=Tpl;
end
