function root = nrr_project_root()
% NRR_PROJECT_ROOT  Return absolute path to VsPredict_NRR_v5 root.
%   Works from any working directory. Based on this file's location.
this_dir = fileparts(mfilename('fullpath'));   % figure_scripts/
root     = fileparts(this_dir);               % VsPredict_NRR_v5/
assert(isfolder(root), 'nrr_project_root: computed root not found: %s', root);
end
