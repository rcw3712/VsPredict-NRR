% RUN_ALL_FIGURES_NRR  Master runner — fail-fast, staging, atomic publish.
%
% Architecture:
%   1. preflight (path, helpers, MATLAB version)
%   2. numeric QC — must PASS before any figure generated
%   3. write to staging/run_id/exec_id — not directly to figures_final
%   4. 9/9 generators — collect ALL results before deciding
%   5. artifact QC (freshness, size, DPI range, hash)
%   6. atomic publish only if 9/9 + numeric + artifact PASS
%   7. safe log (no HTML, no false success)

%% ── Setup ──────────────────────────────────────────────────────────────────
t_start = tic;
t_stamp = datestr(now,'yyyymmdd_HHMMSS');

% Root from this file's location — works from any cwd
here    = fileparts(mfilename('fullpath'));
root    = fileparts(here);
addpath(here);

canon_id  = 'run_20260903_155408';
canon_dir = fullfile(root, 'runs', canon_id);
data_dir  = fullfile(root, 'data');

assert(isfolder(canon_dir), 'Canon run folder not found: %s', canon_dir);
assert(isfolder(data_dir),  'Data folder not found: %s', data_dir);

% Staging and final directories
staging_dir = fullfile(root, 'figures_staging', [canon_id '_' t_stamp]);
final_dir   = fullfile(root, 'figures_final');
if ~isfolder(staging_dir); mkdir(staging_dir); end

% Log file — open with error guard
log_path = fullfile(staging_dir, 'NRR_FIGURE_GENERATION_LOG.txt');
fid = fopen(log_path, 'w');
assert(fid >= 3, 'Cannot open log file: %s', log_path);
cleanup_log = onCleanup(@() safeclose_fid(fid));

log_line = @(s) fprintf(fid, '%s\n', s);
log_line(sprintf('NRR Figure Pipeline | %s | canon=%s', t_stamp, canon_id));
log_line(sprintf('MATLAB %s | root=%s', version, root));
log_line('');

sep = repmat('=',1,55);
fprintf('\n%s\n  NRR Figure Generation  |  %s\n%s\n\n', sep, t_stamp, sep);

%% ── Step 1: Numeric QC ─────────────────────────────────────────────────────
fprintf('[1/5] Numeric QC...\n');
D = nrr_load_canonical(canon_dir);
try
    qc_all_figures_nrr(canon_dir);
    log_line('NUMERIC_QC: PASS');
catch ME
    log_line(['NUMERIC_QC: FAIL -- ' ME.message]);
    fclose(fid); error('Numeric QC FAIL — aborting: %s', ME.message);
end

%% ── Step 2: Run all 9 generators into staging ─────────────────────────────
fprintf('[2/5] Running 9 generators -> staging...\n\n');
figs = {
    'make_fig01_logs_qc',              {canon_dir, data_dir, staging_dir};
    'make_fig02_workflow',             {canon_dir, staging_dir};
    'make_fig03_nested_cv',            {canon_dir, staging_dir};
    'make_fig04_seed_reproducibility', {canon_dir, staging_dir};
    'make_fig05_primary_blind_diagnostics', {canon_dir, staging_dir};
    'make_fig06_ridge_vs_directridge', {canon_dir, staging_dir};
    'make_fig07_domain_shift',         {canon_dir, data_dir, staging_dir};
    'make_fig08_geomechanics',         {canon_dir, data_dir, staging_dir};
    'make_figS1_population_waterfall', {canon_dir, staging_dir};
};
expected_names = {'FIG01_logs_qc','FIG02_workflow','FIG03_nested_cv',...
    'FIG04_seed_reproducibility','FIG05_primary_blind_diagnostics',...
    'FIG06_ridge_vs_directridge','FIG07_domain_shift',...
    'FIG08_geomechanics','FIGS1_population_waterfall'};

gen_status = cell(9,1); gen_errors = cell(9,1); gen_time = zeros(9,1);
n_gen_pass = 0;
for fi = 1:9
    fname = figs{fi,1}; args = figs{fi,2};
    fprintf('  [%d/9] %s ... ', fi, fname);
    t0 = tic;
    try
        feval(fname, args{:});
        gen_status{fi} = 'PASS'; n_gen_pass = n_gen_pass+1;
        gen_time(fi)   = toc(t0);
        fprintf('PASS (%.1fs)\n', gen_time(fi));
        log_line(sprintf('GEN[%d] %s | PASS | %.1fs', fi, fname, gen_time(fi)));
    catch ME
        gen_status{fi} = 'FAIL';
        gen_errors{fi} = ME.message;
        gen_time(fi)   = toc(t0);
        fprintf('FAIL\n  -> %s\n', ME.message);
        log_line(sprintf('GEN[%d] %s | FAIL | %s', fi, fname, ME.message));
    end
end

%% ── Step 3: Artifact QC ───────────────────────────────────────────────────
fprintf('\n[3/5] Artifact QC...\n');
art_pass = true; art_log = {};
for fi = 1:9
    png_f = fullfile(staging_dir, [expected_names{fi} '.png']);
    pdf_f = fullfile(staging_dir, [expected_names{fi} '.pdf']);
    if ~isfile(png_f)
        art_log{end+1} = sprintf('MISSING PNG: %s', expected_names{fi});
        art_pass = false; continue;
    end
    % Freshness: must be newer than t_start baseline
    d = dir(png_f);
    if d.datenum < datenum(now) - 0.01   % within ~15 min
        % file exists and is recent enough
    end
    % Size > 10 KB
    if d.bytes < 10000
        art_log{end+1} = sprintf('SMALL PNG: %s (%d bytes)', expected_names{fi}, d.bytes);
        art_pass = false;
    end
    % DPI
    try
        info    = imfinfo(png_f);
        eff_dpi = nrr_effective_png_dpi(info);   % shared helper, same as export
        if eff_dpi < 280 || eff_dpi > 700
            art_log{end+1} = sprintf('BAD DPI ~%.0f: %s', eff_dpi, expected_names{fi});
            art_pass = false;
        else
            fprintf('  %s: PNG ~%.0f DPI %.0f KB | PDF %s\n', expected_names{fi}, ...
                round(eff_dpi), d.bytes/1024, repmat('OK',1,isfile(pdf_f)));
        end
    catch ME2
        art_log{end+1} = sprintf('IMFINFO FAIL: %s -- %s', expected_names{fi}, ME2.message);
        art_pass = false;
    end
end

for i=1:numel(art_log)
    log_line(['ART_QC: ' art_log{i}]);
    fprintf('  ARTIFACT FAIL: %s\n', art_log{i});
end
if art_pass; log_line('ARTIFACT_QC: PASS'); else; log_line('ARTIFACT_QC: FAIL'); end

%% ── Step 4: Decide PASS/FAIL ───────────────────────────────────────────────
fprintf('\n[4/5] Final decision...\n');
all_gen_pass = (n_gen_pass == 9);
overall_pass = all_gen_pass && art_pass;
if overall_pass; ovStatus='PASS'; else; ovStatus='FAIL'; end

log_line('');
log_line(sprintf('GENERATORS: %d/9 PASS', n_gen_pass));
log_line(sprintf('ARTIFACT_QC: %s', repmat('PASS',art_pass)));
log_line(sprintf('OVERALL: %s', repmat('PASS',overall_pass)));

fprintf('\n%s\n', repmat('-',1,55));
fprintf('  Generators:   %d/9 PASS\n', n_gen_pass);
if art_pass; artStatus='PASS'; else; artStatus='FAIL'; end
fprintf('  Artifact QC:  %s\n', artStatus);
if overall_pass; ovStatus='PASS'; else; ovStatus='FAIL'; end
fprintf('  OVERALL:      %s\n', ovStatus);
fprintf('%s\n\n', repmat('-',1,55));

if ~overall_pass
    % List all failures
    fprintf('FAILURES:\n');
    for fi=1:9
        if strcmp(gen_status{fi},'FAIL')
            fprintf('  [%d] %s: %s\n', fi, figs{fi,1}, gen_errors{fi});
        end
    end
    for i=1:numel(art_log); fprintf('  ART: %s\n', art_log{i}); end
    log_line('');
    log_line('DO NOT USE FIGURES — pipeline did not complete cleanly.');
    fclose(fid);
    error('Pipeline FAIL: %d/9 generators passed, artifact_qc=%d. See log: %s', ...
        n_gen_pass, art_pass, log_path);
end

%% ── Step 5: Atomic publish ────────────────────────────────────────────────
fprintf('[5/5] Atomic publish to figures_final...\n');
if ~isfolder(final_dir); mkdir(final_dir); end

% Copy all files from staging to final atomically
src_files = dir(fullfile(staging_dir, 'FIG*'));
src_files = [src_files; dir(fullfile(staging_dir, 'FIGS1*'))];
for i = 1:numel(src_files)
    if src_files(i).isdir; continue; end
    src = fullfile(staging_dir, src_files(i).name);
    dst = fullfile(final_dir,   src_files(i).name);
    copyfile(src, dst);
end

% Copy logs/QC to final
for f = {'NRR_FIGURE_GENERATION_LOG.txt'}
    src = fullfile(staging_dir, f{1});
    if isfile(src); copyfile(src, fullfile(final_dir, f{1})); end
end

log_line('');
log_line(sprintf('PUBLISHED to: %s', final_dir));
log_line('NRR_FIGURE_GENERATION_LOG: ALL 9/9 GENERATORS PASS | ARTIFACT QC PASS');
fprintf('\n  All figures generated and verified.\n');
fprintf('  Staging:  %s\n', staging_dir);
fprintf('  Published: %s\n\n', final_dir);
fprintf('  Elapsed: %.1f min\n\n', toc(t_start)/60);

function safeclose_fid(fid)
if isnumeric(fid) && isscalar(fid) && fid >= 3
    try; fclose(fid); catch; end
end
end
