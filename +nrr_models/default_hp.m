function hp = default_hp(cfg)
% NRR_MODELS.DEFAULT_HP  Build default HP struct from config.
%   Used when a function needs a complete HP struct without tuning.
hp.pnn_spread      = cfg.hp.pnn_spread_grid(1);
hp.ridge_lambda    = cfg.hp.ridge_lambda_grid(1);
hp.mlffnn_hidden   = cfg.hp.mlffnn_hidden_grid{1};
hp.mlffnn_lr       = cfg.hp.mlffnn_lr_grid(1);
hp.mlffnn_epochs   = cfg.hp.mlffnn_epochs;
hp.mlffnn_batch    = cfg.hp.mlffnn_batch;
hp.dffnn_hidden    = cfg.hp.dffnn_hidden_grid{1};
hp.dffnn_lr        = cfg.hp.dffnn_lr_grid(1);
hp.dffnn_epochs    = cfg.hp.dffnn_epochs;
hp.dffnn_batch     = cfg.hp.dffnn_batch;
hp.cnn1d_filters   = cfg.hp.cnn1d_filters_grid(1);
hp.cnn1d_lr        = cfg.hp.cnn1d_lr;
hp.cnn1d_epochs    = cfg.hp.cnn1d_epochs;
hp.cnn1d_batch     = cfg.hp.cnn1d_batch;
hp.hp_status       = 'DEFAULT';
hp.nn_hp_status    = 'FIRST_IMPLEMENTATION';
hp.note            = 'default HP from config grid[1]';
end
