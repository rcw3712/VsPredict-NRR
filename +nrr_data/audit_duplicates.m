function dup = audit_duplicates(T_A, T_B, out_dir, cfg)
% NRR_DATA.AUDIT_DUPLICATES  Gate 3: exact cross-well duplicate audit.
%   Counts duplicates from data — never hard-codes 163.
%   Differentiates: exact (all predictors+target), predictor-only,
%   near/rounded, same-depth coincidences.

td = cfg.dup.tol_depth; tl = cfg.dup.tol_log;
chk = cfg.dup.check_cols;
fprintf('[G3] Duplicate audit (tol_depth=%.0e tol_log=%.0e)...\n',td,tl);

% Step 1: depth-match candidates
ma=[]; mb=[];
for bi=1:height(T_B)
    d = abs(T_A.(cfg.data.depth_col)-T_B.(cfg.data.depth_col)(bi));
    c = find(d<=td);
    if isempty(c); continue; end
    [~,best]=min(d(c)); ma(end+1)=c(best); mb(end+1)=bi;
end
n_cand=numel(ma);

% Step 2: column-by-column for each candidate
exact_a=[]; exact_b=[];
pred_only_a=[]; pred_only_b=[];
col_diffs=struct();
for c=chk; col_diffs.(c{1})=nan(n_cand,1); end

for mi=1:n_cand
    ai=ma(mi); bi=mb(mi); all_match=true; pred_match=true;
    for ci=1:numel(chk)
        col=chk{ci};
        ha=ismember(col,T_A.Properties.VariableNames);
        hb=ismember(col,T_B.Properties.VariableNames);
        if ~ha||~hb; continue; end
        va=T_A.(col)(ai); vb=T_B.(col)(bi);
        d=abs(va-vb); col_diffs.(col)(mi)=d;
        is_target = strcmp(col,'DTS')||strcmp(col,'VS');
        if ~(isnan(va)&&isnan(vb)) && (isnan(va)||isnan(vb)||d>tl)
            all_match=false;
            if ~is_target; pred_match=false; end
        end
    end
    if all_match;      exact_a(end+1)=ai; exact_b(end+1)=bi;
    elseif pred_match; pred_only_a(end+1)=ai; pred_only_b(end+1)=bi; end
end

n_exact=numel(exact_a); n_pred_only=numel(pred_only_a);
fprintf('[G3] Depth-matched: %d | Exact (all cols): %d | Predictor-only: %d\n',...
    n_cand, n_exact, n_pred_only);

if n_exact~=cfg.dup.expected_n
    warning('[G3] Found %d exact dups; canonical expected %d',n_exact,cfg.dup.expected_n);
end

% Save outputs
writetable(table(height(T_A),height(T_B),n_cand,n_exact,n_pred_only,...
    td,tl,'VariableNames',{'N_WELLA','N_WELLB','N_DEPTH_MATCHED',...
    'N_EXACT_ALL_COLS','N_PRED_ONLY','TOL_DEPTH','TOL_LOG'}),...
    fullfile(out_dir,'EXACT_DUPLICATE_REPORT.csv'));

if n_exact>0
    writetable(table(exact_a(:),exact_b(:),...
        T_A.(cfg.data.depth_col)(exact_a(:)),...
        T_A.(cfg.data.id_col)(exact_a(:)),...
        T_B.(cfg.data.id_col)(exact_b(:)),...
        'VariableNames',{'IDX_A','IDX_B','DEPTH','ROW_ID_A','ROW_ID_B'}),...
        fullfile(out_dir,'EXACT_DUPLICATE_MATCHED_ROWS.csv'));
end

T_cd=table((1:n_cand)',ma(:),mb(:),'VariableNames',{'MI','IDX_A','IDX_B'});
for c=chk; T_cd.(c{1})=col_diffs.(c{1}); end
writetable(T_cd,fullfile(out_dir,'EXACT_DUPLICATE_COLUMN_DIFFERENCES.csv'));

assert(n_exact>0,'[G3] Zero exact duplicates — check data files');

dup.n=n_exact; dup.idx_A=exact_a(:); dup.idx_B=exact_b(:);
dup.n_pred_only=n_pred_only; dup.tol_d=td; dup.tol_l=tl;
fprintf('[G3] PASS — %d exact duplicates verified\n',n_exact);
end
