function nrr_figure_style()
% NRR_FIGURE_STYLE  Apply global publication-ready style for NRR figures.
set(groot, 'DefaultAxesFontName',    'Helvetica');
set(groot, 'DefaultTextFontName',    'Helvetica');
set(groot, 'DefaultAxesFontSize',    10);
set(groot, 'DefaultTextFontSize',    10);
set(groot, 'DefaultLineLineWidth',   1.0);
set(groot, 'DefaultAxesLineWidth',   0.75);
set(groot, 'DefaultAxesBox',         'off');
set(groot, 'DefaultAxesTickDir',     'out');
set(groot, 'DefaultFigureColor',     'white');
set(groot, 'DefaultAxesColor',       'white');
set(groot, 'DefaultAxesXColor',      [0.2 0.2 0.2]);
set(groot, 'DefaultAxesYColor',      [0.2 0.2 0.2]);
set(groot, 'DefaultAxesGridColor',   [0.85 0.85 0.85]);
set(groot, 'DefaultAxesGridAlpha',   0.8);
end
