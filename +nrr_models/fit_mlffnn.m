function model = fit_mlffnn(X, y, hp, seed, cfg)
% NRR_MODELS.FIT_MLFFNN  2-layer MLP via trainNetwork (Deep Learning Toolbox).
%   Architecture from v4: FC(H1)->BN->ReLU -> FC(H2)->BN->ReLU -> FC(1).
%   Shuffle='never' (v4 Rule §4.2). CPU only.
%   Intercept NOT penalized (no regularization on bias).
%   model.type = 'mlffnn' (never 'ridge_proxy').
%   Failure throws error — no silent fallback.

hidden = hp.hidden;   % e.g. [64,32]
lr     = hp.lr;
ep     = hp.epochs;
bs     = hp.batch;
n_in   = size(X,2);

% Build layers
layers = featureInputLayer(n_in,'Normalization','none','Name','input');
for hi=1:numel(hidden)
    layers=[layers,...
        fullyConnectedLayer(hidden(hi),'Name',sprintf('fc%d',hi)),...
        batchNormalizationLayer('Name',sprintf('bn%d',hi)),...
        reluLayer('Name',sprintf('relu%d',hi))]; %#ok<AGROW>
end
layers=[layers, fullyConnectedLayer(1,'Name','output'), regressionLayer('Name','regout')];

opts=trainingOptions('adam',...
    'MaxEpochs',ep,'MiniBatchSize',bs,'InitialLearnRate',lr,...
    'Shuffle','never','Verbose',false,'ExecutionEnvironment','cpu');

rng(seed,'twister');
ok=~isnan(y);
net=trainNetwork(single(X(ok,:)),single(y(ok)),layers,opts);

model.type    = 'mlffnn';
model.net     = net;
model.seed    = seed;
model.hidden  = hidden;
model.lr      = lr;
model.epochs  = ep;
model.n_train = sum(ok);
model.n_feat  = n_in;
model.hp      = hp;
if ~isfield(cfg,'logging') || ~isfield(cfg.logging,'console_model_fit') || cfg.logging.console_model_fit
    fprintf('    [MLFFNN] n=%d hidden=[%s] lr=%.0e seed=%d\n',...
    model.n_train,num2str(hidden),lr,seed);
end
end
