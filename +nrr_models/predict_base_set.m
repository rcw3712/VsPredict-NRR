function [P, cnn_audit] = predict_base_set(nets, X, segment_ids)
% NRR_MODELS.PREDICT_BASE_SET  Apply four learners with explicit segments.
assert(nargin>=3 && ~isempty(segment_ids), ...
    'predict_base_set: segment_ids is mandatory');
assert(numel(segment_ids)==size(X,1), ...
    'predict_base_set: segment_ids length mismatch');
n=size(X,1); P=nan(n,4);
P(:,1)=nrr_models.predict_pnn(nets.pnn,X);
P(:,2)=nrr_models.predict_mlffnn(nets.mlffnn,X);
P(:,3)=nrr_models.predict_dffnn(nets.dffnn,X);
[P(:,4),cnn_audit]=nrr_models.predict_cnn1d(nets.cnn1d,X,segment_ids);
assert(all(isfinite(P),'all'),'predict_base_set: non-finite prediction');
assert(cnn_audit.N_RETAINED_CROSS_SEGMENT==0, ...
    'predict_base_set: cross-segment prediction window retained');

pairs={[2,3],[2,4],[3,4]};
for pi=1:numel(pairs)
    a=pairs{pi}(1); b=pairs{pi}(2);
    if max(abs(P(:,a)-P(:,b)))<1e-10
        warning('predict_base_set: learners %d and %d are identical',a,b);
    end
end
end
