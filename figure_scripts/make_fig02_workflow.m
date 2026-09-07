function result = make_fig02_workflow(canon_run_folder, out_dir)
% MAKE_FIG02_WORKFLOW  Corrected v5 workflow for NRR.
% Data roles, model development, and external evaluation are separated.
% Well-B is never used for fitting or model selection.

if nargin < 1
    canon_run_folder = fullfile(nrr_project_root(),'runs','run_20260903_155408');
end
if nargin < 2
    out_dir = fullfile(nrr_project_root(),'figures_final');
end

nrr_figure_style();
D = nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

assert(D.nWellA == 492 && D.nDev == 392 && D.nHoldout == 100);
assert(D.nWellB == 492 && D.nShared == 163 && D.nPopA == 329 && D.nPopB == 236);
assert(D.nWellB-D.nShared == D.nPopA);
assert(D.nPopA-D.nPopB == 93);

fig = figure('Units','centimeters','Position',[0 0 18 11.5], ...
    'Visible','off','Color','white');
ax = axes(fig,'Position',[0.015 0.045 0.97 0.925], ...
    'Visible','off','XLim',[0 1],'YLim',[0 1]);
hold(ax,'on');

blueFill  = [0.89 0.94 0.99];
greenFill = [0.90 0.97 0.90];
redFill   = [0.99 0.92 0.90];
grayFill  = [0.94 0.94 0.96];
passFill  = [0.88 0.97 0.88];
edge      = [0.48 0.51 0.54];
dark      = [0.10 0.10 0.10];
blue      = [0.08 0.24 0.56];
green     = [0.05 0.38 0.10];
red       = [0.55 0.10 0.08];
arrowCol  = [0.35 0.35 0.35];

% Lane geometry
x1=0.015; w1=0.315;
x2=0.365; w2=0.270;
x3=0.670; w3=0.315;

lane_header(x1,w1,'DATA ROLES',blue);
lane_header(x2,w2,'MODEL DEVELOPMENT',green);
lane_header(x3,w3,'EXTERNAL EVALUATION',red);

% DATA ROLES: two independent wells
subgap=0.012; sw=(w1-subgap)/2;
boxc(x1,0.825,sw,0.085,{'Well-A','n = 492'},blueFill,dark,7.4,false);
boxc(x1,0.690,sw,0.085,{'Development','n = 392','model input'},blueFill,dark,7.0,true);
boxc(x1,0.555,sw,0.080,{'Historical holdout','n = 100','provenance only'},grayFill,[0.30 0.30 0.42],6.5,false);
arrow_down(x1+sw/2,0.825,0.775);
arrow_down(x1+sw/2,0.690,0.635);

xb=x1+sw+subgap;
boxc(xb,0.825,sw,0.085,{'Well-B blind','n = 492'},blueFill,dark,7.4,false);
boxc(xb,0.690,sw,0.085,{'Shared-depth audit','exclude 163'},redFill,red,6.8,false);
boxc(xb,0.555,sw,0.085,{'Pop-A primary blind','n = 329'},blueFill,dark,6.8,true);
boxc(xb,0.420,sw,0.085,{'Vp/Vs QC','exclude 93'},redFill,red,6.8,false);
boxc(xb,0.285,sw,0.085,{'Pop-B diagnostic','n = 236','target-informed'},blueFill,dark,6.6,false);
arrow_down(xb+sw/2,0.825,0.775);
arrow_down(xb+sw/2,0.690,0.640);
arrow_down(xb+sw/2,0.555,0.505);
arrow_down(xb+sw/2,0.420,0.370);

% MODEL DEVELOPMENT: Well-A development only
boxc(x2,0.825,w2,0.075,{'Input: Well-A development (n = 392)','Well-B outcomes unavailable'},greenFill,green,6.9,true);
boxc(x2,0.715,w2,0.075,{'5 contiguous outer depth folds'},greenFill,dark,7.0,false);
boxc(x2,0.605,w2,0.075,{'4 inner folds rebuilt','inside each outer-training set'},greenFill,dark,6.6,false);
boxc(x2,0.495,w2,0.075,{'Fold-local preprocessing'},greenFill,dark,7.0,false);
boxc(x2,0.385,w2,0.075,{'PNN | MLFFNN | DFFNN | CNN1D'},greenFill,dark,6.4,false);
boxc(x2,0.275,w2,0.075,{'Inner OOF meta-features','and meta-feature scaling'},greenFill,dark,6.5,false);
boxc(x2,0.165,w2,0.075,{'Ridge stacker','λ = 0.001'},greenFill,dark,6.9,true);
boxc(x2,0.050,w2,0.082, ...
    {sprintf('Nested CV: R² = %.4f',D.cvPooledR2), ...
     sprintf('RMSE = %.4f km/s',D.cvPooledRMSE)},passFill,green,7.0,true);
for yy=[0.825 0.715 0.605 0.495 0.385 0.275 0.165]
    arrow_down(x2+w2/2,yy,yy-0.035);
end

% EXTERNAL EVALUATION: frozen primary pipeline
boxc(x3,0.825,w3,0.075,{'Frozen Ridge-stacker pipeline','no Well-B refitting'},redFill,red,7.0,true);
boxc(x3,0.705,w3,0.092, ...
    {'Primary blind evaluation — Pop-A', ...
     sprintf('n = %d | R² = %.4f | RMSE = %.4f km/s', ...
     D.nPopA,D.ridgePopAR2,D.ridgePopARMSE)},redFill,red,6.7,true);
boxc(x3,0.575,w3,0.092, ...
    {'Diagnostic evaluation — Pop-B', ...
     sprintf('n = %d | R² = %.4f | RMSE = %.4f km/s', ...
     D.nPopB,D.ridgePopBR2,D.ridgePopBRMSE)},redFill,red,6.7,false);
boxc(x3,0.455,w3,0.082, ...
    {'Domain shift',sprintf('DT: z = +7.85 | KS = 1.000')},redFill,red,6.8,false);
boxc(x3,0.335,w3,0.082, ...
    {'Geomechanical ALL_OK',sprintf('Ridge: 0/%d | Direct Ridge*: %d/%d', ...
    D.nPopB,D.nPopB,D.nPopB)},redFill,red,6.6,false);
boxc(x3,0.215,w3,0.082, ...
    {sprintf('Gate 18: %d/%d checks PASS',D.gate18_pass,D.gate18_total), ...
     'two clean-session runs'},passFill,green,7.0,true);
boxc(x3,0.075,w3,0.095, ...
    {'* Direct Ridge','post-hoc sensitivity only','not used for primary selection'},grayFill,[0.25 0.33 0.43],6.5,false);
for yy=[0.825 0.705 0.575 0.455 0.335]
    arrow_down(x3+w3/2,yy,yy-0.035);
end

% Cross-lane arrows show permitted information flow only.

arrow_right(x2+w2,0.862,x3,0.862);
text(ax,0.652,0.885,'freeze','HorizontalAlignment','center', ...
    'FontSize',6.0,'Color',arrowCol,'Interpreter','none');

xlim(ax,[0 1]); ylim(ax,[0 1]);
nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig,out_dir,'FIG02_workflow');

result = struct('status',"PASS",'name',"FIG02_workflow", ...
    'png_path',fullfile(out_dir,'FIG02_workflow.png'), ...
    'pdf_path',fullfile(out_dir,'FIG02_workflow.pdf'), ...
    'n_wellA',D.nWellA,'n_dev',D.nDev,'n_holdout',D.nHoldout, ...
    'n_wellB',D.nWellB,'n_shared',D.nShared,'n_popA',D.nPopA,'n_popB',D.nPopB);
close(fig);

    function lane_header(x,w,label,color)
        text(ax,x+w/2,0.965,label,'HorizontalAlignment','center', ...
            'VerticalAlignment','middle','FontSize',8.2,'FontWeight','bold', ...
            'Color',color,'Interpreter','none','FontName','Helvetica');
        line(ax,[x x+w],[0.935 0.935],'Color',color,'LineWidth',1.0);
    end

    function boxc(x,y,w,h,lines,face,fg,fs,bold)
        rectangle(ax,'Position',[x y w h],'FaceColor',face,'EdgeColor',edge, ...
            'LineWidth',0.55,'Curvature',0.045);
        fw='normal'; if bold; fw='bold'; end
        text(ax,x+w/2,y+h/2,strjoin(lines,newline), ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontSize',fs,'FontWeight',fw,'Color',fg,'Interpreter','none', ...
            'FontName','Helvetica','Clipping','on');
    end

    function arrow_down(x,yTop,yBottom)
        quiver(ax,x,yTop,x*0,yBottom-yTop,0,'Color',arrowCol, ...
            'LineWidth',0.65,'MaxHeadSize',1.6,'AutoScale','off');
    end

    function arrow_right(xStart,y,xEnd,~)
        quiver(ax,xStart,y,xEnd-xStart,0,0,'Color',arrowCol, ...
            'LineWidth',0.75,'MaxHeadSize',1.6,'AutoScale','off');
    end
end
