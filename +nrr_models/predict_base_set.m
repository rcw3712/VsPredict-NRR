function P = predict_base_set(nets, X)
% NRR_MODELS.PREDICT_BASE_SET  Apply all 4 fitted base learners.
%   Returns n×4 matrix [pnn, mlffnn, dffnn, cnn1d].
%   Warns if any two learners produce identical predictions.
n=size(X,1); P=nan(n,4);
P(:,1)=nrr_models.predict_pnn(nets.pnn,X);
P(:,2)=nrr_models.predict_mlffnn(nets.mlffnn,X);
P(:,3)=nrr_models.predict_dffnn(nets.dffnn,X);
P(:,4)=nrr_models.predict_cnn1d(nets.cnn1d,X);

% Diversity check — warn if any pair is artificially identical
pairs={[2,3],[2,4],[3,4]};
for pi=1:3
    a=pairs{pi}(1); b=pairs{pi}(2);
    ok=isfinite(P(:,a))&isfinite(P(:,b));
    if any(ok) && max(abs(P(ok,a)-P(ok,b)))<1e-10
        warning('predict_base_set: learners %d and %d are identical — check training',a,b);
    end
end
end
