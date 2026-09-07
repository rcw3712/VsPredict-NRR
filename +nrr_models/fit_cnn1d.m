function model = fit_cnn1d(X, y, hp, seed, cfg)
% NRR_MODELS.FIT_CNN1D  Sliding-window 2D conv emulating temporal 1D (v4).
%   Window W: reshape X into [W 1 n_feat n_seq] for convolution2dLayer.
%   Architecture: Conv(3x1,nf)->BN->ReLU -> Conv(5x1,nf)->BN->ReLU -> GAP -> FC(1).
%   model.type = 'cnn1d' (never 'ridge_proxy').

nf = hp.filters;
lr = hp.lr;
ep = hp.epochs;
bs = hp.batch;
W  = cfg.hp.cnn1d_window;   % 16 (v4 cfg.base.window)

n=size(X,1); n_feat=size(X,2); n_seq=n-W+1;
model.type   = 'cnn1d';
model.window = W;
model.seed   = seed;
model.n_train= n;
model.filters= nf;
model.hp     = hp;

if n_seq<=0
    error('fit_cnn1d: n=%d < window=%d, cannot train',n,W);
end

% Build [W 1 n_feat n_seq] input
Xw=zeros(W,1,n_feat,n_seq,'single');
for j=1:n_seq; Xw(:,1,:,j)=reshape(single(X(j:j+W-1,:)),W,1,n_feat); end

% Align y to windowed positions
half=floor(W/2);
y_seq=y(half+1:min(n,n_seq+half));
n_y=numel(y_seq);
if n_y<n_seq; y_seq(end+1:n_seq)=mean(y_seq,'omitnan'); end
y_seq=reshape(single(y_seq(1:n_seq)),[1,1,1,n_seq]);

layers=[imageInputLayer([W 1 n_feat],'Normalization','none'),...
    convolution2dLayer([3 1],nf,'Padding','same'),batchNormalizationLayer,reluLayer,...
    convolution2dLayer([5 1],nf,'Padding','same'),batchNormalizationLayer,reluLayer,...
    globalAveragePooling2dLayer,fullyConnectedLayer(1),regressionLayer];

opts=trainingOptions('adam','MaxEpochs',ep,'MiniBatchSize',bs,...
    'InitialLearnRate',lr,'Shuffle','never','Verbose',false,'ExecutionEnvironment','cpu');

rng(seed,'twister');
model.net=trainNetwork(Xw,y_seq,layers,opts);
if ~isfield(cfg,'logging') || ~isfield(cfg.logging,'console_model_fit') || cfg.logging.console_model_fit
    fprintf('    [CNN1D] n=%d W=%d filters=%d lr=%.0e seed=%d\n',n,W,nf,lr,seed);
end
end
