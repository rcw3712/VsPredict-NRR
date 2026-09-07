function model = fit_pnn(X, y, hp, seed, cfg)
% NRR_MODELS.FIT_PNN  Nadaraya-Watson kernel regression (v4 architecture).
%   model.type = 'pnn' (never 'ridge_proxy').
%   hp.spread: kernel bandwidth.
%   Seed set before any stochastic operation.
rng(seed, 'twister');
ok=~isnan(y);
model.type   = 'pnn';
model.X_tr   = X(ok,:);
model.y_tr   = y(ok);
model.spread = hp.spread;
model.seed   = seed;
model.n_train= sum(ok);
model.n_feat = size(X,2);
model.hp     = hp;
if ~isfield(cfg,'logging') || ~isfield(cfg.logging,'console_model_fit') || cfg.logging.console_model_fit
    if ~isfield(hp,'silent') || ~hp.silent
    fprintf('    [PNN] n=%d spread=%.4f seed=%d\n',model.n_train,model.spread,seed);
end
end
end
