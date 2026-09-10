function main_ped_targeted_extension(project_root, canonical_run_id)
% MAIN_PED_TARGETED_EXTENSION  Orchestrator for PED targeted extension.
%
% Contract: every gate returns a result struct with fields:
%   result.status        = "PASS"|"BLOCKED"|"FAIL"|"SKIPPED"
%   result.code          = string (machine-readable reason)
%   result.message       = string (human-readable)
%   result.required      = logical
%   result.evidence_path = string (folder where outputs were written)
%   result.n_checks      = integer
%   result.n_pass        = integer
%
% Status semantics:
%   PASS    = all acceptance criteria met
%   BLOCKED = scientific input missing; cannot determine pass/fail
%   FAIL    = ran and found a violation
%   SKIPPED = validly not run (must have documented scientific reason)
%
% Exception in a gate -> FAIL with code=UNEXPECTED_RUNTIME_ERROR
% BLOCKED and SKIPPED are NOT counted as PASS.
%
% Required gates (must all be PASS for a valid run):
%   0,1,2,3,4,5,6,8,9,10
% Gate 7 allows PASS or SKIPPED_BY_VALID_DECISION.
% Gates 11,12 run only if can_freeze is true.

t_stamp   = datestr(now,'yyyymmdd_HHMMSS');
ext_run_id = sprintf('ped_extension_%s_%s', canonical_run_id, t_stamp);
ext_dir    = fullfile(project_root, 'runs', ext_run_id);
mkdir(ext_dir);

% ── Subfolder scaffold ────────────────────────────────────────────────────
subdirs = {'00_environment','01_duplicate_audit','02_provenance',...
    '03_boundary_audit','04_holdout','05_external_models',...
    '06_full_b_sensitivity','07_domain_shift','08_bootstrap',...
    '09_physics','10_freeze','11_report','figures_staging','logs'};
for k = 1:numel(subdirs); mkdir(fullfile(ext_dir,subdirs{k})); end

% ── Log file ──────────────────────────────────────────────────────────────
log_path = fullfile(ext_dir,'logs','PED_EXTENSION_RUN.log');
fid = fopen(log_path,'w');
if fid < 3; error('Cannot open log: %s', log_path); end
clog = onCleanup(@() fclose_safe(fid));
logf = @(s) fprintf(fid,'[%s] %s\n', datestr(now,'HH:MM:SS'), s);
logf(sprintf('PED extension: %s | canonical: %s', ext_run_id, canonical_run_id));

% ── Required gates definition ─────────────────────────────────────────────
% Gates 0..10 map to gate_results indices 1..11
% Gate 0 = index 1, Gate 1 = index 2, ..., Gate 10 = index 11
% Gates 11,12 = indices 12,13 (freeze and report)
GATE_NAMES = {'EXT_GATE_0','EXT_GATE_1','EXT_GATE_2','EXT_GATE_3',...
    'EXT_GATE_4','EXT_GATE_5','EXT_GATE_6','EXT_GATE_7',...
    'EXT_GATE_8','EXT_GATE_9','EXT_GATE_10','EXT_GATE_11','EXT_GATE_12'};
N_GATES = 13;

% Required gate indices (1-based): 0→1, 1→2, 2→3, 3→4, 4→5, 5→6, 6→7,
%                                   8→9, 9→10, 10→11
REQUIRED_IDX  = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11];  % indices of required gates
GATE7_IDX     = 8;  % Gate 7 allows PASS or SKIPPED_BY_VALID_DECISION

% ── Initialize result array ───────────────────────────────────────────────
gate_results = cell(N_GATES,1);
for k = 1:N_GATES
    gate_results{k} = make_result('PENDING','PENDING','Not yet run',false,'',0,0);
end

canonical_dir = fullfile(project_root,'runs',canonical_run_id);
ctx = [];

sep = repmat('=',1,60);
fprintf('\n%s\n  PED TARGETED EXTENSION | %s\n%s\n\n', sep, t_stamp, sep);

% ══════════════════════════════════════════════════════════════════════════
% GATE 0 — Environment and frozen artifact verification
% ══════════════════════════════════════════════════════════════════════════
fprintf('[EXT_GATE_0] Environment and frozen artifact verification...\n');
try
    ctx = ped_ext.gate0_environment(project_root, canonical_dir, ext_dir);
    gate_results{1} = ctx.gate_result;
catch ME
    gate_results{1} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'00_environment'),0,0);
end
print_gate(GATE_NAMES{1}, gate_results{1});
logf(sprintf('%s: %s [%s]', GATE_NAMES{1}, gate_results{1}.status, gate_results{1}.code));

if gate_results{1}.status ~= "PASS"
    logf('Gate 0 did not PASS — cannot continue (frozen artifacts unverified)');
    finalize(ext_dir, ext_run_id, GATE_NAMES, gate_results, REQUIRED_IDX, GATE7_IDX, log_path, fid);
    return;
end

% ══════════════════════════════════════════════════════════════════════════
% GATE 1 — Duplicate forensic audit
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_1] Duplicate forensic audit...\n');
dup_result = [];
try
    dup_result = ped_ext.gate1_duplicate_forensic(ctx, ext_dir);
    gate_results{2} = dup_result.gate_result;
catch ME
    gate_results{2} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'01_duplicate_audit'),0,0);
end
print_gate(GATE_NAMES{2}, gate_results{2});
logf(sprintf('%s: %s [%s]', GATE_NAMES{2}, gate_results{2}.status, gate_results{2}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 2 — Population decision
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_2] Population decision...\n');
pop_decision = [];
try
    pop_decision = ped_ext.gate2_population_decision(ctx, dup_result, ext_dir);
    gate_results{3} = pop_decision.gate_result;
catch ME
    gate_results{3} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'01_duplicate_audit'),0,0);
end
print_gate(GATE_NAMES{3}, gate_results{3});
logf(sprintf('%s: %s [%s]', GATE_NAMES{3}, gate_results{3}.status, gate_results{3}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 3 — Architecture provenance
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_3] Architecture and hyperparameter provenance...\n');
try
    r3 = ped_ext.gate3_architecture_provenance(ctx, ext_dir);
    gate_results{4} = r3;
catch ME
    gate_results{4} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'02_provenance'),0,0);
end
print_gate(GATE_NAMES{4}, gate_results{4});
logf(sprintf('%s: %s [%s]', GATE_NAMES{4}, gate_results{4}.status, gate_results{4}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 4 — CNN boundary audit
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_4] CNN window and preprocessing boundary audit...\n');
try
    r4 = ped_ext.gate4_cnn_boundary(ctx, ext_dir);
    gate_results{5} = r4;
catch ME
    gate_results{5} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'03_boundary_audit'),0,0);
end
print_gate(GATE_NAMES{5}, gate_results{5});
logf(sprintf('%s: %s [%s]', GATE_NAMES{5}, gate_results{5}.status, gate_results{5}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 5 — Corrected 100-sample holdout (train-392, primary Ridge stacker)
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_5] Corrected 100-sample holdout evaluation (train-392)...\n');
holdout_result = [];
try
    holdout_result = ped_ext.gate5_corrected_holdout(ctx, ext_dir);
    gate_results{6} = holdout_result.gate_result;
catch ME
    gate_results{6} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'04_holdout'),0,0);
end
print_gate(GATE_NAMES{6}, gate_results{6});
logf(sprintf('%s: %s [%s]', GATE_NAMES{6}, gate_results{6}.status, gate_results{6}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 6 — External evaluation all models (train-492)
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_6] External evaluation — all frozen models (train-492)...\n');
ext_model_result = [];
try
    ext_model_result = ped_ext.gate6_external_all_models(ctx, pop_decision, ext_dir);
    gate_results{7} = ext_model_result.gate_result;
catch ME
    gate_results{7} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'05_external_models'),0,0);
end
print_gate(GATE_NAMES{7}, gate_results{7});
logf(sprintf('%s: %s [%s]', GATE_NAMES{7}, gate_results{7}.status, gate_results{7}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 7 — Full Well-B sensitivity (conditional on Gate 2)
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_7] Full Well-B sensitivity (conditional)...\n');
try
    r7 = ped_ext.gate7_full_well_b(ctx, pop_decision, ext_dir);
    gate_results{8} = r7;
catch ME
    gate_results{8} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,false,...
        fullfile(ext_dir,'06_full_b_sensitivity'),0,0);
end
print_gate(GATE_NAMES{8}, gate_results{8});
logf(sprintf('%s: %s [%s]', GATE_NAMES{8}, gate_results{8}.status, gate_results{8}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 8 — Support-shift and DT diagnostics
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_8] Support-shift and DT diagnostics...\n');
try
    r8 = ped_ext.gate8_support_diagnostics(ctx, pop_decision, ext_dir);
    gate_results{9} = r8;
catch ME
    gate_results{9} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'07_domain_shift'),0,0);
end
print_gate(GATE_NAMES{9}, gate_results{9});
logf(sprintf('%s: %s [%s]', GATE_NAMES{9}, gate_results{9}.status, gate_results{9}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 9 — Paired moving-block bootstrap
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_9] Paired moving-block bootstrap...\n');
try
    r9 = ped_ext.gate9_paired_bootstrap(ctx, ext_model_result, pop_decision, ext_dir);
    gate_results{10} = r9;
catch ME
    gate_results{10} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'08_bootstrap'),0,0);
end
print_gate(GATE_NAMES{10}, gate_results{10});
logf(sprintf('%s: %s [%s]', GATE_NAMES{10}, gate_results{10}.status, gate_results{10}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 10 — Physical plausibility audit
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_10] Physical plausibility audit...\n');
try
    r10 = ped_ext.gate10_physical_plausibility(ctx, ext_model_result, pop_decision, ext_dir);
    gate_results{11} = r10;
catch ME
    gate_results{11} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,true,...
        fullfile(ext_dir,'09_physics'),0,0);
end
print_gate(GATE_NAMES{11}, gate_results{11});
logf(sprintf('%s: %s [%s]', GATE_NAMES{11}, gate_results{11}.status, gate_results{11}.code));

% ══════════════════════════════════════════════════════════════════════════
% Decide whether to freeze
% ══════════════════════════════════════════════════════════════════════════
required_pass = all(cellfun(@(r) r.status=="PASS", gate_results(REQUIRED_IDX)));
gate7_valid   = any(gate_results{GATE7_IDX}.status == ["PASS","SKIPPED_BY_VALID_DECISION"]);
can_freeze    = required_pass && gate7_valid;

logf(sprintf('required_pass=%d gate7_valid=%d can_freeze=%d', ...
    required_pass, gate7_valid, can_freeze));

% ══════════════════════════════════════════════════════════════════════════
% GATE 11 — Freeze (only if can_freeze)
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_11] Freeze extension artifacts...\n');
if ~can_freeze
    n_req_fail = sum(cellfun(@(r) r.status~="PASS", gate_results(REQUIRED_IDX)));
    msg11 = sprintf('BLOCKED_REQUIRED_GATES_INCOMPLETE: %d required gate(s) not PASS', n_req_fail);
    gate_results{12} = make_result('BLOCKED','BLOCKED_REQUIRED_GATES_INCOMPLETE',msg11,false,...
        fullfile(ext_dir,'10_freeze'),0,0);
    fprintf('  BLOCKED — %s\n', msg11);
    logf(sprintf('EXT_GATE_11: BLOCKED -- %s', msg11));
else
    try
        r11 = ped_ext.gate11_freeze(ctx, ext_dir, ext_run_id, gate_results, GATE_NAMES,...
            holdout_result, ext_model_result, pop_decision);
        gate_results{12} = r11;
    catch ME
        gate_results{12} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,false,...
            fullfile(ext_dir,'10_freeze'),0,0);
    end
end
print_gate(GATE_NAMES{12}, gate_results{12});
logf(sprintf('%s: %s [%s]', GATE_NAMES{12}, gate_results{12}.status, gate_results{12}.code));

% ══════════════════════════════════════════════════════════════════════════
% GATE 12 — Report and figures staging
% ══════════════════════════════════════════════════════════════════════════
fprintf('\n[EXT_GATE_12] Report and figures staging...\n');
try
    r12 = ped_ext.gate12_report(ctx, ext_dir, ext_run_id, gate_results, GATE_NAMES,...
        holdout_result, ext_model_result, pop_decision, dup_result, can_freeze);
    gate_results{13} = r12;
catch ME
    gate_results{13} = make_result('FAIL','UNEXPECTED_RUNTIME_ERROR',ME.message,false,...
        fullfile(ext_dir,'11_report'),0,0);
end
print_gate(GATE_NAMES{13}, gate_results{13});
logf(sprintf('%s: %s [%s]', GATE_NAMES{13}, gate_results{13}.status, gate_results{13}.code));

finalize(ext_dir, ext_run_id, GATE_NAMES, gate_results, REQUIRED_IDX, GATE7_IDX, log_path, fid);
end

% ══════════════════════════════════════════════════════════════════════════
% Local helpers
% ══════════════════════════════════════════════════════════════════════════
function finalize(ext_dir, ext_run_id, GATE_NAMES, gate_results, REQUIRED_IDX, GATE7_IDX, log_path, fid)
n_pass    = sum(cellfun(@(r) r.status=="PASS",    gate_results));
n_fail    = sum(cellfun(@(r) r.status=="FAIL",    gate_results));
n_blocked = sum(cellfun(@(r) r.status=="BLOCKED", gate_results));
n_skipped = sum(cellfun(@(r) r.status=="SKIPPED" | contains(r.status,"SKIPPED"), gate_results));

required_pass = all(cellfun(@(r) r.status=="PASS", gate_results(REQUIRED_IDX)));
gate7_valid   = any(gate_results{GATE7_IDX}.status == ["PASS","SKIPPED_BY_VALID_DECISION"]);
can_freeze    = required_pass && gate7_valid;
overall       = "FAIL";
if can_freeze && n_fail==0 && gate_results{12}.status=="PASS" && gate_results{13}.status=="PASS"
    overall = "PASS";
end

% Write gate status CSV
T = table(string(GATE_NAMES(:)),...
    cellfun(@(r) r.status,   gate_results,'UniformOutput',false),...
    cellfun(@(r) r.code,     gate_results,'UniformOutput',false),...
    cellfun(@(r) r.message,  gate_results,'UniformOutput',false),...
    'VariableNames',{'GATE','STATUS','CODE','MESSAGE'});
T.STATUS  = string(T.STATUS);
T.CODE    = string(T.CODE);
T.MESSAGE = string(T.MESSAGE);
writetable(T, fullfile(ext_dir,'PED_EXTENSION_GATE_STATUS.csv'));

sep = repmat('=',1,60);
fprintf('\n%s\n  PED TARGETED EXTENSION — %s\n%s\n', sep, overall, sep);
fprintf('  PASS: %d | FAIL: %d | BLOCKED: %d | SKIPPED: %d\n',...
    n_pass, n_fail, n_blocked, n_skipped);
fprintf('  Required gates PASS: %s | Gate 7 valid: %s | Can freeze: %s\n',...
    yn(required_pass), yn(gate7_valid), yn(can_freeze));
for i=1:numel(GATE_NAMES)
    st = gate_results{i}.status;
    sym = '✓'; if st~="PASS"; sym='✗'; end
    fprintf('  [%s] %s: %s\n', sym, GATE_NAMES{i}, st);
end
fprintf('  Output: %s\n%s\n\n', ext_dir, sep);

if fid>=3
    fprintf(fid,'[%s] OVERALL: %s | PASS=%d FAIL=%d BLOCKED=%d SKIPPED=%d can_freeze=%d\n',...
        datestr(now,'HH:MM:SS'), overall, n_pass, n_fail, n_blocked, n_skipped, can_freeze);
end

if overall ~= "PASS"
    error('PED Extension: overall status=%s. Resolve BLOCKED/FAIL gates before rerunning.', overall);
end
end

function r = make_result(status, code, message, required, evidence_path, n_checks, n_pass)
r.status        = string(status);
r.code          = string(code);
r.message       = string(message);
r.required      = logical(required);
r.evidence_path = string(evidence_path);
r.n_checks      = n_checks;
r.n_pass        = n_pass;
end

function print_gate(name, r)
fprintf('  %s: %s [%s]\n', name, r.status, r.code);
msg = strtrim(char(r.message));
cod = strtrim(char(r.code));
if ~isempty(msg) && ~strcmp(msg, cod) && ~strcmp(msg,'')
    fprintf('    %s\n', msg);
end
end

function s = yn(v)
if v; s='YES'; else; s='NO'; end
end

function fclose_safe(fid)
if isnumeric(fid) && isscalar(fid) && fid>=3
    try; fclose(fid); catch; end
end
end
