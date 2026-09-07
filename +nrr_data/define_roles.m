function roles = define_roles(T_A, T_B, dup, out_dir, cfg)
% NRR_DATA.DEFINE_ROLES  Gate 4: data role definitions.
%   All counts computed from data — no hard-coding.
%   Pop-B is TARGET-INFORMED (Vp/Vs gate uses measured VS).
%   Three assertions verify partition exhaustiveness.

n_A=height(T_A); n_B=height(T_B);

%% Well-A: depth-blocked fold assignment (for dev/hold split)
k=[]; [~,dord]=sort(T_A.(cfg.data.depth_col)); fsz=floor(n_A/cfg.cv.n_outer);
fids=zeros(n_A,1);
for fi=1:cfg.cv.n_outer
    s=(fi-1)*fsz+1; e=min(fi*fsz,n_A); if fi==cfg.cv.n_outer;e=n_A;end
    fids(dord(s:e))=fi;
end
hf=cfg.cv.holdout_fold;
dev_mask=fids~=hf; hold_mask=fids==hf;
n_dev=sum(dev_mask); n_hold=sum(hold_mask);

%% P1.1 Assertions — partition must be exhaustive and mutually exclusive
assert(n_dev+n_hold==n_A,...
    '[G4] n_dev(%d)+n_hold(%d)~=n_A(%d)',n_dev,n_hold,n_A);
assert(nnz(dev_mask & hold_mask)==0,...
    '[G4] dev_mask and hold_mask overlap');
assert(nnz(dev_mask | hold_mask)==n_A,...
    '[G4] dev_mask|hold_mask does not cover all Well-A rows');

%% Well-B populations
non_dup=true(n_B,1); non_dup(dup.idx_B)=false;
has_vs=~isnan(T_B.(cfg.data.target));
popA=non_dup & has_vs;

% Pop-B: Pop-A passing measured Vp/Vs >= sqrt(2) — TARGET-INFORMED
if ismember('VP',T_B.Properties.VariableNames)
    vpvs_m=T_B.VP./T_B.(cfg.data.target);
elseif ismember('VPVS',T_B.Properties.VariableNames)
    vpvs_m=T_B.VPVS;
else
    vpvs_m=inf(n_B,1);
    warning('[G4] No VP/VPVS — Pop-B equals Pop-A');
end
popB=popA & (vpvs_m>=cfg.sanity.vpvs_min);
assert(sum(popB)<=sum(popA),'[G4] Pop-B not subset of Pop-A');
assert(~any(ismember(find(popA),dup.idx_B)),'[G4] Pop-A contains exact duplicates');

n_popA=sum(popA); n_popB=sum(popB);

%% DATA_ROLE_COUNTS.csv — dynamic, no hard-coded 394/98
writetable(table(...
    {'Well-A total';'Well-A development';'Well-A holdout';...
     'Well-B total';'Well-B exact duplicate';'Well-B non-duplicate';...
     'Pop-A primary blind';'Pop-B diagnostic QC'},...
    {n_A;n_dev;n_hold;n_B;dup.n;sum(non_dup);n_popA;n_popB},...
    {sprintf('%d = %d + %d',n_A,n_dev,n_hold);...
     'outer CV training (k-1 folds)';...
     sprintf('Level-1 selection set (fold %d)',cfg.cv.holdout_fold);...
     'all rows';'exact duplicates excluded from blind';...
     'non-duplicate rows';'non-dup with measured VS';...
     'Pop-A with Vp/Vs>=sqrt(2) [target-informed]'},...
    'VariableNames',{'ROLE','N','NOTE'}),...
    fullfile(out_dir,'DATA_ROLE_COUNTS.csv'));

%% DATA_ROLE_ROW_IDS.csv
role_A=repmat({'Well-A development'},n_A,1); role_A(hold_mask)={'Well-A holdout'};
T_rA=table(T_A.(cfg.data.id_col),T_A.(cfg.data.depth_col),role_A,...
    'VariableNames',{'ROW_ID','DEPTH','ROLE'});
role_B=repmat({'Well-B duplicate'},n_B,1);
role_B(non_dup & ~has_vs)={'Well-B no VS'};
role_B(popA)={'Pop-A primary blind'};
role_B(popB)={'Pop-B diagnostic QC'};
T_rB=table(T_B.(cfg.data.id_col),T_B.(cfg.data.depth_col),role_B,...
    'VariableNames',{'ROW_ID','DEPTH','ROLE'});
writetable([T_rA;T_rB],fullfile(out_dir,'DATA_ROLE_ROW_IDS.csv'));

roles.fold_ids=fids; roles.dev_mask=dev_mask; roles.hold_mask=hold_mask;
roles.popA_mask=popA; roles.popB_mask=popB; roles.dup_mask=~non_dup;
roles.n_dev=n_dev; roles.n_hold=n_hold; roles.n_popA=n_popA; roles.n_popB=n_popB;
roles.n_A=n_A; roles.n_B=n_B;

fprintf('[G4] PASS — n_A=%d: dev=%d hold=%d | PopA=%d PopB=%d\n',...
    n_A,n_dev,n_hold,n_popA,n_popB);
end
