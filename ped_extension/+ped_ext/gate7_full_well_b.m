function result_out = gate7_full_well_b(ctx, pop_decision, ext_dir)
% PED_EXT.GATE7_FULL_WELL_B  Full Well-B sensitivity (conditional on Gate 2).

out_dir = fullfile(ext_dir, '06_full_b_sensitivity');
result_out = struct('status',string('SKIPPED_BY_VALID_DECISION'),'code',string('SKIPPED_BY_VALID_DECISION'),'message',string('Not yet determined'),'required',false,'evidence_path',string(out_dir),'n_checks',0,'n_pass',0);

% ── Check if Full Well-B is valid ─────────────────────────────────────────
if isempty(pop_decision) || ~isstruct(pop_decision)
    fprintf('    BLOCKED: pop_decision not available (Gate 2 failed)\n');
    result_out = struct('status',string('BLOCKED'),'code',string('BLOCKED_GATE2_FAILED'),...
        'message',string('Gate 2 population decision not available'),'required',false,...
        'evidence_path',string(out_dir),'n_checks',0,'n_pass',0);
    return;
end

if ~pop_decision.full_b_valid
    fprintf('    SKIPPED: Full Well-B not valid for sensitivity\n');
    fprintf('    Condition %s: %s\n', pop_decision.condition, pop_decision.notes);
    write_status(out_dir, sprintf('SKIPPED_CONDITION_%s', pop_decision.condition), ...
        pop_decision.full_b_status);
    result_out.message=string(sprintf(['Condition %s: Full Well-B sensitivity excluded because ' ...
        '%d predictor-and-target-exact shared rows would mix duplicated evidence into the sensitivity set'], ...
        pop_decision.condition,ctx.n_shared));
    result_out.n_checks=1; result_out.n_pass=1;
    return;
end

% ── Condition B: Full Well-B is valid sensitivity ─────────────────────────
fprintf('    Condition B confirmed — computing Full Well-B sensitivity\n');

% Load predictions for all Well-B rows
T = ctx.predictions;
if isempty(T)
    write_status(out_dir, 'BLOCKED_NO_PREDICTIONS', 'No prediction table');
    return;
end

% Full Well-B = all Well-B rows (492) including the 163 depth-matched
% Primary model predictions should be available for all Well-B rows
cn = T.Properties.VariableNames;
pred_col = '';
for ci=1:numel(cn)
    if contains(lower(cn{ci}),'pred') && contains(lower(cn{ci}),'raw')
        pred_col = cn{ci}; break;
    end
end

if isempty(pred_col)
    write_status(out_dir, 'BLOCKED_NO_PRED_COL', 'Prediction column not found');
    return;
end

% All Well-B rows with measured VS
meas_col = '';
for ci=1:numel(cn)
    if any(strcmpi(cn{ci},{'VS_measured','VS_MEASURED','VS','Vs_meas'}))
        meas_col = cn{ci}; break;
    end
end

if isempty(meas_col)
    write_status(out_dir, 'BLOCKED_NO_MEAS_COL', 'Measured VS column not found');
    return;
end

y_true = T.(meas_col);
y_pred = T.(pred_col);
ok = isfinite(y_true) & isfinite(y_pred);

if sum(ok) < 10
    write_status(out_dir, 'BLOCKED_INSUFFICIENT_ROWS', sprintf('Only %d valid rows', sum(ok)));
    return;
end

r2_fullb   = 1 - sum((y_true(ok)-y_pred(ok)).^2)/sum((y_true(ok)-mean(y_true(ok))).^2);
rmse_fullb = sqrt(mean((y_true(ok)-y_pred(ok)).^2));
bias_fullb = mean(y_pred(ok)-y_true(ok));
n_fullb    = sum(ok);

fprintf('    Full Well-B (n=%d): R²=%.4f RMSE=%.4f Bias=%.4f\n', ...
    n_fullb, r2_fullb, rmse_fullb, bias_fullb);

T_met = table(...
    string({'model','population','status','n','R2','RMSE_km_s','Bias_km_s'}),...
    string({'Ridge_stacker','Full_Well_B','FULL_WELL_B_SENSITIVITY',...
            num2str(n_fullb),num2str(r2_fullb,'%.4f'),...
            num2str(rmse_fullb,'%.4f'),num2str(bias_fullb,'%.4f')}),...
    'VariableNames',{'PARAMETER','VALUE'});
writetable(T_met, fullfile(out_dir,'PED_FULL_WELL_B_SENSITIVITY_METRICS.csv'));

fmd = fopen(fullfile(out_dir,'PED_FULL_WELL_B_SENSITIVITY_STATUS.md'),'w');
fprintf(fmd,'# Full Well-B Sensitivity\n\nStatus: FULL_WELL_B_SENSITIVITY (Condition B)\n\n');
fprintf(fmd,'| n | R² | RMSE | Bias |\n|---|---|---|---|\n');
fprintf(fmd,'| %d | %.4f | %.4f | %.4f |\n', n_fullb, r2_fullb, rmse_fullb, bias_fullb);
fclose(fmd);
result_out=struct('status',string('PASS'),'code',string('OK'), ...
    'message',string(sprintf('Full Well-B sensitivity completed on %d rows',n_fullb)), ...
    'required',false,'evidence_path',string(out_dir),'n_checks',1,'n_pass',1, ...
    'r2',r2_fullb,'rmse',rmse_fullb,'bias',bias_fullb);
end

function write_status(out_dir, status, notes)
% Write CSV
T = table(string({status}), string({notes}), 'VariableNames',{'STATUS','NOTES'});
writetable(T, fullfile(out_dir,'PED_FULL_WELL_B_SENSITIVITY_STATUS.csv'));
% Write MD as text
fmd = fopen(fullfile(out_dir,'PED_FULL_WELL_B_SENSITIVITY_STATUS.md'),'w');
fprintf(fmd,'# Full Well-B Sensitivity\n\nStatus: %s\nNotes: %s\n', status, notes);
fclose(fmd);
end
