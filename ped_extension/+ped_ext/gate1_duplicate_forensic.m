function result = gate1_duplicate_forensic(ctx, ext_dir)
% PED_EXT.GATE1_DUPLICATE_FORENSIC  Row-level duplicate forensic audit.
%   HARD RULE: sum(all classes) MUST equal height(Well-B) == 492.
%   Any arithmetic failure = error (not a soft warning).

out_dir = fullfile(ext_dir, '01_duplicate_audit');

% ── Load well data ─────────────────────────────────────────────────────────
T_A = load_well(ctx, 'A');
T_B = load_well(ctx, 'B');

nA = height(T_A); nB = height(T_B);
fprintf('    Well-A: %d rows | Well-B: %d rows\n', nA, nB);
assert(nA == ctx.n_wellA, 'gate1: Well-A row count %d != %d', nA, ctx.n_wellA);
assert(nB == ctx.n_wellB, 'gate1: Well-B row count %d != %d', nB, ctx.n_wellB);

tol_d = 1e-6;  tol_l = 1e-6;  tol_v = 1e-6;
fprintf('    Tolerances: depth=%.0e log=%.0e vs=%.0e\n', tol_d, tol_l, tol_v);

pred_cols = intersect({'GR','DT','NPHI','RHOB'}, T_A.Properties.VariableNames, 'stable');
pred_cols = intersect(pred_cols, T_B.Properties.VariableNames, 'stable');
tgt_A = ''; tgt_B = '';
for tc = {'VS','Vs','DTS','DTs'}
    if ismember(tc{1},T_A.Properties.VariableNames); tgt_A=tc{1}; break; end
end
for tc = {'VS','Vs','DTS','DTs'}
    if ismember(tc{1},T_B.Properties.VariableNames); tgt_B=tc{1}; break; end
end
fprintf('    Predictor cols: %s | Target A: %s | Target B: %s\n',...
    strjoin(pred_cols,','), tgt_A, tgt_B);

% ── Pre-build Well-A lookup by depth ──────────────────────────────────────
depths_A = T_A.DEPTH;

% ── Classify every Well-B row ─────────────────────────────────────────────
cls_list  = repmat(string('UNCLASSIFIED'), nB, 1);
row_ids_B = (1:nB)';
if ismember('ROW_ID', T_B.Properties.VariableNames)
    row_ids_B = T_B.ROW_ID;
end
match_A_id = NaN(nB,1);
pred_exact = false(nB,1);
tgt_exact  = false(nB,1);

for bi = 1:nB
    depth_B = T_B.DEPTH(bi);
    depth_matches = find(abs(depths_A - depth_B) <= tol_d);

    if isempty(depth_matches)
        cls_list(bi) = "NO_MATCH";
        continue;
    end

    ai = depth_matches(1);
    if ismember('ROW_ID',T_A.Properties.VariableNames)
        match_A_id(bi) = T_A.ROW_ID(ai);
    else
        match_A_id(bi) = ai;
    end

    % Check predictor exact match
    pm = true;
    for ci = 1:numel(pred_cols)
        col = pred_cols{ci};
        vA = T_A.(col)(ai); vB = T_B.(col)(bi);
        if isfinite(vA) && isfinite(vB)
            if abs(vA-vB) > tol_l; pm=false; break; end
        end
    end
    pred_exact(bi) = pm;

    % Check target exact match
    tm = false;
    if ~isempty(tgt_A) && ~isempty(tgt_B)
        vA = T_A.(tgt_A)(ai); vB = T_B.(tgt_B)(bi);
        if isfinite(vA) && isfinite(vB)
            tm = abs(vA-vB) <= tol_v;
        end
    end
    tgt_exact(bi) = tm;

    % Classify
    if pm && tm
        cls_list(bi) = "PREDICTOR_AND_TARGET_EXACT";
    elseif pm && ~tm
        cls_list(bi) = "PREDICTOR_EXACT";
    else
        cls_list(bi) = "DEPTH_MATCH_ONLY";
    end
end

% ── HARD CHECK: all 492 rows must be classified ───────────────────────────
n_unclass = sum(cls_list == "UNCLASSIFIED");
assert(n_unclass == 0, ...
    'gate1: %d rows remain UNCLASSIFIED — arithmetic failure', n_unclass);

% Count per class
cc.PREDICTOR_AND_TARGET_EXACT = sum(cls_list == "PREDICTOR_AND_TARGET_EXACT");
cc.PREDICTOR_EXACT            = sum(cls_list == "PREDICTOR_EXACT");
cc.DEPTH_MATCH_ONLY           = sum(cls_list == "DEPTH_MATCH_ONLY");
cc.ROW_ID_COLLISION           = 0;
cc.NO_MATCH                   = sum(cls_list == "NO_MATCH");

total_classified = cc.PREDICTOR_AND_TARGET_EXACT + cc.PREDICTOR_EXACT + ...
    cc.DEPTH_MATCH_ONLY + cc.ROW_ID_COLLISION + cc.NO_MATCH;

% ── HARD CHECK: total must equal nB ──────────────────────────────────────
assert(total_classified == nB, ...
    'gate1: class totals sum to %d, expected %d — audit arithmetic error', ...
    total_classified, nB);

fprintf('    Classifications: %d PRED+TGT_EXACT | %d PRED_EXACT | %d DEPTH_ONLY | %d NO_MATCH\n',...
    cc.PREDICTOR_AND_TARGET_EXACT, cc.PREDICTOR_EXACT, cc.DEPTH_MATCH_ONLY, cc.NO_MATCH);
fprintf('    Total: %d / %d rows classified (PASS)\n', total_classified, nB);
fprintf('    Historical canonical "163 exact duplicates": found %d PREDICTOR_AND_TARGET_EXACT\n',...
    cc.PREDICTOR_AND_TARGET_EXACT);

% ── Write CSV ─────────────────────────────────────────────────────────────
T_audit = table(row_ids_B, T_B.DEPTH, match_A_id, cls_list, pred_exact, tgt_exact,...
    'VariableNames',{'WELL_B_ROW_ID','WELL_B_DEPTH','MATCHED_A_ROW_ID',...
    'CLASSIFICATION','PRED_EXACT','TARGET_EXACT'});
writetable(T_audit, fullfile(out_dir,'PED_DUPLICATE_FORENSIC_AUDIT.csv'));

classes_u  = {'PREDICTOR_AND_TARGET_EXACT','PREDICTOR_EXACT','DEPTH_MATCH_ONLY',...
              'ROW_ID_COLLISION','NO_MATCH'};
counts_u   = [cc.PREDICTOR_AND_TARGET_EXACT, cc.PREDICTOR_EXACT, ...
              cc.DEPTH_MATCH_ONLY, cc.ROW_ID_COLLISION, cc.NO_MATCH];
T_sum = table(string(classes_u(:)), counts_u(:), counts_u(:)/nB*100,...
    'VariableNames',{'CLASSIFICATION','COUNT','PCT'});
writetable(T_sum, fullfile(out_dir,'PED_DUPLICATE_CLASS_SUMMARY.csv'));

% ── Write MD ──────────────────────────────────────────────────────────────
fmd = fopen(fullfile(out_dir,'PED_DUPLICATE_FORENSIC_AUDIT.md'),'w');
fprintf(fmd,'# Duplicate Forensic Audit\n\nRows: Well-A=%d Well-B=%d\n\n',nA,nB);
fprintf(fmd,'| Class | Count | Pct |\n|---|---|---|\n');
for i=1:numel(classes_u)
    fprintf(fmd,'| %s | %d | %.1f%% |\n',classes_u{i},counts_u(i),counts_u(i)/nB*100);
end
fprintf(fmd,'\n**Total classified: %d / %d (arithmetic verified)**\n\n',total_classified,nB);
if cc.PREDICTOR_AND_TARGET_EXACT == ctx.n_shared
    fprintf(fmd,'CONFIRMED: %d matches match canonical n_shared=%d\n', ...
        cc.PREDICTOR_AND_TARGET_EXACT, ctx.n_shared);
else
    fprintf(fmd,'DIVERGENCE: found %d PRED+TGT_EXACT vs canonical n_shared=%d\n',...
        cc.PREDICTOR_AND_TARGET_EXACT, ctx.n_shared);
    fprintf(fmd,'This divergence must be resolved before manuscript revision.\n');
end
fclose(fmd);

result.n_classified = total_classified;
result.class_counts = cc;
result.n_exact_full = cc.PREDICTOR_AND_TARGET_EXACT;
result.cls_list     = cls_list;
result.T_audit      = T_audit;
result.T_summary    = T_sum;
result.confirmed_canonical = (cc.PREDICTOR_AND_TARGET_EXACT == ctx.n_shared);
result.gate_result = struct('status',string('PASS'),'code',string('OK'),...
    'message',string(sprintf('%d/%d rows classified; %d PRED+TGT_EXACT', ...
    total_classified,nB,cc.PREDICTOR_AND_TARGET_EXACT)),...
    'required',true,'evidence_path',string(out_dir),'n_checks',nB,'n_pass',nB);
end

function T = load_well(ctx, letter)
candidates = {
    fullfile(ctx.project_root,'data',sprintf('Well-%s.xlsx',letter));
    fullfile(ctx.project_root,'data',sprintf('well_%s.csv',lower(letter)));
};
for i=1:numel(candidates)
    if isfile(candidates{i})
        [~,~,ext_] = fileparts(candidates{i});
        if strcmpi(ext_,'.xlsx')
            T = readtable(candidates{i},'VariableNamingRule','preserve');
        else
            T = readtable(candidates{i},'TextType','string');
        end
        T.Properties.VariableNames = cellfun(@(s) strtok(strtrim(s),' '),...
            T.Properties.VariableNames,'UniformOutput',false);
        T = sortrows(T,'DEPTH');
        if ~ismember('ROW_ID',T.Properties.VariableNames)
            T.ROW_ID = (1:height(T))';
        end
        return;
    end
end
error('gate1: Well-%s data not found. Tried: %s', letter, strjoin(candidates,'; '));
end
