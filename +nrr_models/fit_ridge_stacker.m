function model = fit_ridge_stacker(oof_sc, y, lam, cfg)
% NRR_MODELS.FIT_RIDGE_STACKER  Fit Ridge meta-learner on SCALED OOF predictions.
%   INPUT MUST be standardized_meta (output of apply_meta_scaler).
%   Intercept NOT penalized (center before regularization).
%   P0-1 fix: stacker is always fit on scaled space, never on raw OOF.

assert(nargin >= 3, 'fit_ridge_stacker requires oof_sc, y, lam');

ok = ~isnan(y);
M  = oof_sc(ok,:); yb = y(ok);

% Impute any remaining NaN (should be none after apply_meta_scaler)
for ci = 1:size(M,2)
    nan_m = isnan(M(:,ci));
    if any(nan_m); M(nan_m,ci) = 0; end   % already standardized, 0 = mean
end

% Center y (intercept not penalized)
mu_y = mean(yb);
yc   = yb - mu_y;
B    = (M'*M + lam*eye(size(M,2))) \ (M'*yc);
b0   = mu_y;   % intercept in y-space (M already centered by scaler)

assert(all(isfinite(B)) && isfinite(b0), ...
    'fit_ridge_stacker: NaN/Inf in coefficients');

model.type          = 'ridge_stacker';
model.input_space   = 'standardized_meta';     % P0-1: explicit space label
model.feature_names = {'PNN','MLFFNN','DFFNN','CNN1D'};
model.B             = B;
model.b0            = b0;
model.lambda        = lam;
model.n_train       = sum(ok);
model.intercept_penalized = false;
end
