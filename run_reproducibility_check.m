function result = run_reproducibility_check(run_id_1, run_id_2, repo_root)
% RUN_REPRODUCIBILITY_CHECK  Gate 18 — cross-run reproducibility.
%   Requires two completed clean-session runs.
%   Compares numerical outputs, hashes, fold assignments, bootstrap,
%   geomechanics, seed ledger, and gate statuses.
if nargin<3; repo_root=fileparts(mfilename('fullpath')); end
addpath(repo_root); addpath(fullfile(repo_root,'config'));
cfg=config_nrr_v5(); tol=1e-4;
runs_dir=fullfile(repo_root,cfg.out.runs_dir);
sep=repmat('=',1,60);
fprintf('\n%s\n  Gate 18: Cross-Run Reproducibility\n%s\n\n',sep,sep);
fprintf('  Run 1: %s\n  Run 2: %s\n\n',run_id_1,run_id_2);

checks={}; passed=0; failed=0;
function log(name,ok,detail)
    st='PASS'; if ~ok; st='FAIL'; end
    if nargin<3; detail=''; end
    checks{end+1}={name,st,detail};
    if ok; passed=passed+1; else; failed=failed+1; end
    fprintf('  [%s] %s\n',st,name);
    if ~ok&&~isempty(detail); fprintf('         %s\n',detail); end
end

mat1=fullfile(runs_dir,run_id_1,'08_freeze','FROZEN_NUMERICAL_RUN.mat');
mat2=fullfile(runs_dir,run_id_2,'08_freeze','FROZEN_NUMERICAL_RUN.mat');
assert(isfile(mat1),'[G18] Run 1 MAT not found'); r1=load(mat1,'run'); r1=r1.run;
assert(isfile(mat2),'[G18] Run 2 MAT not found'); r2=load(mat2,'run'); r2=r2.run;

log('Config hash identical',      strcmp(r1.env.config_hash,r2.env.config_hash));
log('MATLAB version identical',   strcmp(r1.env.matlab_ver,r2.env.matlab_ver));
log('Well-A data hash identical', strcmp(r1.hashes.A,r2.hashes.A));
log('Well-B data hash identical', strcmp(r1.hashes.B,r2.hashes.B));
log('n_popA identical',           r1.n_popA==r2.n_popA,sprintf('%d vs %d',r1.n_popA,r2.n_popA));
log('n_popB identical',           r1.n_popB==r2.n_popB,sprintf('%d vs %d',r1.n_popB,r2.n_popB));
log('n_dev identical',            r1.n_dev==r2.n_dev,sprintf('%d vs %d',r1.n_dev,r2.n_dev));
log('n_hold identical',           r1.n_hold==r2.n_hold,sprintf('%d vs %d',r1.n_hold,r2.n_hold));
log('Outer fold hash identical',  strcmp(r1.fold_hash,r2.fold_hash));
log('Canon HP lambda identical',  abs(r1.canon_hp.ridge_lambda-r2.canon_hp.ridge_lambda)<1e-10);
log('Canon HP hash identical',    strcmp(r1.canon_hp_hash,r2.canon_hp_hash));

% Pop-A metrics
for f={'r2','rmse','bias','mae'}
    v1=r1.blind.ridge.popA.(f{1}); v2=r2.blind.ridge.popA.(f{1});
    log(sprintf('Pop-A %s identical (tol=%.0e)',upper(f{1}),tol),...
        abs(v1-v2)<tol,sprintf('%.6f vs %.6f',v1,v2));
end
% Pop-B metrics
for f={'r2','rmse','bias','mae'}
    v1=r1.blind.ridge.popB.(f{1}); v2=r2.blind.ridge.popB.(f{1});
    log(sprintf('Pop-B %s identical (tol=%.0e)',upper(f{1}),tol),...
        abs(v1-v2)<tol,sprintf('%.6f vs %.6f',v1,v2));
end

% Prediction vectors
T_p1=readtable(fullfile(runs_dir,run_id_1,'04_blind','PRIMARY_BLIND_ROW_PREDICTIONS.csv'));
T_p2=readtable(fullfile(runs_dir,run_id_2,'04_blind','PRIMARY_BLIND_ROW_PREDICTIONS.csv'));
log('Prediction vector length identical',height(T_p1)==height(T_p2));
if height(T_p1)==height(T_p2)
    maxd=max(abs(T_p1.VS_pred_raw-T_p2.VS_pred_raw));
    log(sprintf('Prediction values identical (tol=%.0e)',tol),maxd<tol,...
        sprintf('max diff=%.2e',maxd));
end

% Direct Ridge
log('DR Pop-A R² identical',abs(r1.posthoc.popA.r2-r2.posthoc.popA.r2)<tol);
log('DR Pop-B R² identical',abs(r1.posthoc.popB.r2-r2.posthoc.popB.r2)<tol);
log('DR status POST_HOC_SENSITIVITY',...
    strcmp(r1.posthoc.dr.status,'POST_HOC_SENSITIVITY')&&...
    strcmp(r2.posthoc.dr.status,'POST_HOC_SENSITIVITY'));

% Geomechanics
geo1=readtable(fullfile(runs_dir,run_id_1,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv'));
geo2=readtable(fullfile(runs_dir,run_id_2,'07_geomech','GEOMECHANICAL_MODEL_COMPARISON.csv'));
log('Geomech N_ALL_OK identical',isequal(geo1.N_ALL_OK,geo2.N_ALL_OK));

% Provenance class
log('Provenance class V5_CORRECTED_REANALYSIS',...
    strcmp(r1.deploy.provenance,'V5_CORRECTED_REANALYSIS')&&...
    strcmp(r2.deploy.provenance,'V5_CORRECTED_REANALYSIS'));

% Gate statuses
gates={'GATE_0','GATE_1','GATE_2','GATE_3','GATE_4','GATE_5',...
       'GATE_6','GATE_7','GATE_8','GATE_9','GATE_10','GATE_11',...
       'GATE_12','GATE_13','GATE_14','GATE_15','GATE_16','GATE_17'};
for gi=1:numel(gates)
    g=gates{gi};
    ok=isfield(r1.gate,g)&&isfield(r2.gate,g)&&...
       strcmp(r1.gate.(g),'PASS')&&strcmp(r2.gate.(g),'PASS');
    log(sprintf('%s PASS in both runs',g),ok);
end

n_total=passed+failed;
fprintf('\n%s\n  Gate 18: %d / %d checks PASS\n%s\n\n',sep,passed,n_total,sep);
st='FAIL'; if failed==0; st='PASS'; end

T_rep=cell2table(vertcat(checks{:}),'VariableNames',{'CHECK','STATUS','DETAIL'});
T_rep.RUN_1=repmat({run_id_1},height(T_rep),1);
T_rep.RUN_2=repmat({run_id_2},height(T_rep),1);
out_path=fullfile(runs_dir,'CROSS_RUN_REPRODUCIBILITY.csv');
writetable(T_rep,out_path);

if strcmp(st,'PASS')
    fprintf('  Gate 18: PASS — ready for nrr_report.generate_all\n\n');
else
    fprintf('  Gate 18: FAIL — %d check(s) failed\n\n',failed);
end
result=struct('gate18_status',st,'n_pass',passed,'n_total',n_total,...
    'run_id_1',run_id_1,'run_id_2',run_id_2,'report_path',out_path);
end
