function dpi = nrr_effective_png_dpi(info)
% NRR_EFFECTIVE_PNG_DPI  Unit-aware DPI from imfinfo struct.
%   PNG XResolution may be px/m (23622 ≈ 600 dpi). Converts correctly.
%   Used by both nrr_export_figure and artifact QC.

xr = double(info.XResolution);

if isfield(info,'ResolutionUnit')
    u = lower(string(info.ResolutionUnit));
else
    u = "";
end

if contains(u,"meter")
    dpi = xr * 0.0254;
elseif contains(u,"inch")
    dpi = xr;
elseif contains(u,"centimeter")
    dpi = xr * 2.54;
else
    if xr > 5000
        dpi = xr * 0.0254;   % px/m fallback
    else
        dpi = xr;
    end
end
end
