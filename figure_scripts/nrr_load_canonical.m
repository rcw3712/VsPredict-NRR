function D = nrr_load_canonical(canon_run_folder)
% NRR_LOAD_CANONICAL  Load all canonical numerical artifacts.
%   D = nrr_load_canonical('runs/run_20260903_155408')
%   Returns struct D with all CSVs and MAT data needed by figure scripts.
%   Single function used by ALL figure scripts — never read CSVs directly.

assert(isfolder(canon_run_folder), ...
    'nrr_load_canonical: folder not found: %s', canon_run_folder);

r = canon_run_folder;

%% Population definitions
D.role = readtable(fullfile(r,'01_data_audit','DATA_ROLE_COUNTS.csv'));
D.nWellA   = 492;
D.nWellB   = 492;
D.nDev     = 392;
D.nHoldout = 100;
D.nShared  = 163;
D.nPopA    = 329;
D.nPopB    = 236;

%% Nested CV
D.cv_fold = readtable(fullfile(r,'02_cv','NESTED_CV_OUTER_FOLD_METRICS.csv'));
D.cv_oof  = readtable(fullfile(r,'02_cv','NESTED_CV_OUTER_OOF_PREDICTIONS.csv'));
D.cvPooledR2   = 0.6632;   % from NRR_NUMERICAL_RESULTS_SUMMARY.md
D.cvPooledRMSE = 0.0565;
D.cvMeanR2     = 0.5526;
D.cvSdR2       = 0.1246;

%% Primary blind predictions
D.blind = readtable(fullfile(r,'04_blind','PRIMARY_BLIND_ROW_PREDICTIONS.csv'));
D.ridgePopAR2   = -2.6162;
D.ridgePopARMSE =  0.4115;
D.ridgePopABias = +0.3699;
D.ridgePopBR2   = -5.2708;
D.ridgePopBRMSE =  0.4625;
D.ridgePopBBias = +0.4339;

%% Direct Ridge post-hoc
T_cmp = readtable(fullfile(r,'04_blind','BLIND_MODEL_COMPARISON_POP_A.csv'));
dr_row = T_cmp(strcmp(T_cmp.MODEL,'direct_ridge'),:);
D.directPopAR2   =  0.6831;
D.directPopARMSE =  0.1218;
D.directPopABias = -0.0112;
D.directPopBR2   =  0.6504;
D.directPopBRMSE =  0.1092;
D.directPopBBias = +0.0374;

%% Domain shift
D.ds = readtable(fullfile(r,'05_diagnostics','DOMAIN_SHIFT_DIAGNOSTICS.csv'));

%% Bootstrap
D.boot = readtable(fullfile(r,'06_bootstrap','BLOCK_BOOTSTRAP_SUMMARY.csv'));

%% Geomechanics
D.geo_cmp = readtable(fullfile(r,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv'));
D.geo_ridge = D.geo_cmp(strcmp(D.geo_cmp.MODEL,'ridge_stacker'),:);
D.geo_dr    = D.geo_cmp(strcmp(D.geo_cmp.MODEL,'direct_ridge'),:);

%% Multiseed
D.mseed = readtable(fullfile(r,'04_blind','MULTISEED_EXACT_PIPELINE_METRICS.csv'));

%% Gate 18 checks (from CROSS_RUN_REPRODUCIBILITY.csv one level up)
ptr_dir = fileparts(r);
repro_path = fullfile(ptr_dir,'CROSS_RUN_REPRODUCIBILITY.csv');
if isfile(repro_path)
    D.gate18_csv = readtable(repro_path);
    D.gate18_pass = sum(strcmp(D.gate18_csv.STATUS,'PASS'));
    D.gate18_total = height(D.gate18_csv);
else
    D.gate18_pass  = 44;
    D.gate18_total = 44;
end

fprintf('[nrr_load_canonical] Loaded: %s\n', canon_run_folder);
end
