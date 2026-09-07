function qc_all_figures_nrr(canon_run_folder)
% QC_ALL_FIGURES_NRR  Run all canonical assertions before figure export.
%   If any assertion fails, prints the mismatch and aborts.
%   Call this BEFORE running any make_fig*.m script.

if nargin < 1; canon_run_folder = 'runs/run_20260903_155408'; end

fprintf('\n%s\n  NRR FIGURE QC — Canonical assertions\n%s\n\n', repmat('=',1,50), repmat('=',1,50));
D = nrr_load_canonical(canon_run_folder);

n_pass = 0; n_fail = 0;
function chk(label, val, expected, tol)
    if nargin < 4; tol = 0; end
    if tol == 0
        ok = isequal(val, expected);
    else
        ok = abs(val - expected) < tol;
    end
    if ok
        fprintf('  PASS  %s\n', label); n_pass=n_pass+1;
    else
        fprintf('  FAIL  %s — got %g, expected %g\n', label, val, expected); n_fail=n_fail+1;
    end
end

%% Dataset
chk('nWellA == 492',   D.nWellA,   492);
chk('nWellB == 492',   D.nWellB,   492);
chk('nDev == 392',     D.nDev,     392);
chk('nHoldout == 100', D.nHoldout, 100);
chk('nShared == 163',  D.nShared,  163);
chk('nPopA == 329',    D.nPopA,    329);
chk('nPopB == 236',    D.nPopB,    236);
chk(sprintf('nPopA = nWellB - nShared (%d = %d - %d)',D.nPopA,D.nWellB,D.nShared), D.nPopA+D.nShared, D.nWellB);

%% Nested CV
chk('cvPooledR2 = 0.6632',   D.cvPooledR2,   0.6632, 5e-4);
chk('cvPooledRMSE = 0.0565', D.cvPooledRMSE, 0.0565, 5e-4);
chk('cvMeanR2 = 0.5526',     D.cvMeanR2,     0.5526, 5e-4);
chk('cvSdR2 = 0.1246',       D.cvSdR2,       0.1246, 5e-4);

%% Fold R²
r2 = [0.4073,0.4638,0.6943,0.5325,0.6651];
for fi=1:5
    if ismember('R2',D.cv_fold.Properties.VariableNames)
        chk(sprintf('Fold %d R2',fi), D.cv_fold.R2(fi), r2(fi), 5e-4);
    end
end

%% Primary blind Ridge
chk('ridgePopAR2 = -2.6162',   D.ridgePopAR2,   -2.6162, 5e-4);
chk('ridgePopARMSE = 0.4115',  D.ridgePopARMSE,  0.4115, 5e-4);
chk('ridgePopABias = +0.3699', D.ridgePopABias, +0.3699, 5e-4);
chk('ridgePopBR2 = -5.2708',   D.ridgePopBR2,   -5.2708, 5e-4);
chk('ridgePopBRMSE = 0.4625',  D.ridgePopBRMSE,  0.4625, 5e-4);
chk('ridgePopBBias = +0.4339', D.ridgePopBBias, +0.4339, 5e-4);

%% Direct Ridge
chk('directPopAR2 = 0.6831',   D.directPopAR2,  0.6831, 5e-4);
chk('directPopARMSE = 0.1218', D.directPopARMSE,0.1218, 5e-4);
chk('directPopABias = -0.0112',D.directPopABias,-0.0112,5e-4);
chk('directPopBR2 = 0.6504',   D.directPopBR2,  0.6504, 5e-4);

%% Domain shift
dt_row = D.ds(strcmp(D.ds.FEATURE,'DT'),:);
chk('DT z_BA_FULL = +7.85', dt_row.Z_BA_FULL, 7.85, 0.01);
chk('DT KS = 1.000',        dt_row.KS_STAT,   1.00, 1e-4);
chk('DT OOD 3sigma = 100%', dt_row.OOD_3SG_PCT, 100, 0.01);

%% Geomechanics
chk('Ridge Vp/Vs = 0/236',  D.geo_ridge.N_VPVS_OK, 0);
chk('Ridge Nu = 0/236',     D.geo_ridge.N_NU_OK,   0);
chk('Ridge E = 187/236',    D.geo_ridge.N_E_OK,   187);
chk('Ridge G = 236/236',    D.geo_ridge.N_G_OK,   236);
chk('Ridge K = 187/236',    D.geo_ridge.N_K_OK,   187);
chk('Ridge ALL_OK = 0/236', D.geo_ridge.N_ALL_OK,   0);
chk('DR ALL_OK = 236/236',  D.geo_dr.N_ALL_OK,    236);

%% Gate 18
chk('Gate18 pass = 44',     D.gate18_pass,  44);
chk('Gate18 total = 44',    D.gate18_total, 44);

%% Summary
fprintf('\n%s\n', repmat('-',1,50));
if n_fail == 0
    fprintf('  NRR FIGURE QC: ALL %d CHECKS PASS\n', n_pass);
    fprintf('  Proceed to make_fig*.m scripts.\n');
else
    fprintf('  NRR FIGURE QC: %d CHECKS FAILED — DO NOT EXPORT FIGURES\n', n_fail);
    error('Canonical numerical mismatch. Figure generation aborted.');
end
fprintf('%s\n\n', repmat('=',1,50));
end
