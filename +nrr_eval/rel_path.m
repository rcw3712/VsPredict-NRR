function rel = rel_path(fp, root)
% NRR_EVAL.REL_PATH  Normalize path to relative with forward slashes.
%   Removes root prefix, converts backslashes, strips leading separators.
rel = erase(string(fp), string(root));
rel = replace(rel, '\', '/');
rel = regexprep(rel, '^/+', '');
rel = char(rel);
end
