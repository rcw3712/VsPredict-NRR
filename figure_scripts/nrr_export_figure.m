function nrr_export_figure(fig_handle, out_dir, fig_name)
% NRR_EXPORT_FIGURE  Export PNG 600 DPI + vector PDF + .fig
%   Unit-aware DPI resolution: PNG XResolution may be px/m (23622 ≈ 600 dpi).

if ~isfolder(out_dir); mkdir(out_dir); end
drawnow;

png_path = fullfile(out_dir, [fig_name '.png']);
pdf_path = fullfile(out_dir, [fig_name '.pdf']);
fig_path = fullfile(out_dir, [fig_name '.fig']);

exportgraphics(fig_handle, png_path, 'Resolution', 600, 'BackgroundColor', 'white');
exportgraphics(fig_handle, pdf_path, 'ContentType', 'vector', 'BackgroundColor', 'white');
savefig(fig_handle, fig_path);

% Unit-aware DPI via shared helper (same logic as artifact QC)
info = imfinfo(png_path);
eff_dpi = nrr_effective_png_dpi(info);
assert(eff_dpi >= 280 && eff_dpi <= 700, ...
    'nrr_export_figure: effective DPI %.1f outside [280,700] for %s', eff_dpi, fig_name);

sz = dir(png_path);
assert(sz.bytes > 1000, 'nrr_export_figure: PNG suspiciously small (%d bytes)', sz.bytes);

fprintf('[export] %s | PNG %dx%d @ ~%.0f DPI (%.0f KB) | PDF OK\n', ...
    fig_name, info.Width, info.Height, round(eff_dpi), sz.bytes/1024);
end
