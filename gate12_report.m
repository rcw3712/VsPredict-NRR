function result = gate12_report(ctx, ext_dir, ext_run_id, gate_results, gate_names,...
    holdout_result, ext_model_result, pop_decision, dup_result, can_freeze)
% PED_EXT.GATE12_REPORT  Generate summary report and manuscript update map.

out_dir = fullfile(ext_dir,'11_report');
figs_dir = fullfile(ext_dir,'figures_staging');

% ── Extension summary markdown ────────────────────────────────────────────
fmd = fopen(fullfile(out_dir,'PED_TARGETED_EXTENSION_SUMMARY.md'),'w');
fprintf(fmd,'# PED Targeted Extension Summary\n\n');
fprintf(fmd,'**Run:** `%s`\n\n', ext_run_id);
fprintf(fmd,'**Canonical:** `run_20260903_155408` | Seed 42 | V5_CORRECTED_REANALYSIS\n\n');

n_pass = sum(cellfun(@(r) isstruct(r) && strcmp(char(r.status),'PASS'), gate_results));
if n_pass==13 && can_freeze; ov_str='PASS'; else; ov_str='FAIL'; end
fprintf(fmd,'**Overall: %s (%d/13 gates PASS)**\n\n', ...
    ov_str, n_pass); if n_pass==13 && can_freeze; ov_str='PASS'; else; ov_str='FAIL'; end

fprintf(fmd,'## Gate Summary\n\n| Gate | Status | Notes |\n|---|---|---|\n');
gates = {'EXT_GATE_0','EXT_GATE_1','EXT_GATE_2','EXT_GATE_3','EXT_GATE_4',...
         'EXT_GATE_5','EXT_GATE_6','EXT_GATE_7','EXT_GATE_8','EXT_GATE_9',...
         'EXT_GATE_10','EXT_GATE_11','EXT_GATE_12'};
for gi=1:13
    fprintf(fmd,'| %s | %s | %s |\n', gates{gi}, gate_results(gi), char(gate_results{gi}.message));
end

% Duplicate result
if ~isempty(dup_result) && isstruct(dup_result)
    fprintf(fmd,'\n## Duplicate Forensic (EXT_GATE_1)\n\n');
    cc = dup_result.class_counts;
    fprintf(fmd,'| Class | Count |\n|---|---|\n');
    fns = fieldnames(cc);
    for fi=1:numel(fns)
        fprintf(fmd,'| %s | %d |\n', fns{fi}, cc.(fns{fi}));
    end
end

% Population decision
if ~isempty(pop_decision)
    fprintf(fmd,'\n## Population Decision (EXT_GATE_2)\n\n');
    fprintf(fmd,'**Condition %s** — %s\n\n', pop_decision.condition, pop_decision.notes);
    fprintf(fmd,'Full Well-B valid for sensitivity: **%s**\n\n', ...
        string(pop_decision.full_b_valid));
end

% Corrected holdout
if ~isempty(holdout_result) && isstruct(holdout_result) && isfield(holdout_result,'r2')
    fprintf(fmd,'\n## Corrected Holdout (EXT_GATE_5)\n\n');
    fprintf(fmd,'| Metric | Value |\n|---|---|\n');
    fprintf(fmd,'| R² | %.4f |\n', holdout_result.r2);
    fprintf(fmd,'| RMSE | %.4f km/s |\n', holdout_result.rmse);
    fprintf(fmd,'| Classification | %s |\n', holdout_result.classification);
    fprintf(fmd,'| Historical R² (provenance) | %.4f |\n', holdout_result.historical_r2);
end

% External models
if ~isempty(ext_model_result) && isstruct(ext_model_result)
    fprintf(fmd,'\n## External Models (EXT_GATE_6)\n\n');
    fprintf(fmd,'**Verdict: %s**\n\n', ext_model_result.verdict);
    if ~isempty(ext_model_result.T_metrics)
        T = ext_model_result.T_metrics;
        fprintf(fmd,'| Model | Status | Pop-A R² |\n|---|---|---|\n');
        for ri=1:height(T)
            r2v = T.R2(ri);
            if isnumeric(r2v) && isfinite(r2v)
                fprintf(fmd,'| %s | %s | %.4f |\n', T.MODEL(ri), T.ANALYSIS_STATUS(ri), r2v);
            else
                fprintf(fmd,'| %s | %s | N/A |\n', T.MODEL(ri), T.ANALYSIS_STATUS(ri));
            end
        end
    end
end
fclose(fmd);

% ── Manuscript update map ─────────────────────────────────────────────────
fmap = fopen(fullfile(out_dir,'PED_MANUSCRIPT_UPDATE_MAP.md'),'w');
fprintf(fmap,'# Manuscript Update Map\n\n');
fprintf(fmap,'Maps EXT_GATE results to manuscript sections requiring update.\n\n');

fprintf(fmap,'## Abstract\n- Update if holdout classification changes three-level hierarchy claim\n');
fprintf(fmap,'- Retain: pooled CV R²=0.6632, Pop-A R²=-2.6162, Pop-B R²=-5.2708\n\n');

fprintf(fmap,'## Methods\n');
fprintf(fmap,'- EXT_GATE_3: Add architecture provenance table\n');
fprintf(fmap,'- EXT_GATE_4: Add CNN boundary audit statement\n');
fprintf(fmap,'- EXT_GATE_5: Clarify holdout is provenance, not v5 nested-CV test set\n');
fprintf(fmap,'- EXT_GATE_10: Replace "stable isotropic media" with "application-specific sedimentary-rock screen"\n');
fprintf(fmap,'- EXT_GATE_10: Add Vp formula: Vp (km/s) = 304.8 / DT (µs/ft)\n');
fprintf(fmap,'- EXT_GATE_10: Add unit statement: rho (g/cm3) × V² (km/s)² = GPa\n\n');

fprintf(fmap,'## Results\n');
fprintf(fmap,'- EXT_GATE_1: Clarify 163-row classification (confirmed or revised)\n');
fprintf(fmap,'- EXT_GATE_5: Add corrected holdout R² if positive (recovery) or negative (confirms three-level)\n');
fprintf(fmap,'- EXT_GATE_6: Add external predictions for all base learners\n');
fprintf(fmap,'- EXT_GATE_7: Add Full Well-B sensitivity if condition B\n');
fprintf(fmap,'- EXT_GATE_8: Add DT interpretation limits paragraph\n\n');

fprintf(fmap,'## Discussion\n');
fprintf(fmap,'- EXT_GATE_5: Reconcile historical holdout R²=-3.0622\n');
fprintf(fmap,'- EXT_GATE_6: Discuss whether failure is model-specific or universal\n');
fprintf(fmap,'- EXT_GATE_9: Add paired bootstrap supporting Direct Ridge vs stacker difference\n');
fprintf(fmap,'- EXT_GATE_10: Change "Geomechanical Consequences" to "Physical-Admissibility Consequences" if no wellbore calc\n\n');

fprintf(fmap,'## Figures\n');
fprintf(fmap,'- PED_FIG_VALIDATION_HIERARCHY: new figure (CV / same-well holdout / cross-well)\n');
fprintf(fmap,'- PED_FIG_EXTERNAL_ALL_MODELS: new figure (all base learners external)\n');
fprintf(fmap,'- PED_FIG_DT_SUPPORT: DT distribution with source support boundaries\n\n');

fprintf(fmap,'## Do NOT change\n');
fprintf(fmap,'- Canonical numerical results from run_20260903_155408\n');
fprintf(fmap,'- Primary analysis: Ridge stacker is pre-specified confirmatory model\n');
fprintf(fmap,'- Direct Ridge: always POST_HOC_EXPLORATORY\n');
fclose(fmap);

% ── Figure source CSVs (stub — populated from actual gate results) ─────────
% PED_FIG_VALIDATION_HIERARCHY
% Build validation hierarchy figure source data safely
hier_levels = {'Nested_CV','Same_well_holdout','Cross_well_PopA'};
hier_descs  = {'Development_interval','Contiguous_depth_extrapolation','External_transfer'};
hr2 = holdout_result_r2(holdout_result);
hier_r2 = [0.6632; hr2; -2.6162];
T_hier = table(string(hier_levels(:)), string(hier_descs(:)), hier_r2, ...
    'VariableNames',{'LEVEL','DESCRIPTION','R2'});
writetable(T_hier, fullfile(figs_dir,'PED_FIG_VALIDATION_HIERARCHY_source.csv'));

fprintf('    Report and figure source data written\n');
end

function r2 = holdout_result_r2(hr)
if isstruct(hr) && isfield(hr,'r2') && isfinite(hr.r2)
    r2 = hr.r2;
else
    r2 = NaN;
end
end

function s = ternary_pass(is_pass)
if is_pass; s='PASS'; else; s='FAIL'; end
end

function s = get_status(r)
if isstruct(r); s = char(r.status); else; s = 'PENDING'; end
end

function s = get_code(r)
if isstruct(r); s = char(r.code); else; s = 'PENDING'; end
end

function s = get_msg(r)
if isstruct(r); s = char(r.message); else; s = ''; end
end
