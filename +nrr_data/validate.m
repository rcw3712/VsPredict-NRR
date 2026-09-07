function validate(T_A, T_B, cfg)
% NRR_DATA.VALIDATE  Gate 2: schema and value-range integrity.
assert(issorted(T_A.(cfg.data.depth_col)),'[G2] Well-A DEPTH not sorted');
assert(issorted(T_B.(cfg.data.depth_col)),'[G2] Well-B DEPTH not sorted');
assert(numel(unique(T_A.(cfg.data.id_col)))==height(T_A),'[G2] Well-A ROW_ID not unique');
assert(numel(unique(T_B.(cfg.data.id_col)))==height(T_B),'[G2] Well-B ROW_ID not unique');
pct_vs = mean(~isnan(T_A.(cfg.data.target)))*100;
assert(pct_vs>80,'[G2] Well-A VS too sparse: %.1f%% valid', pct_vs);
fprintf('[G2] Well-A %d rows (%.0f%% VS) | Well-B %d rows\n', height(T_A), pct_vs, height(T_B));
end
