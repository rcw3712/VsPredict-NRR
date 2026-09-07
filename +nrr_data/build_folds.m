function [folds, fold_hash] = build_folds(T, n_folds, cfg)
% NRR_DATA.BUILD_FOLDS  Build depth-blocked folds. Used for outer and inner.
%   All rows must appear in exactly one val set.
%   val ∩ train = ∅ asserted per fold.
n=[]; [~,dord]=sort(T.(cfg.data.depth_col)); n=height(T);
fsz=floor(n/n_folds); folds=repmat(struct(),1,n_folds);
for fi=1:n_folds
    s=(fi-1)*fsz+1; e=min(fi*fsz,n); if fi==n_folds;e=n;end
    vi=dord(s:e); ti=dord(setdiff(1:n,s:e));
    folds(fi).val_idx=sort(vi(:)); folds(fi).train_idx=sort(ti(:));
    folds(fi).val_ids=T.(cfg.data.id_col)(sort(vi(:)));
    folds(fi).train_ids=T.(cfg.data.id_col)(sort(ti(:)));
    folds(fi).n_val=numel(vi); folds(fi).n_train=numel(ti);
    folds(fi).depth_min=T.(cfg.data.depth_col)(folds(fi).val_idx(1));
    folds(fi).depth_max=T.(cfg.data.depth_col)(folds(fi).val_idx(end));
    assert(isempty(intersect(folds(fi).val_idx,folds(fi).train_idx)),...
        'build_folds: fold %d val/train overlap',fi);
end
all_v=vertcat(folds.val_idx);
assert(numel(unique(all_v))==n && numel(all_v)==n,...
    'build_folds: not all rows covered exactly once');
fold_hash=sprintf('n=%d,k=%d,sum=%d,dmin=%.2f,dmax=%.2f',...
    n,n_folds,sum(all_v),...
    T.(cfg.data.depth_col)(dord(1)),...
    T.(cfg.data.depth_col)(dord(end)));
end
