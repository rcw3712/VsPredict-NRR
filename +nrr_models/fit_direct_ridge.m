function model = fit_direct_ridge(X, y, lam, cfg)
% NRR_MODELS.FIT_DIRECT_RIDGE  Gate 13 post-hoc model.
%   STATUS = POST_HOC_SENSITIVITY — immutable.
%   Trained on full Well-A n=492 with lambda=1.0 (fixed).
%   Intercept NOT penalized.
%   Cannot be labeled primary, selected, or confirmatory.

assert(nargin>=3,'fit_direct_ridge requires X, y, lam');
ok=~isnan(y);
assert(sum(ok)==cfg.dr.train_n||cfg.dr.train_n==0,...
    'fit_direct_ridge: expected n=%d, got %d',cfg.dr.train_n,sum(ok));

mu_x=mean(X(ok,:)); mu_y=mean(y(ok));
Xc=X(ok,:)-mu_x; yc=y(ok)-mu_y;
B=(Xc'*Xc+lam*eye(size(Xc,2)))\(Xc'*yc);
b0=mu_y-mu_x*B;

model.type       = 'direct_ridge';
model.status     = 'POST_HOC_SENSITIVITY';     % immutable
model.constraint = 'cannot_redefine_primary_analysis';
model.note       = 'requires_independent_third_well_confirmation';
model.B          = B;
model.b0         = b0;
model.mu_x       = mu_x;
model.lambda     = lam;
model.n_train    = sum(ok);
model.intercept_penalized = false;

% Hard assertion — enforced here and in report generator
assert(~strcmp(model.status,'primary'),'direct_ridge cannot be primary');
assert(~strcmp(model.status,'selected'),'direct_ridge cannot be selected');
fprintf('[DR] fit_direct_ridge: n=%d lambda=%.1f status=%s\n',...
    model.n_train,lam,model.status);
end
