function model = fit_cnn1d(X, y, hp, seed, cfg, segment_ids)
% NRR_MODELS.FIT_CNN1D  Segment-aware CNN1D training (PED correction).
% segment_ids is mandatory. Candidate windows spanning two segments are
% discarded before tensors and targets are constructed.

assert(nargin>=6 && ~isempty(segment_ids), ...
    'fit_cnn1d: segment_ids is mandatory (fail-closed policy)');
n=size(X,1); nf_in=size(X,2); W=cfg.hp.cnn1d_window;
segment_ids=double(segment_ids(:));
assert(numel(segment_ids)==n && all(isfinite(segment_ids)), ...
    'fit_cnn1d: segment_ids length/content mismatch');
assert(numel(y)==n,'fit_cnn1d: target length mismatch');

n_candidate=max(0,n-W+1);
assert(n_candidate>0,'fit_cnn1d: n=%d < window=%d',n,W);
valid=false(n_candidate,1);
for j=1:n_candidate
    valid(j)=all(segment_ids(j:j+W-1)==segment_ids(j));
end
starts=find(valid); n_valid=numel(starts); n_discard=n_candidate-n_valid;
assert(n_valid>0,'fit_cnn1d: no within-segment windows remain');

Xw=zeros(W,1,nf_in,n_valid,'single'); anchors=zeros(n_valid,1);
half=floor(W/2);
for k=1:n_valid
    j=starts(k); w=j:j+W-1;
    Xw(:,1,:,k)=reshape(single(X(w,:)),W,1,nf_in);
    anchors(k)=j+half;
end
y_seq=reshape(single(y(anchors)),[1 1 1 n_valid]);
assert(all(isfinite(y_seq),'all'),'fit_cnn1d: non-finite window targets');

nf=hp.filters;
layers=[imageInputLayer([W 1 nf_in],'Normalization','none'), ...
    convolution2dLayer([3 1],nf,'Padding','same'),batchNormalizationLayer,reluLayer, ...
    convolution2dLayer([5 1],nf,'Padding','same'),batchNormalizationLayer,reluLayer, ...
    globalAveragePooling2dLayer,fullyConnectedLayer(1),regressionLayer];
opts=trainingOptions('adam','MaxEpochs',hp.epochs,'MiniBatchSize',hp.batch, ...
    'InitialLearnRate',hp.lr,'Shuffle','never','Verbose',false, ...
    'ExecutionEnvironment','cpu');
rng(seed,'twister');

model=struct('type','cnn1d','window',W,'seed',seed,'n_train',n, ...
    'filters',nf,'hp',hp,'segment_policy','PHYSICAL_DEPTH_SEGMENTS', ...
    'segment_ids',segment_ids,'valid_starts',starts,'anchor_indices',anchors, ...
    'n_candidate_windows',n_candidate,'n_valid_windows',n_valid, ...
    'n_discarded_cross_segment',n_discard, ...
    'n_retained_cross_segment',0);
model.net=trainNetwork(Xw,y_seq,layers,opts);
assert(model.n_retained_cross_segment==0, ...
    'fit_cnn1d: cross-segment window retained');
if n_discard>0
    fprintf('    [CNN1D] discarded %d/%d cross-segment training windows; retained-cross=0\n', ...
        n_discard,n_candidate);
end
end
