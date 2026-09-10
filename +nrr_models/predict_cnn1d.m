function [pred, audit] = predict_cnn1d(model, X, segment_ids)
% NRR_MODELS.PREDICT_CNN1D  Segment-aware sliding-window prediction.
% Edge values are filled only from predictions in the same depth segment.

assert(nargin>=3 && ~isempty(segment_ids), ...
    'predict_cnn1d: segment_ids is mandatory (fail-closed policy)');
n=size(X,1); nf=size(X,2); W=model.window;
segment_ids=double(segment_ids(:));
assert(numel(segment_ids)==n && all(isfinite(segment_ids)), ...
    'predict_cnn1d: segment_ids length/content mismatch');
assert(~isempty(model.net),'predict_cnn1d: fitted network is missing');

pred=nan(n,1); candidate=0; valid_count=0; discarded=0;
for s=unique(segment_ids(:))'
    ix=find(segment_ids==s);
    assert(all(diff(ix)==1), ...
        'predict_cnn1d: each segment must occupy contiguous rows');
    ns=numel(ix)-W+1;
    assert(ns>0, ...
        'predict_cnn1d: segment %g has %d rows < window %d',s,numel(ix),W);
    candidate=candidate+ns;
    Xw=zeros(W,1,nf,ns,'single');
    for j=1:ns
        w=ix(j:j+W-1);
        assert(all(segment_ids(w)==s),'predict_cnn1d: cross-segment window');
        Xw(:,1,:,j)=reshape(single(X(w,:)),W,1,nf);
    end
    pw=double(squeeze(predict(model.net,Xw))); pw=pw(:);
    anchors=ix((1:ns)+floor(W/2)); pred(anchors)=pw;
    pseg=pred(ix); pseg=fillmissing(pseg,'nearest'); pred(ix)=pseg;
    valid_count=valid_count+ns;
end
assert(all(isfinite(pred)),'predict_cnn1d: prediction incomplete');
audit=table(n,max(segment_ids),W,candidate,valid_count,discarded,0, ...
    'VariableNames',{'N_ROWS','N_SEGMENTS','WINDOW','N_CANDIDATE', ...
    'N_VALID','N_DISCARDED_CROSS_SEGMENT','N_RETAINED_CROSS_SEGMENT'});
end
