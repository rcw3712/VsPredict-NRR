function result = make_fig05_primary_blind_diagnostics(canon_run_folder, out_dir)
% MAKE_FIG05_PRIMARY_BLIND_DIAGNOSTICS  Primary blind Pop-A diagnostics.
% Residual is defined as raw prediction minus measurement.

if nargin < 1
    canon_run_folder = fullfile(nrr_project_root(),'runs','run_20260903_155408');
end
if nargin < 2
    out_dir = fullfile(nrr_project_root(),'figures_final');
end

nrr_figure_style();
D = nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

T = D.blind;
required = {'IS_POPA','VS_measured','VS_pred_raw','DEPTH'};
for k=1:numel(required)
    assert(any(strcmp(T.Properties.VariableNames,required{k})), ...
        'FIG05: missing canonical column %s',required{k});
end

popA = logical(T.IS_POPA);
yt = T.VS_measured(popA);
yp = T.VS_pred_raw(popA);
dep = T.DEPTH(popA);
ok = isfinite(yt) & isfinite(yp) & isfinite(dep);
yt=yt(ok); yp=yp(ok); dep=dep(ok);
res = yp-yt; % predicted minus measured

n = numel(yt);
r2 = 1-sum((yt-yp).^2)/sum((yt-mean(yt)).^2);
rmse = sqrt(mean(res.^2));
bias = mean(res);

assert(n==D.nPopA && n==329,'FIG05: Pop-A row count mismatch');
assert(abs(r2-D.ridgePopAR2)<5e-4,'FIG05: R2 mismatch');
assert(abs(rmse-D.ridgePopARMSE)<5e-4,'FIG05: RMSE mismatch');
assert(abs(bias-D.ridgePopABias)<5e-4,'FIG05: bias mismatch');

c=nrr_colors();
fig=figure('Units','centimeters','Visible','off', ...
    'Position',[0 0 17.4 7.5],'Color','white');
tl=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');

% Shared limits for a true 1:1 comparison
lo=min([yt;yp]); hi=max([yt;yp]); pad=0.045*(hi-lo);
lims=[lo-pad hi+pad];

% Panel a
ax1=nexttile(tl,1);
scatter(ax1,yt,yp,11,c.ridge,'filled','MarkerFaceAlpha',0.48, ...
    'MarkerEdgeColor','none');
hold(ax1,'on');
plot(ax1,lims,lims,'-','Color',[0.12 0.12 0.12],'LineWidth',0.9);
set(ax1,'XLim',lims,'YLim',lims,'FontSize',7.6,'TickDir','out', ...
    'Layer','top','Box','off','XGrid','on','YGrid','on');
axis(ax1,'square');
xlabel(ax1,'Measured V_s (km/s)','FontSize',8.3);
ylabel(ax1,'Predicted V_s (km/s)','FontSize',8.3);
title(ax1,'(a) Measured versus predicted','FontSize',8.8,'FontWeight','bold');
text(ax1,lims(2)-0.025*diff(lims),lims(1)+0.025*diff(lims), ...
    sprintf('R² = %.4f\nRMSE = %.4f km/s\nBias = %+.4f km/s\nn = %d', ...
    r2,rmse,bias,n), ...
    'HorizontalAlignment','right','VerticalAlignment','bottom', ...
    'FontSize',6.6,'Color',c.ridge,'BackgroundColor','white', ...
    'EdgeColor',[0.72 0.72 0.72],'Margin',3,'Interpreter','none');

% Panel b
ax2=nexttile(tl,2);
scatter(ax2,res,dep,9,c.ridge,'filled','MarkerFaceAlpha',0.50, ...
    'MarkerEdgeColor','none');
hold(ax2,'on');
xline(ax2,0,'-','Color',[0.25 0.25 0.25],'LineWidth',0.9);
xline(ax2,bias,'--','Color',c.ridge,'LineWidth',1.0);
xmin=min(res); xmax=max(res); xpad=0.06*(xmax-xmin);
set(ax2,'XLim',[xmin-xpad xmax+xpad],'YDir','reverse', ...
    'FontSize',7.6,'TickDir','out','Layer','top','Box','off', ...
    'XGrid','on','YGrid','on');
xlabel(ax2,'Residual (km/s)','FontSize',8.3);
ylabel(ax2,'Depth (m)','FontSize',8.3);
title(ax2,'(b) Residual versus depth','FontSize',8.8,'FontWeight','bold');
text(ax2,0.03,0.975,'residual = predicted - measured', ...
    'Units','normalized','HorizontalAlignment','left','VerticalAlignment','top', ...
    'FontSize',6.1,'Color',[0.25 0.25 0.25], ...
    'BackgroundColor','white','Margin',1.5,'Interpreter','none');
text(ax2,0.97,0.035,sprintf('mean = %+.4f km/s',bias), ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','bottom', ...
    'FontSize',6.2,'Color',c.ridge,'BackgroundColor','white', ...
    'Margin',1.5,'Interpreter','none');

% Panel c
ax3=nexttile(tl,3);
histogram(ax3,res,25,'FaceColor',c.ridge,'EdgeColor','white', ...
    'LineWidth',0.25,'FaceAlpha',0.78);
hold(ax3,'on');
xline(ax3,0,'-','Color',[0.25 0.25 0.25],'LineWidth',0.9);
xline(ax3,bias,'--','Color',c.ridge,'LineWidth',1.0);
set(ax3,'XLim',[xmin-xpad xmax+xpad],'FontSize',7.6, ...
    'TickDir','out','Layer','top','Box','off','XGrid','on','YGrid','on');
xlabel(ax3,'Residual (km/s)','FontSize',8.3);
ylabel(ax3,'Count','FontSize',8.3);
title(ax3,'(c) Residual distribution','FontSize',8.8,'FontWeight','bold');
text(ax3,0.97,0.955,sprintf('mean = %+.4f km/s',bias), ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
    'FontSize',6.2,'Color',c.ridge,'BackgroundColor','white', ...
    'Margin',1.5,'Interpreter','none');

nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig,out_dir,'FIG05_primary_blind_diagnostics');

result=struct('status',"PASS",'name',"FIG05_primary_blind_diagnostics", ...
    'png_path',fullfile(out_dir,'FIG05_primary_blind_diagnostics.png'), ...
    'pdf_path',fullfile(out_dir,'FIG05_primary_blind_diagnostics.pdf'), ...
    'population',"Pop-A primary blind",'prediction',"VS_pred_raw", ...
    'residual_definition',"predicted - measured", ...
    'n',n,'r2',r2,'rmse',rmse,'bias',bias);
close(fig);
end
