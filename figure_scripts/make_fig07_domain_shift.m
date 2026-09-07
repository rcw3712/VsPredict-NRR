function result = make_fig07_domain_shift(canon_run_folder, data_folder, out_dir)
% MAKE_FIG07_DOMAIN_SHIFT  Fig 7: GR, DT, NPHI, RHOB histograms.
%   Canonical z(DT) = +7.85 (2 decimal), not +7.86.
%   Association language only — no causation claim.

if nargin < 1; canon_run_folder = 'runs/run_20260903_155408'; end
if nargin < 2; data_folder      = 'data'; end
if nargin < 3; out_dir          = 'figures_final'; end

nrr_figure_style();
D = nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

% Load well data
T_A = readtable(fullfile(data_folder,'Well-A.xlsx'),'VariableNamingRule','preserve');
T_B = readtable(fullfile(data_folder,'Well-B.xlsx'),'VariableNamingRule','preserve');
clean_cols = @(T) setfield(T,'Properties','VariableNames',...
    cellfun(@(s) strtok(strtrim(s),' '),T.Properties.VariableNames,'UniformOutput',false));
rawcols_T_A = T_A.Properties.VariableNames;
T_A.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '), rawcols_T_A, 'UniformOutput', false); rawcols_T_B = T_B.Properties.VariableNames;
T_B.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '), rawcols_T_B, 'UniformOutput', false);

% Pop-A mask for Well-B
role_csv = readtable(fullfile(canon_run_folder,'01_data_audit','DATA_ROLE_ROW_IDS.csv'));
isPopA = strcmp(role_csv.ROLE,'Pop-A primary blind') | ...
    strcmp(role_csv.ROLE,'Pop-B diagnostic QC');
popA_ids = role_csv.ROW_ID(isPopA);
T_B.ROW_ID = (1:height(T_B))';
popA_mask  = ismember(T_B.ROW_ID, popA_ids);
assert(height(T_A)==D.nWellA,'FIG07: Well-A row count mismatch');
assert(nnz(popA_mask)==D.nPopA,'FIG07: Pop-A row count mismatch');

tracks  = {'GR','DT','NPHI','RHOB'};
units   = {'API','µs/ft','%','g/cm³'};
sub_lbl = {'(a)','(b)','(c)','(d)'};
c = nrr_colors();

fig = figure('Units','centimeters','Visible','off','Position',[0 0 17.4 12.2], 'Color','white');
tl  = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

for ti = 1:4
    col = tracks{ti};
    vA  = T_A.(col); vA = vA(isfinite(vA));
    vB  = T_B.(col)(popA_mask); vB = vB(isfinite(vB));

    ax = nexttile(tl,ti);
    hold(ax,'on');

    % Shared bin edges
    all_v  = [vA; vB];
    e      = linspace(min(all_v), max(all_v), 26);
    hA = histogram(ax, vA, e, 'FaceColor', c.wellA, 'EdgeColor','white','LineWidth',0.25,'FaceAlpha',0.58,'Normalization','pdf');
    hB = histogram(ax, vB, e, 'FaceColor', c.wellB, 'EdgeColor','white','LineWidth',0.25,'FaceAlpha',0.58,'Normalization','pdf');

    % Mean lines
    lA = xline(ax, mean(vA), '--', 'Color', c.wellA, 'LineWidth',1.25);
    lB = xline(ax, mean(vB), '--', 'Color', c.wellB, 'LineWidth',1.25);
    if ti==1; hLeg=[hA hB lA lB]; end

    % z and KS from canonical CSV
    ds_row = D.ds(strcmp(D.ds.FEATURE, col),:);
    z_val  = ds_row.Z_BA_FULL;
    ks_val = ds_row.KS_STAT;

    % Canonical rounding: DT → 7.85, not 7.86
    z_str  = sprintf('%+.2f', z_val);
    ks_str = sprintf('%.3f', ks_val);

    % Determine annotation color
    if strcmp(col,'DT'); ann_clr=c.ridge; else; ann_clr=[0.2 0.2 0.2]; end
    ann_txt = sprintf('z_{B|A} = %s\nKS = %s\nOOD_{|z|>3} = %.1f%%', ...
        z_str, ks_str, ds_row.OOD_3SG_PCT);

    text(ax, ax.XLim(2)-0.02*(ax.XLim(2)-ax.XLim(1)), ax.YLim(2)*0.95, ann_txt, ...
        'HorizontalAlignment','right','VerticalAlignment','top','FontSize',8,'Color',ann_clr,...
        'BackgroundColor','none');

    xlabel(ax, sprintf('%s (%s)', col, units{ti}), 'FontSize',9);
    ylabel(ax, 'Probability density', 'FontSize',8);
    title(ax, sprintf('%s %s', sub_lbl{ti}, col), 'FontSize',9,'FontWeight','bold');
    grid(ax,'on'); box(ax,'off'); set(ax,'FontSize',8);
end

% Compact key in panel (a); explicit handles prevent legend-order errors.
lg_ax = nexttile(tl,1);
legend(lg_ax,hLeg,...
    sprintf('Well-A calibration (n=%d)',D.nWellA),...
    sprintf('Well-B Pop-A blind (n=%d)',D.nPopA),...
    'Well-A mean','Well-B mean',...
    'Location','southwest','Box','off','FontSize',6.4,'NumColumns',2);

sgtitle('Source–target covariate distributions',...
    'FontSize',9.2,'FontWeight','bold');

nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig, out_dir, 'FIG07_domain_shift');
result = struct('status','PASS','name','FIG07_domain_shift', ...
    'png_path',fullfile(out_dir,'FIG07_domain_shift.png'), ...
    'pdf_path',fullfile(out_dir,'FIG07_domain_shift.pdf'), ...
    'population','Well-A full versus Well-B Pop-A blind', ...
    'n_wellA',D.nWellA,'n_popA',D.nPopA);
close(fig);
end
