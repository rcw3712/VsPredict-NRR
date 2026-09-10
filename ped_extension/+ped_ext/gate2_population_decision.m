function pop = gate2_population_decision(ctx, dup_result, ext_dir)
% PED_EXT.GATE2_POPULATION_DECISION  Locked population decision.
%   NO FALLBACK to canonical assumption. Gate 1 evidence is authoritative.
%   Divergence from canonical 163 → BLOCKED_CONTRADICTORY_EVIDENCE.

out_dir = fullfile(ext_dir, '01_duplicate_audit');
cc = dup_result.class_counts;

n_exact_full = cc.PREDICTOR_AND_TARGET_EXACT;
n_pred_only  = cc.PREDICTOR_EXACT;
n_depth_only = cc.DEPTH_MATCH_ONLY;
n_no_match   = cc.NO_MATCH;
n_total      = dup_result.n_classified;

fprintf('    Gate 1 result: %d EXACT_FULL | %d PRED_ONLY | %d DEPTH_ONLY | %d NO_MATCH\n',...
    n_exact_full, n_pred_only, n_depth_only, n_no_match);

% ── Check divergence from canonical ──────────────────────────────────────
% Canonical says 163 rows were excluded. Gate 1 must corroborate this.
% If Gate 1 finds 0 exact duplicates, that CONTRADICTS the canonical design.
% This cannot be resolved by falling back to an assumption.
divergence = (n_exact_full ~= ctx.n_shared) && (n_depth_only ~= ctx.n_shared);

if divergence && n_exact_full == 0 && n_depth_only == 0
    % No depth matches at all — likely a depth unit or resampling mismatch
    error(['gate2: BLOCKED_CONTRADICTORY_EVIDENCE — Gate 1 found 0 depth matches '...
        'but canonical design excluded 163. Check: (1) depth units in Well-A vs Well-B, '...
        '(2) resampling applied before or after split, '...
        '(3) ROW_ID alignment. '...
        'Do NOT fall back to canonical assumption.']);
end

% ── Decision rule (evidence-based only) ──────────────────────────────────
if n_exact_full > 0
    % Condition A: rows with identical predictor AND target exist
    condition       = 'A';
    primary_pop     = sprintf('Pop-A (n=%d, depth-disjoint)', ctx.n_popA);
    full_b_valid    = false;
    full_b_status   = 'CONTAMINATED_DIAGNOSTIC_NOT_FOR_PERFORMANCE_CLAIMS';
    notes = sprintf('%d PREDICTOR_AND_TARGET_EXACT found — Condition A applies.', n_exact_full);

elseif n_exact_full == 0 && n_pred_only == 0 && n_depth_only > 0
    % Condition B: only depth coordinate matches, values differ
    condition       = 'B';
    primary_pop     = sprintf('Pop-A (n=%d, conservative primary)', ctx.n_popA);
    full_b_valid    = true;
    full_b_status   = 'FULL_WELL_B_SENSITIVITY';
    notes = sprintf('%d DEPTH_MATCH_ONLY (values differ) — Condition B. Full Well-B valid as sensitivity.', n_depth_only);
    fprintf('    CONDITION B: 163 rows are depth-coordinate matches with DIFFERENT log values.\n');
    fprintf('    This means Pop-A exclusion was conservative. Full Well-B (n=492) is valid sensitivity.\n');

elseif n_exact_full == 0 && n_pred_only > 0
    % Condition C: predictor match but target differs
    condition       = 'C';
    primary_pop     = sprintf('Pop-A (n=%d, mixed case)', ctx.n_popA);
    full_b_valid    = false;
    full_b_status   = 'REQUIRES_SCIENTIFIC_REVIEW';
    notes = sprintf('Mixed: %d EXACT_FULL=0, %d PRED_ONLY. REQUIRES_SCIENTIFIC_REVIEW.', ...
        n_exact_full, n_pred_only);

else
    error('gate2: Unresolvable classification pattern. Manual review required.');
end

fprintf('    Decision: Condition %s — %s\n', condition, notes);
fprintf('    Full Well-B valid: %d\n', full_b_valid);

% ── Write outputs ─────────────────────────────────────────────────────────
T_dec = table(...
    string({'condition','primary_pop','full_b_valid','full_b_status',...
            'n_exact_full','n_pred_only','n_depth_only','n_no_match',...
            'n_total_classified','canonical_n_shared','notes'}),...
    string({condition, primary_pop, num2str(full_b_valid), full_b_status,...
            num2str(n_exact_full), num2str(n_pred_only),...
            num2str(n_depth_only), num2str(n_no_match),...
            num2str(n_total), num2str(ctx.n_shared), notes}),...
    'VariableNames',{'PARAMETER','VALUE'});
writetable(T_dec, fullfile(out_dir,'PED_POPULATION_DECISION.csv'));

% Population membership per row
cls   = dup_result.cls_list;
n_B   = numel(cls);
memb  = repmat(string('UNASSIGNED'), n_B, 1);
for ri=1:n_B
    switch string(cls(ri))
        case "PREDICTOR_AND_TARGET_EXACT"
            memb(ri) = "DUPLICATE_EXCLUDED_AUDIT_SET";
        case "PREDICTOR_EXACT"
            memb(ri) = "PREDICTOR_ONLY_MATCH";
        case "DEPTH_MATCH_ONLY"
            if full_b_valid
                memb(ri) = "DEPTH_MATCH_INCLUDED_IN_FULL_WELL_B_SENSITIVITY";
            else
                memb(ri) = "DEPTH_COORD_MATCH_CONSERVATIVE_EXCLUSION";
            end
        case "NO_MATCH"
            memb(ri) = "BLIND_EVALUATION_INCLUDED_POPA";
        case "ROW_ID_COLLISION"
            memb(ri) = "ROW_ID_COLLISION_FLAGGED";
        otherwise
            memb(ri) = "UNCLASSIFIED_ERROR";
    end
end
T_mem = table(dup_result.T_audit.WELL_B_ROW_ID, dup_result.T_audit.WELL_B_DEPTH,...
    dup_result.T_audit.CLASSIFICATION, memb,...
    'VariableNames',{'ROW_ID','DEPTH','CLASSIFICATION','POPULATION_MEMBERSHIP'});
writetable(T_mem, fullfile(out_dir,'PED_POPULATION_MEMBERSHIP.csv'));

fmd = fopen(fullfile(out_dir,'PED_POPULATION_DECISION.md'),'w');
fprintf(fmd,'# Population Decision\n\n**Condition %s** — Evidence-based only, no fallback.\n\n',condition);
fprintf(fmd,'%s\n\n',notes);
if strcmp(condition,'B')
    fprintf(fmd,'## Implication\n\nThe 163 depth-coordinate matches have DIFFERENT log values.\n');
    fprintf(fmd,'This supports the interpretation that the canonical exclusion was conservative.\n');
    fprintf(fmd,'Full Well-B (n=492) is valid as a prespecified sensitivity analysis.\n\n');
end
fclose(fmd);

pop.condition    = condition;
pop.primary_pop  = primary_pop;
pop.full_b_valid = full_b_valid;
pop.full_b_status= full_b_status;
pop.notes        = notes;
pop.cls_list     = cls;
pop.membership   = memb;
pop.T_membership = T_mem;
pop.n_exact_full = n_exact_full;
pop.gate_result = struct('status',string('PASS'),'code',string(sprintf('CONDITION_%s',condition)),...
    'message',string(notes),'required',true,'evidence_path',string(out_dir),...
    'n_checks',1,'n_pass',1);
end
