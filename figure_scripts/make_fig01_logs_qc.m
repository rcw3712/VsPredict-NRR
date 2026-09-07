function result = make_fig01_logs_qc(canon_run_folder, data_folder, out_dir)
% MAKE_FIG01_LOGS_QC  Fig 1: Conventional well logs and QC overview.
%   Corrected terminology: 'shared-depth coordinates' not 'duplicates'.
%   'development / historical-holdout boundary' not 'train/test'.

if nargin < 1; canon_run_folder = 'runs/run_20260903_155408'; end
if nargin < 2; data_folder      = 'data'; end
if nargin < 3; out_dir          = 'figures_final'; end

nrr_figure_style();
D = nrr_load_canonical(canon_run_folder);
nrr_assert_canonical(D);

%% Load raw well data
T_A = readtable(fullfile(data_folder, 'Well-A.xlsx'), 'VariableNamingRule', 'preserve');
T_B = readtable(fullfile(data_folder, 'Well-B.xlsx'), 'VariableNamingRule', 'preserve');

% Normalize column names (strip unit suffixes)
rawcols_T_A = T_A.Properties.VariableNames;
T_A.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '), rawcols_T_A, 'UniformOutput', false); rawcols_T_B = T_B.Properties.VariableNames;
T_B.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '), rawcols_T_B, 'UniformOutput', false);
T_A = sortrows(T_A, 'DEPTH'); T_B = sortrows(T_B, 'DEPTH');

% VS/VP derivation
if ~ismember('VS',T_A.Properties.VariableNames) && ismember('DTS',T_A.Properties.VariableNames)
    T_A.VS = 304.8 ./ T_A.DTS; T_B.VS = 304.8 ./ T_B.DTS;
end

% Load role masks
role_csv = readtable(fullfile(canon_run_folder,'01_data_audit','DATA_ROLE_ROW_IDS.csv'));
dev_ids  = role_csv.ROW_ID(strcmp(role_csv.ROLE,'Well-A development'));
hold_ids = role_csv.ROW_ID(strcmp(role_csv.ROLE,'Well-A holdout'));
popA_only_ids = role_csv.ROW_ID(strcmp(role_csv.ROLE,'Pop-A primary blind'));
popB_ids = role_csv.ROW_ID(contains(role_csv.ROLE,'Pop-B'));
popA_ids = unique([popA_only_ids; popB_ids]);
dup_ids  = role_csv.ROW_ID(strcmp(role_csv.ROLE,'Well-B duplicate'));

assert(numel(unique(dev_ids)) == D.nDev, 'FIG01: development mask mismatch');
assert(numel(unique(hold_ids)) == D.nHoldout, 'FIG01: holdout mask mismatch');
assert(numel(unique(dup_ids)) == D.nShared, 'FIG01: shared-depth mask mismatch');
assert(numel(unique(popA_ids)) == D.nPopA, 'FIG01: Pop-A must contain 329 rows');
assert(numel(unique(popB_ids)) == D.nPopB, 'FIG01: Pop-B must contain 236 rows');

T_A.ROW_ID = (1:height(T_A))';
T_B.ROW_ID = (1:height(T_B))';

c = nrr_colors();
tracks = {'GR','DT','NPHI','RHOB','VS'};
units  = {'API','µs/ft','%','g/cm³','km/s'};

fig = figure('Units','centimeters','Visible','off','Position',[0 0 18 22]);
tl = tiledlayout(2,5,'TileSpacing','compact','Padding','compact');

for row = 1:2
    if row == 1; T = T_A; well_lbl = '(a) Well-A';
    else;        T = T_B; well_lbl = '(b) Well-B (blind)'; end

    for ci = 1:5
        col = tracks{ci};
        if ~ismember(col, T.Properties.VariableNames); continue; end
        ax = nexttile(tl, (row-1)*5+ci);
        hold(ax,'on');

        dep = T.DEPTH; val = T.(col);
        ok  = isfinite(dep) & isfinite(val);

        if row == 1
            % Well-A: plot full, then colour holdout differently
            is_hold = ismember(T.ROW_ID, hold_ids);
            plot(ax, val(ok&~is_hold), dep(ok&~is_hold), 'Color', c.wellA, 'LineWidth', 0.8);
            if any(is_hold & ok)
                plot(ax, val(ok&is_hold), dep(ok&is_hold), 'Color', [0.5 0.5 0.9], 'LineWidth', 0.8);
            end
            % development/historical-holdout boundary
            boundary_d = T.DEPTH(find(is_hold,1,'first'));
            if ~isempty(boundary_d)
                yline(ax, boundary_d, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8);
            end
        else
            % Well-B: colour by category
            is_dup  = ismember(T.ROW_ID, dup_ids);
            is_popA = ismember(T.ROW_ID, popA_ids);
            is_popB = ismember(T.ROW_ID, popB_ids);
            if any(is_popA & ok)
                plot(ax, val(ok&is_popA), dep(ok&is_popA), 'Color', c.wellB, 'LineWidth', 0.8);
            end
            if any(is_dup & ok)
                plot(ax, val(ok&is_dup), dep(ok&is_dup), 'Color', [0.55 0.55 0.55], 'LineWidth', 0.7);
            end
            % Mark Pop-B (Vp/Vs screened) with circles if Vs track
            if ci == 5 && any(is_popB & ok)
                scatter(ax, val(ok&is_popB), dep(ok&is_popB), 8, c.popB_excl, 'filled');
            end
        end

        set(ax,'YDir','reverse','XAxisLocation','bottom','FontSize',8);
        lbl = units{ci}; if strcmp(col,'VS'); col_lbl='V_s'; else; col_lbl=col; end
        xlabel(ax, sprintf('%s (%s)',col_lbl,lbl), 'FontSize',8);
        if ci == 1; ylabel(ax, 'Depth (m)', 'FontSize',8); end
        if ci == 1; title(ax, well_lbl,'FontSize',9,'FontWeight','bold'); end
        grid(ax,'on'); box(ax,'off');
    end
end

% Legend
leg_items = [plot(NaN,NaN,'Color',c.wellA,'LineWidth',1.2), ...
             plot(NaN,NaN,'Color',[0.5 0.5 0.9],'LineWidth',1.2), ...
             plot(NaN,NaN,'Color',c.wellB,'LineWidth',1.2), ...
             plot(NaN,NaN,'Color',[0.55 0.55 0.55],'LineWidth',1.2), ...
             scatter(NaN,NaN,12,c.popB_excl,'filled'), ...
             plot(NaN,NaN,'--','Color',[0.4 0.4 0.4],'LineWidth',0.8)];
lgd = legend(leg_items, ...
    'Well-A development (n=392)', ...
    'Well-A historical holdout (n=100)', ...
    ['Well-B Pop-A primary blind (n=' num2str(D.nPopA) ')'], ...
    ['Well-B shared-depth coordinates (n=' num2str(D.nShared) ')'], ...
    ['Well-B Vp/Vs screened (Pop-B, n=' num2str(D.nPopB) ')'], ...
    'Development / historical-holdout boundary', ...
    'Location','southoutside','Orientation','horizontal','FontSize',7, ...
    'NumColumns',3,'Box','off');
lgd.Layout.Tile = 'south';

nrr_assert_canonical(D);
drawnow;
nrr_export_figure(fig, out_dir, 'FIG01_logs_qc');
png_path = fullfile(out_dir,'FIG01_logs_qc.png');
pdf_path = fullfile(out_dir,'FIG01_logs_qc.pdf');
result = struct('status',"PASS",'name',"FIG01_logs_qc", ...
    'png_path',png_path,'pdf_path',pdf_path, ...
    'n_dev',numel(unique(dev_ids)),'n_hold',numel(unique(hold_ids)), ...
    'n_shared',numel(unique(dup_ids)),'n_popA',numel(unique(popA_ids)), ...
    'n_popB',numel(unique(popB_ids)));
close(fig);
end
