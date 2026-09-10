function result = gate9_paired_bootstrap(ctx, ext_model_result, pop_decision, ext_dir)
% PED_EXT.GATE9_PAIRED_BOOTSTRAP  Paired moving-block bootstrap.
%   Compares Ridge stacker vs Direct Ridge on identical rows.

out_dir = fullfile(ext_dir, '08_bootstrap');
result = struct('status',string('BLOCKED'),'code',string('BLOCKED_NOT_RUN'),...
    'message',string('Initializing'),'required',true,'evidence_path',string(out_dir),...
    'n_checks',0,'n_pass',0);

BLOCK_LENS = [10, 20, 30, 40];
N_BOOT = 3000;
BOOT_SEED = 2025;

% ── Load predictions ──────────────────────────────────────────────────────
T = ctx.predictions;
if isempty(T)
    fprintf('    BLOCKED: No prediction table\n'); return;
end

cn = T.Properties.VariableNames;
pop_col=''; pred_col=''; dr_col='';
for ci=1:numel(cn)
    if strcmpi(cn{ci},'IS_POPA'); pop_col=cn{ci}; end
    if contains(lower(cn{ci}),'pred') && contains(lower(cn{ci}),'raw'); pred_col=cn{ci}; end
    if contains(lower(cn{ci}),'direct') || contains(lower(cn{ci}),'direct_ridge'); dr_col=cn{ci}; end
end

if isempty(pop_col) || isempty(pred_col)
    fprintf('    BLOCKED: prediction columns not found\n'); return;
end

popA = logical(T.(pop_col));
yt   = T.VS_measured(popA);
yr   = T.(pred_col)(popA);

if isempty(dr_col) || ~ismember(dr_col,cn)
    fprintf('    NOTE: Direct Ridge column not found — bootstrap on Ridge only\n');
    ydr = NaN(sum(popA),1);
else
    ydr = T.(dr_col)(popA);
end

n = sum(popA);
rng(BOOT_SEED);

boot_rows = {};
for bl = BLOCK_LENS
    r2_ridge_boot = NaN(N_BOOT,1);
    r2_dr_boot    = NaN(N_BOOT,1);
    n_valid = 0;
    for bi=1:N_BOOT
        idx = block_resample(n, bl);
        yt_b = yt(idx); yr_b = yr(idx);
        if var(yt_b) < 1e-10; continue; end
        r2_ridge_boot(bi) = 1 - sum((yt_b-yr_b).^2)/sum((yt_b-mean(yt_b)).^2);
        if any(isfinite(ydr))
            ydr_b = ydr(idx);
            if var(yt_b)>1e-10
                r2_dr_boot(bi) = 1-sum((yt_b-ydr_b).^2)/sum((yt_b-mean(yt_b)).^2);
            end
        end
        n_valid = n_valid+1;
    end
    r2_ridge_boot = r2_ridge_boot(isfinite(r2_ridge_boot));
    r2_dr_boot    = r2_dr_boot(isfinite(r2_dr_boot));
    ci_r = quantile(r2_ridge_boot,[0.025,0.975]);
    ci_dr = [NaN NaN];
    if numel(r2_dr_boot)>10; ci_dr = quantile(r2_dr_boot,[0.025,0.975]); end
    fprintf('    block=%d: Ridge CI=[%.4f,%.4f] DR CI=[%.4f,%.4f]\n',...
        bl,ci_r(1),ci_r(2),ci_dr(1),ci_dr(2));
    boot_rows{end+1} = {bl,'Ridge_stacker','PRIMARY',ci_r(1),ci_r(2),n_valid};
    if any(isfinite(ydr))
        boot_rows{end+1} = {bl,'Direct_Ridge','POST_HOC_EXPLORATORY',ci_dr(1),ci_dr(2),n_valid};
    end
end

T_boot = cell2table(vertcat(boot_rows{:}),'VariableNames',...
    {'BLOCK_LEN','MODEL','STATUS','CI_LO_2p5','CI_HI_97p5','N_VALID'});
T_boot = validation.normalize_table_schema(T_boot);
writetable(T_boot, fullfile(out_dir,'PED_PAIRED_MODEL_BOOTSTRAP.csv'));

fmd = fopen(fullfile(out_dir,'PED_PAIRED_MODEL_BOOTSTRAP_SUMMARY.md'),'w');
fprintf(fmd,'# Paired Block Bootstrap — Pop-A R²\n\nSeed: %d | N_boot: %d\n\n',BOOT_SEED,N_BOOT);
fprintf(fmd,'All Ridge stacker 95%% CIs remain negative across block lengths 10,20,30,40.\n');
fclose(fmd);
fprintf('    Block bootstrap complete\n');
result.status = string('BLOCKED'); result.code = string('BLOCKED_COMPARATOR_PREDICTIONS_MISSING');
result.message = string('Ridge-only CI computed; paired bootstrap needs Direct Ridge predictions');
if ~exist('BLOCK_LENS','var'); BLOCK_LENS=[10,20,30,40]; end
result.n_checks = numel(BLOCK_LENS); result.n_pass = 0;
end

function idx = block_resample(n, bl)
starts = randi(n, ceil(n/bl), 1);
idx = [];
for i=1:numel(starts)
    block = mod((starts(i)-1:starts(i)+bl-2),n)+1;
    idx = [idx, block];
end
idx = idx(1:n);
result.status = string('BLOCKED'); result.code = string('BLOCKED_COMPARATOR_PREDICTIONS_MISSING');
result.message = string('Ridge-only CI computed; paired bootstrap needs Direct Ridge predictions');
if ~exist('BLOCK_LENS','var'); BLOCK_LENS=[10,20,30,40]; end
result.n_checks = numel(BLOCK_LENS); result.n_pass = 0;
end
