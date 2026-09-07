function result = make_fig06_ridge_vs_directridge(canon_run_folder, out_dir)
% MAKE_FIG06_RIDGE_VS_DIRECTRIDGE  Primary versus post-hoc sensitivity.
% Row-level comparison uses Pop-B because both frozen prediction vectors are
% available for exactly the same 236 rows. Aggregate R2 is shown for Pop-A
% and Pop-B without implying confirmatory selection of Direct Ridge.

if nargin < 1
    canon_run_folder=fullfile(nrr_project_root(),'runs','run_20260903_155408');
end
if nargin < 2
    out_dir=fullfile(nrr_project_root(),'figures_final');
end

nrr_figure_style();
D=nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

T=D.blind;
assert(all(ismember({'ROW_ID','VS_measured','IS_POPB'},T.Properties.VariableNames)));
TB=T(logical(T.IS_POPB),:);
assert(height(TB)==D.nPopB && D.nPopB==236,'FIG06: Pop-B count mismatch');

geo_dir=fullfile(canon_run_folder,'07_geomech');
Tr=readtable(fullfile(geo_dir,'GEOMECH_ROW_LEVEL_RIDGE_STACKER.csv'));
Td=readtable(fullfile(geo_dir,'GEOMECH_ROW_LEVEL_DIRECT_RIDGE.csv'));
assert(all(ismember({'ROW_ID','VS_PRED_KM'},Tr.Properties.VariableNames)));
assert(all(ismember({'ROW_ID','VS_PRED_KM'},Td.Properties.VariableNames)));

[tfR,locR]=ismember(TB.ROW_ID,Tr.ROW_ID);
[tfD,locD]=ismember(TB.ROW_ID,Td.ROW_ID);
assert(all(tfR)&&all(tfD),'FIG06: row-level predictions do not cover Pop-B');
assert(numel(unique(Tr.ROW_ID))==236 && numel(unique(Td.ROW_ID))==236, ...
    'FIG06: prediction ROW_ID must be unique');

yt=TB.VS_measured;
ypR=Tr.VS_PRED_KM(locR);
ypD=Td.VS_PRED_KM(locD);
ok=isfinite(yt)&isfinite(ypR)&isfinite(ypD);
yt=yt(ok); ypR=ypR(ok); ypD=ypD(ok);
assert(numel(yt)==236,'FIG06: finite paired sample count mismatch');

metric=@(y,p) [1-sum((y-p).^2)/sum((y-mean(y)).^2), ...
    sqrt(mean((p-y).^2)),mean(p-y)];
mR=metric(yt,ypR);
mD=metric(yt,ypD);
assert(abs(mR(1)-D.ridgePopBR2)<5e-4 && ...
       abs(mR(2)-D.ridgePopBRMSE)<5e-4 && ...
       abs(mR(3)-D.ridgePopBBias)<5e-4,'FIG06: Ridge Pop-B metrics mismatch');
assert(abs(mD(1)-D.directPopBR2)<5e-4 && ...
       abs(mD(2)-D.directPopBRMSE)<5e-4 && ...
       abs(mD(3)-D.directPopBBias)<5e-4,'FIG06: Direct Ridge Pop-B metrics mismatch');

c=nrr_colors();
fig=figure('Units','centimeters','Position',[0 0 17.4 8.4], ...
    'Visible','off','Color','white');
tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

% Panel a: paired Pop-B scatter
ax1=nexttile(tl,1);
lo=min([yt;ypR;ypD]); hi=max([yt;ypR;ypD]); pad=.04*(hi-lo);
lims=[lo-pad hi+pad];
sR=scatter(ax1,yt,ypR,10,c.ridge,'filled','MarkerFaceAlpha',.42, ...
    'MarkerEdgeColor','none','DisplayName','Ridge stacker — primary');
hold(ax1,'on');
sD=scatter(ax1,yt,ypD,10,c.dr,'filled','MarkerFaceAlpha',.48, ...
    'MarkerEdgeColor','none','DisplayName','Direct Ridge — post-hoc');
plot(ax1,lims,lims,'-','Color',[.12 .12 .12],'LineWidth',.9, ...
    'HandleVisibility','off');
set(ax1,'XLim',lims,'YLim',lims,'FontSize',7.6,'TickDir','out', ...
    'Layer','top','Box','off','XGrid','on','YGrid','on');
axis(ax1,'square');
xlabel(ax1,'Measured V_s (km/s)','FontSize',8.3);
ylabel(ax1,'Predicted V_s (km/s)','FontSize',8.3);
title(ax1,'(a) Paired predictions on Pop-B (n = 236)', ...
    'FontSize',8.8,'FontWeight','bold');

% Metric boxes occupy opposite empty corners.
text(ax1,.03,.97,sprintf('Primary Ridge stacker\nR² = %.4f\nRMSE = %.4f km/s\nBias = %+.4f km/s',mR), ...
    'Units','normalized','HorizontalAlignment','left','VerticalAlignment','top', ...
    'FontSize',6.2,'Color',c.ridge,'BackgroundColor','white', ...
    'EdgeColor',[.70 .70 .70],'Margin',2.4,'Interpreter','none');
text(ax1,.97,.04,sprintf('Direct Ridge*\nR² = %.4f\nRMSE = %.4f km/s\nBias = %+.4f km/s',mD), ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','bottom', ...
    'FontSize',6.2,'Color',c.dr,'BackgroundColor','white', ...
    'EdgeColor',[.70 .70 .70],'Margin',2.4,'Interpreter','none');

% Panel b: aggregate R2 across both declared populations
ax2=nexttile(tl,2);
Y=[D.ridgePopAR2 D.directPopAR2; D.ridgePopBR2 D.directPopBR2];
b=bar(ax2,1:2,Y,'grouped','BarWidth',.72);
b(1).FaceColor=c.ridge; b(1).EdgeColor=[.40 .18 .04]; b(1).LineWidth=.4;
b(2).FaceColor=c.dr; b(2).EdgeColor=[.12 .25 .36]; b(2).LineWidth=.4;
hold(ax2,'on');
yline(ax2,0,'-','Color',[.25 .25 .25],'LineWidth',1.0,'HandleVisibility','off');
drawnow;
for j=1:2
    xx=b(j).XEndPoints;
    vals=Y(:,j);
    for i=1:2
        if vals(i)<0
            yy=vals(i)-.12; va='top';
        else
            yy=vals(i)+.08; va='bottom';
        end
        text(ax2,xx(i),yy,sprintf('%.4f',vals(i)), ...
            'HorizontalAlignment','center','VerticalAlignment',va, ...
            'FontSize',6.7,'FontWeight','bold','Color',[.12 .12 .12], ...
            'Interpreter','none');
    end
end
set(ax2,'XTick',1:2,'XTickLabel',{'Pop-A primary blind','Pop-B diagnostic'}, ...
    'XLim',[.45 2.55],'YLim',[-5.75 1.0],'FontSize',7.5, ...
    'TickDir','out','Layer','top','Box','off','XGrid','off','YGrid','on');
ylabel(ax2,'R²','FontSize',8.5);
title(ax2,'(b) Frozen aggregate performance', ...
    'FontSize',8.8,'FontWeight','bold');
text(ax2,.98,.96,'Orange: primary Ridge stacker  |  Blue: Direct Ridge*', ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
    'FontSize',6.2,'Color',[0.20 0.20 0.20], ...
    'BackgroundColor','white','Margin',1.5,'Interpreter','none');
text(ax2,.98,.905,'* post-hoc sensitivity only', ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
    'FontSize',6.2,'FontAngle','italic','Color',c.dr, ...
    'BackgroundColor','white','Margin',1.2,'Interpreter','none');

nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig,out_dir,'FIG06_ridge_vs_directridge');

result=struct('status',"PASS",'name',"FIG06_ridge_vs_directridge", ...
    'png_path',fullfile(out_dir,'FIG06_ridge_vs_directridge.png'), ...
    'pdf_path',fullfile(out_dir,'FIG06_ridge_vs_directridge.pdf'), ...
    'row_level_population',"Pop-B diagnostic",'n_paired',numel(yt), ...
    'ridge_popB',[mR(1) mR(2) mR(3)], ...
    'direct_popB',[mD(1) mD(2) mD(3)], ...
    'aggregate_r2',Y);
close(fig);
end
