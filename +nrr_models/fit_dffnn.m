function model = fit_dffnn(X, y, hp, seed, cfg)
% NRR_MODELS.FIT_DFFNN  3-layer deeper MLP via trainNetwork.
%   Same architecture as MLFFNN but deeper hidden stack.
%   model.type = 'dffnn' (never 'ridge_proxy').

hidden = hp.hidden;   % e.g. [128,64,32]
lr     = hp.lr;
ep     = hp.epochs;
bs     = hp.batch;
n_in   = size(X,2);

layers = featureInputLayer(n_in,'Normalization','none','Name','input');
for hi=1:numel(hidden)
    layers=[layers,...
        fullyConnectedLayer(hidden(hi),'Name',sprintf('fc%d',hi)),...
        batchNormalizationLayer('Name',sprintf('bn%d',hi)),...
        reluLayer('Name',sprintf('relu%d',hi))]; %#ok<AGROW>
end
layers=[layers,fullyConnectedLayer(1,'Name','output'),regressionLayer('Name','regout')];

opts=trainingOptions('adam',...
    'MaxEpochs',ep,'MiniBatchSize',bs,'InitialLearnRate',lr,...
    'Shuffle','never','Verbose',false,'ExecutionEnvironment','cpu');

rng(seed,'twister');
ok=~isnan(y);
net=trainNetwork(single(X(ok,:)),single(y(ok)),layers,opts);

model.type    = 'dffnn';
model.net     = net;
model.seed    = seed;
model.hidden  = hidden;
model.lr      = lr;
model.epochs  = ep;
model.n_train = sum(ok);
model.n_feat  = n_in;
model.hp      = hp;
if ~isfield(cfg,'logging') || ~isfield(cfg.logging,'console_model_fit') || cfg.logging.console_model_fit
    fprintf('    [DFFNN] n=%d hidden=[%s] lr=%.0e seed=%d\n',...
    model.n_train,num2str(hidden),lr,seed);
end
end
