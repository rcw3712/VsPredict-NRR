function nrr_assert_canonical(D)
% NRR_ASSERT_CANONICAL  Assert all canonical numerical values.
%   Called by EVERY figure script before exportgraphics.
%   If any assertion fails, figure export is aborted.

tol = 5e-4;

assert(D.nWellA   == 492, 'nWellA mismatch');
assert(D.nWellB   == 492, 'nWellB mismatch');
assert(D.nDev     == 392, 'nDev mismatch');
assert(D.nHoldout == 100, 'nHoldout mismatch');
assert(D.nShared  == 163, 'nShared mismatch');
assert(D.nPopA    == 329, 'nPopA mismatch');
assert(D.nPopB    == 236, 'nPopB mismatch');

assert(abs(D.cvPooledR2   - 0.6632) < tol, 'cvPooledR2 mismatch: %.4f', D.cvPooledR2);
assert(abs(D.cvPooledRMSE - 0.0565) < tol, 'cvPooledRMSE mismatch: %.4f', D.cvPooledRMSE);
assert(abs(D.cvMeanR2     - 0.5526) < tol, 'cvMeanR2 mismatch');
assert(abs(D.cvSdR2       - 0.1246) < tol, 'cvSdR2 mismatch');

assert(abs(D.ridgePopAR2   + 2.6162) < tol, 'ridgePopAR2 mismatch: %.4f', D.ridgePopAR2);
assert(abs(D.ridgePopARMSE - 0.4115) < tol, 'ridgePopARMSE mismatch');
assert(abs(D.ridgePopABias - 0.3699) < tol, 'ridgePopABias mismatch');
assert(abs(D.ridgePopBR2   + 5.2708) < tol, 'ridgePopBR2 mismatch: %.4f', D.ridgePopBR2);

assert(abs(D.directPopAR2   - 0.6831) < tol, 'directPopAR2 mismatch');
assert(abs(D.directPopARMSE - 0.1218) < tol, 'directPopARMSE mismatch');
assert(abs(D.directPopBR2   - 0.6504) < tol, 'directPopBR2 mismatch');

% Domain shift: DT
dt_row = D.ds(strcmp(D.ds.FEATURE,'DT'),:);
assert(abs(dt_row.Z_BA_FULL - 7.85) < 0.01, 'DT z mismatch: %.4f', dt_row.Z_BA_FULL);
assert(abs(dt_row.KS_STAT   - 1.00) < 1e-4, 'DT KS mismatch');

% Geomechanical gates
ridge_allok  = D.geo_ridge.N_ALL_OK;
direct_allok = D.geo_dr.N_ALL_OK;
ridge_G      = D.geo_ridge.N_G_OK;
ridge_E      = D.geo_ridge.N_E_OK;
ridge_K      = D.geo_ridge.N_K_OK;

assert(ridge_allok  == 0,   'Ridge ALL_OK must be 0, got %d',   ridge_allok);
assert(direct_allok == 236, 'Direct ALL_OK must be 236, got %d', direct_allok);
assert(ridge_G      == 236, 'Ridge G_OK must be 236, got %d',    ridge_G);
assert(ridge_E      == 187, 'Ridge E_OK must be 187, got %d',    ridge_E);
assert(ridge_K      == 187, 'Ridge K_OK must be 187, got %d',    ridge_K);

assert(D.gate18_pass  == 44, 'Gate 18 must have 44 PASS, got %d', D.gate18_pass);
assert(D.gate18_total == 44, 'Gate 18 total must be 44, got %d',  D.gate18_total);

fprintf('[nrr_assert_canonical] ALL %d ASSERTIONS PASS\n', 26);
end
