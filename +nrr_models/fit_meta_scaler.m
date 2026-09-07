function ms = fit_meta_scaler(oof_meta)
% NRR_MODELS.FIT_META_SCALER  Fit meta-feature scaler on OOF predictions only.
%   Must be called ONLY on training OOF meta-features.
%   Never call on validation or deployment meta-features.
%
%   ms.mu     : 1×4 column means (fitted on training OOF)
%   ms.sg     : 1×4 column stds  (fitted on training OOF)
%   ms.input_space : 'raw_meta'   (what goes IN)
%   ms.output_space: 'standardized_meta' (what comes OUT)
%   ms.feature_names: {'PNN','MLFFNN','DFFNN','CNN1D'}

ms.mu            = nanmean(oof_meta, 1);
ms.sg            = nanstd(oof_meta,  0, 1);
ms.sg(ms.sg < 1e-9) = 1;   % avoid division by zero
ms.input_space   = 'raw_meta';
ms.output_space  = 'standardized_meta';
ms.feature_names = {'PNN','MLFFNN','DFFNN','CNN1D'};
ms.n_fit         = size(oof_meta, 1);

% Verify scaler is well-conditioned
assert(all(isfinite(ms.mu)), 'fit_meta_scaler: NaN/Inf in mu');
assert(all(isfinite(ms.sg)), 'fit_meta_scaler: NaN/Inf in sg');
assert(all(ms.sg > 0),       'fit_meta_scaler: zero sg');
end
