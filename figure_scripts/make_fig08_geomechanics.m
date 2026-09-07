function result = make_fig08_geomechanics(canon_run_folder, data_folder, out_dir)
% MAKE_FIG08_GEOMECHANICS  Fig 8: (a) Vp/Vs profile, (b) per-gate grouped bars.
%   FIXED: nrr_clean_string_column for safe column access, correct gate counts.
%   Assert Ridge=[0,0,187,236,187,0]; Direct=[236,236,236,236,236,236].

if nargin < 1; canon_run_folder = fullfile(nrr_project_root(),'runs','run_20260903_155408'); end
if nargin < 2; data_folder      = fullfile(nrr_project_root(),'data'); end
if nargin < 3; out_dir          = fullfile(nrr_project_root(),'figures_final'); end

nrr_figure_style();
D = nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

% Load per-row geomechanics
ridge_path = fullfile(canon_run_folder,'07_geomech','GEOMECH_ROW_LEVEL_RIDGE_STACKER.csv');
dr_path    = fullfile(canon_run_folder,'07_geomech','GEOMECH_ROW_LEVEL_DIRECT_RIDGE.csv');
assert(isfile(ridge_path), 'Ridge geomech file not found: %s', ridge_path);
assert(isfile(dr_path),    'DR geomech file not found: %s',    dr_path);

T_r  = readtable(ridge_path);
T_dr = readtable(dr_path);
assert(height(T_r)==D.nPopB && height(T_dr)==D.nPopB,'FIG08: row-level count mismatch');
assert(isequal(T_r.ROW_ID,T_dr.ROW_ID),'FIG08: Ridge/Direct Ridge ROW_ID mismatch');
assert(max(abs(T_r.DEPTH-T_dr.DEPTH))<1e-9,'FIG08: Ridge/Direct Ridge depth mismatch');

% Gate counts from canonical comparison CSV
gr = D.geo_ridge;
gd = D.geo_dr;
N  = D.nPopB;  % 236

% Verify correct gate columns exist and read values
ridge_gates = [gr.N_VPVS_OK, gr.N_NU_OK, gr.N_E_OK, gr.N_G_OK, gr.N_K_OK, gr.N_ALL_OK];
dr_gates    = [gd.N_VPVS_OK, gd.N_NU_OK, gd.N_E_OK, gd.N_G_OK, gd.N_K_OK, gd.N_ALL_OK];

% Assertions
assert(isequal(ridge_gates, [0,0,187,236,187,0]), ...
    'Ridge gate counts mismatch: %s', mat2str(ridge_gates));
assert(all(dr_gates == 236), ...
    'DR gate counts not all 236: %s', mat2str(dr_gates));

gate_labels = {'Vp/Vs','Poisson ratio','Young mod. E','Shear mod. G','Bulk mod. K','ALL-OK'};

c = nrr_colors();
fig = figure('Units','centimeters','Position',[0 0 17.4 9.3],'Visible','off','Color','white');
tl  = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

% ── Panel (a): Vp/Vs depth profile ─────────────────────────────────────────
ax1 = nexttile(tl,1);
hold(ax1,'on');

% Use VPVS column from row-level tables
if ismember('VPVS',T_r.Properties.VariableNames) && ismember('DEPTH',T_r.Properties.VariableNames)
    ok_r = isfinite(T_r.VPVS) & isfinite(T_r.DEPTH);
    hR_vpvs = plot(ax1, T_r.VPVS(ok_r), T_r.DEPTH(ok_r), 'Color',c.ridge,'LineWidth',0.9,...
        'DisplayName','Ridge stacker (primary)');
end
if ismember('VPVS',T_dr.Properties.VariableNames) && ismember('DEPTH',T_dr.Properties.VariableNames)
    ok_d = isfinite(T_dr.VPVS) & isfinite(T_dr.DEPTH);
    hD_vpvs = plot(ax1, T_dr.VPVS(ok_d), T_dr.DEPTH(ok_d), 'Color',c.dr,'LineWidth',0.9,...
        'DisplayName','Direct Ridge (post-hoc)');
end
hl = xline(ax1, sqrt(2), '-k', 'LineWidth',1.2, 'HandleVisibility','off');
text(ax1, sqrt(2)+0.015, mean(ax1.YLim), 'Vp/Vs = sqrt(2)',...
    'FontSize',7,'Interpreter','none','Color','k','Rotation',90,'VerticalAlignment','bottom');
set(ax1,'YDir','reverse','FontSize',8);
xlabel(ax1,'Vp / Vs','FontSize',9);
ylabel(ax1,'Depth (m)','FontSize',9);
title(ax1,sprintf('(a) Vp/Vs profiles — Pop-B (n=%d)',N),...
    'FontSize',9,'FontWeight','bold','Interpreter','none');
if exist('hR_vpvs','var') && exist('hD_vpvs','var')
    legend(ax1,[hR_vpvs,hD_vpvs],'Ridge stacker (primary)','Direct Ridge (post-hoc)',...
        'Location','south','FontSize',6.5,'Box','off');
end
grid(ax1,'on');

% ── Panel (b): Per-gate pass rates ─────────────────────────────────────────
ax2 = nexttile(tl,2);
hold(ax2,'on');
Y = [ridge_gates(:), dr_gates(:)]/N*100;
bh = barh(ax2,1:6,Y,'grouped','BarWidth',0.78);
bh(1).FaceColor=c.ridge; bh(1).EdgeColor='none';
bh(2).FaceColor=c.dr;    bh(2).EdgeColor='none';

% Exact counts with explicit grouped-bar y positions.
counts=[ridge_gates(:),dr_gates(:)];
yoff=[-0.14,0.14];
for i=1:6
    for j=1:2
        xv=Y(i,j); yv=i+yoff(j);
        if xv==0
            xt=1.5; clr=bh(j).FaceColor; ha='left';
        else
            xt=xv-1.5; clr=[1 1 1]; ha='right';
        end
        text(ax2,xt,yv,sprintf('%d/%d',counts(i,j),N), ...
            'HorizontalAlignment',ha,'VerticalAlignment','middle', ...
            'FontSize',6.1,'Color',clr,'FontWeight','bold');
    end
end

set(ax2,'YTick',1:6,'YTickLabel',gate_labels,'YDir','reverse', ...
    'XLim',[0 112],'XTick',0:20:100,'FontSize',7.3, ...
    'TickDir','out','Layer','top','Box','off');
xlabel(ax2,'Pass rate (%)','FontSize',8.5);
title(ax2,'(b) Physical-admissibility gates — Pop-B', ...
    'FontSize',8.8,'FontWeight','bold','Interpreter','none');
text(ax2,.98,.985,'Orange: primary Ridge stacker  |  Blue: Direct Ridge*', ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
    'FontSize',6.0,'Color',[0.20 0.20 0.20], ...
    'BackgroundColor','white','Margin',1.1);
text(ax2,.98,.94,'* post-hoc sensitivity only', ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
    'FontSize',6.0,'FontAngle','italic','Color',c.dr, ...
    'BackgroundColor','white','Margin',1.0);
grid(ax2,'on');

nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig, out_dir, 'FIG08_geomechanics');
result = struct('status','PASS','name','FIG08_geomechanics', ...
    'png_path',fullfile(out_dir,'FIG08_geomechanics.png'), ...
    'pdf_path',fullfile(out_dir,'FIG08_geomechanics.pdf'), ...
    'population','Pop-B diagnostic','n_eval',N, ...
    'ridge_gate_counts',ridge_gates,'direct_ridge_gate_counts',dr_gates);
close(fig);
end
