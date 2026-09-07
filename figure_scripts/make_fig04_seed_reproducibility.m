function result = make_fig04_seed_reproducibility(canon_run_folder, out_dir)
% MAKE_FIG04_SEED_REPRODUCIBILITY  Exact-pipeline seed sensitivity and Gate 18.
% All values are read from frozen canonical artifacts.

if nargin < 1
    canon_run_folder = fullfile(nrr_project_root(),'runs','run_20260903_155408');
end
if nargin < 2
    out_dir = fullfile(nrr_project_root(),'figures_final');
end

nrr_figure_style();
D = nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

T = D.mseed;
required = {'SEED','R2_POPA','R2_POPB','N_POPA','N_POPB'};
for k=1:numel(required)
    assert(any(strcmpi(T.Properties.VariableNames,required{k})), ...
        'FIG04: missing canonical column %s',required{k});
end
v = @(name) T.Properties.VariableNames{strcmpi(T.Properties.VariableNames,name)};
T = sortrows(T,v('SEED'));
seeds = T.(v('SEED'));
r2A = T.(v('R2_POPA'));
r2B = T.(v('R2_POPB'));
nA = T.(v('N_POPA'));
nB = T.(v('N_POPB'));

assert(isequal(seeds(:),[7;42;123]),'FIG04: unexpected seed set');
assert(all(nA==D.nPopA) && all(nB==D.nPopB),'FIG04: population size mismatch');
assert(max(abs(r2A-[-1.00959740468013;-2.61615387472984;-2.55123885839220]))<1e-10);
assert(max(abs(r2B-[-2.61389806558620;-5.27084955040772;-5.22147110332360]))<1e-10);
assert(D.gate18_pass==44 && D.gate18_total==44);
assert(all(strcmp(string(D.gate18_csv.STATUS),"PASS")), ...
    'FIG04: every Gate 18 check must pass');

run1 = string(D.gate18_csv.RUN_1(1));
run2 = string(D.gate18_csv.RUN_2(1));
assert(strlength(run1)>0 && strlength(run2)>0,'FIG04: missing run IDs');

c = nrr_colors();
fig = figure('Units','centimeters','Position',[0 0 17.4 8.8], ...
    'Visible','off','Color','white');
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

% Panel a
ax1 = nexttile(tl,1);
hold(ax1,'on');
% Subtle canonical-seed band, drawn before bars.
patch(ax1,[1.55 2.45 2.45 1.55],[-5.65 -5.65 0.28 0.28], ...
    [0.94 0.94 0.94],'EdgeColor','none','HandleVisibility','off');
x = (1:3)';
Y = [r2A r2B];
b = bar(ax1,x,Y,'grouped','BarWidth',0.72);
b(1).FaceColor=c.wellA; b(1).EdgeColor=[0.12 0.25 0.36]; b(1).LineWidth=0.4;
b(2).FaceColor=c.ridge; b(2).EdgeColor=[0.40 0.18 0.04]; b(2).LineWidth=0.4;
yline(ax1,0,'-','Color',[0.25 0.25 0.25],'LineWidth',1.0, ...
    'HandleVisibility','off');

drawnow;
for j=1:2
    xend=b(j).XEndPoints;
    vals=Y(:,j);
    for i=1:numel(vals)
        text(ax1,xend(i),vals(i)-0.08,sprintf('%.4f',vals(i)), ...
            'HorizontalAlignment','center','VerticalAlignment','top', ...
            'FontSize',6.7,'FontWeight','bold','Color',[0.12 0.12 0.12], ...
            'Interpreter','none');
    end
end
text(ax1,2,0.16,'canonical seed', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',6.8,'FontAngle','italic','Color',[0.25 0.25 0.25], ...
    'Interpreter','none');

set(ax1,'XTick',x,'XTickLabel',compose('Seed %d',seeds), ...
    'XLim',[0.45 3.55],'YLim',[-5.65 0.32],'FontSize',7.8, ...
    'TickDir','out','Layer','top','Box','off','XGrid','off','YGrid','on');
ylabel(ax1,'R²','FontSize',8.8);
xlabel(ax1,'Random seed','FontSize',8.8);
title(ax1,'(a) Exact-pipeline seed sensitivity', ...
    'FontSize',9,'FontWeight','bold','Interpreter','none');

% Panel b
ax2 = nexttile(tl,2);
axis(ax2,'off'); hold(ax2,'on'); xlim(ax2,[0 1]); ylim(ax2,[0 1]);
rectangle(ax2,'Position',[0.08 0.18 0.84 0.68], ...
    'FaceColor',[0.91 0.98 0.91],'EdgeColor',[0.08 0.47 0.10], ...
    'LineWidth',1.7,'Curvature',0.06);
text(ax2,0.50,0.73,sprintf('%d/%d',D.gate18_pass,D.gate18_total), ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',23,'FontWeight','bold','Color',[0.04 0.40 0.06], ...
    'Interpreter','none');
text(ax2,0.50,0.59,'predefined checks passed', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',8.2,'FontWeight','bold','Color',[0.12 0.12 0.12], ...
    'Interpreter','none');
text(ax2,0.50,0.45,char(run1), ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',6.8,'FontName','Courier New','Color',[0.30 0.30 0.30], ...
    'Interpreter','none');
text(ax2,0.50,0.38,'versus', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',6.2,'Color',[0.42 0.42 0.42],'Interpreter','none');
text(ax2,0.50,0.31,char(run2), ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',6.8,'FontName','Courier New','Color',[0.30 0.30 0.30], ...
    'Interpreter','none');
text(ax2,0.50,0.23,'two independent clean-session runs', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontSize',6.5,'Color',[0.36 0.36 0.36],'Interpreter','none');
title(ax2,'(b) Gate 18 cross-run reproducibility', ...
    'FontSize',9,'FontWeight','bold','Interpreter','none');

lg=legend(ax1,b,{'Pop-A primary','Pop-B diagnostic'}, ...
    'Orientation','horizontal','Box','off','FontSize',7.6);
lg.Layout.Tile='south';

nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig,out_dir,'FIG04_seed_reproducibility');

result = struct('status',"PASS",'name',"FIG04_seed_reproducibility", ...
    'png_path',fullfile(out_dir,'FIG04_seed_reproducibility.png'), ...
    'pdf_path',fullfile(out_dir,'FIG04_seed_reproducibility.pdf'), ...
    'seeds',seeds(:)','r2_popA',r2A(:)','r2_popB',r2B(:)', ...
    'gate18_pass',D.gate18_pass,'gate18_total',D.gate18_total, ...
    'run_1',run1,'run_2',run2);
close(fig);
end
