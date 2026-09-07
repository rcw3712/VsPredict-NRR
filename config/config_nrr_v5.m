function cfg = config_nrr_v5()
% CONFIG_NRR_V5  Master configuration for VsPredict_NRR_v5.
%   All values here are STRUCTURAL (architecture, grids, policy).
%   Scientific results come from the frozen run bundle only.
%   Target: Natural Resources Research (Springer, Q1)

cfg = struct();

%% Study identity
cfg.study.name      = 'VsPredict_NRR_v5';
cfg.study.version   = '5.1.0';
cfg.study.target    = 'Natural Resources Research (Springer, Q1)';
cfg.study.provenance_class = 'V5_CORRECTED_REANALYSIS';

%% Data — column names after normalization in nrr_data.load
% Original headers stripped of units: 'DEPTH (M)' -> 'DEPTH', etc.
% VS derived: 304.8 / DTS [us/ft] -> km/s
% VP derived: 304.8 / DT  [us/ft] -> km/s
cfg.data.wellA_file  = 'Well-A.xlsx';
cfg.data.wellB_file  = 'Well-B.xlsx';
cfg.data.features    = {'GR','DT','NPHI','RHOB'};  % fixed, no per-fold selection
cfg.data.target      = 'VS';
cfg.data.depth_col   = 'DEPTH';
cfg.data.id_col      = 'ROW_ID';
cfg.data.wellid_col  = 'WELL_ID';

%% Physical sanity ranges (audit, not imputation)
cfg.sanity.GR        = [0,   150];   % API
cfg.sanity.DT        = [50,  160];   % us/ft
cfg.sanity.NPHI      = [0,   60];    % %
cfg.sanity.RHOB      = [1.85,2.75];  % g/cc
cfg.sanity.VS        = [0.80,3.50];  % km/s
cfg.sanity.VP        = [2.00,5.50];  % km/s
cfg.sanity.vpvs_min  = sqrt(2);      % 1.4142
cfg.sanity.nu_min    = 0.0;
cfg.sanity.nu_max    = 0.5;

%% Duplicate audit (Gate 3)
cfg.dup.tol_depth    = 1e-6;   % m
cfg.dup.tol_log      = 1e-6;   % log unit
cfg.dup.check_cols   = {'GR','DT','NPHI','RHOB','DTS'};
cfg.dup.expected_n   = 163;    % canonical check after data-hash verification

%% Partition (Gates 4-5)
cfg.cv.n_outer       = 5;      % outer depth-blocked folds (development only)
cfg.cv.n_inner       = 4;      % inner tuning folds (within outer-train only)
cfg.cv.holdout_fold  = 5;      % deepest fold = Level-1 historical selection set

%% Seeds (v4 scheme: seed = base + offset + fold_id * fold_mult)
cfg.seeds.canonical      = 42;
cfg.seeds.multiseed      = [7, 42, 123];
cfg.seeds.bootstrap      = 2025;
cfg.seeds.offset_pnn     = 101;
cfg.seeds.offset_mlffnn  = 201;
cfg.seeds.offset_dffnn   = 301;
cfg.seeds.offset_cnn1d   = 401;
cfg.seeds.offset_ridge   = 501;
cfg.seeds.offset_fold    = 10000;   % fold_id * offset_fold added to model seed

%% Hyperparameter grids (tuned in inner loop only — v4 grids)
% PNN
cfg.hp.pnn_spread_grid      = [0.1, 0.2, 0.5, 1.0, 2.0];
% MLFFNN (2-layer)
cfg.hp.mlffnn_hidden_grid   = {[64,32],[32,16],[64,32],[128,64]};
cfg.hp.mlffnn_lr_grid       = [1e-3, 5e-4];
cfg.hp.mlffnn_epochs        = 500;
cfg.hp.mlffnn_batch         = 32;
% DFFNN (3-layer)
cfg.hp.dffnn_hidden_grid    = {[128,64,32],[64,32,16],[128,64]};
cfg.hp.dffnn_lr_grid        = [1e-3, 5e-4];
cfg.hp.dffnn_epochs         = 500;
cfg.hp.dffnn_batch          = 32;
% CNN1D (sliding window)
cfg.hp.cnn1d_filters_grid   = [32, 64];
cfg.hp.cnn1d_lr             = 1e-3;
cfg.hp.cnn1d_epochs         = 500;
cfg.hp.cnn1d_batch          = 32;
cfg.hp.cnn1d_window         = 16;   % v4: cfg.base.window
% Ridge stacker lambda grid
cfg.hp.ridge_lambda_grid    = [0.001, 0.01, 0.1, 1.0, 10.0];
% Intercept policy: NOT penalized (center data before regularization)
cfg.hp.ridge_penalize_intercept = false;

%% Execution environment (v4 Rule §4.2)
cfg.compute.shuffle    = 'never';
cfg.compute.env        = 'cpu';
cfg.compute.use_gpu    = false;

%% Direct Ridge (Gate 13 — POST_HOC only, immutable)
cfg.dr.lambda          = 1.0;
cfg.dr.train_n         = 492;
cfg.dr.status          = 'POST_HOC_SENSITIVITY';

%% Bootstrap (Gate 15)
cfg.boot.block_lens    = [10, 20, 30, 40];
cfg.boot.primary_bl    = 20;
cfg.boot.n_rep         = 3000;
cfg.boot.ci            = [0.025, 0.975];

%% Output
cfg.out.runs_dir       = 'runs';
cfg.out.dpi            = 300;

%% Gate registry (Gates 0-18 per audit spec)
cfg.gates.n_total      = 19;   % 0-18
cfg.gates.numerical_last = 17;
cfg.gates.repro        = 18;

%% Logging
cfg.logging.console_model_fit     = false;   % suppress per-model verbose in tune_inner
cfg.logging.write_training_ledger = true;    % always write CSV ledger

end
