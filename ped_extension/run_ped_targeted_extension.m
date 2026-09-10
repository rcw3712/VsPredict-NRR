% RUN_PED_TARGETED_EXTENSION  Entry point for PED targeted extension.
%
% Usage — from VsPredict_NRR_v5 project root:
%   addpath('PED_Extension')
%   run_ped_targeted_extension
%
% To force a specific canonical run ID:
%   run_ped_targeted_extension('run_20260903_155408')
%
% Clean-session reproducibility check:
%   clear; clc; run_ped_targeted_extension

function run_ped_targeted_extension(varargin)

CANONICAL_RUN_ID = 'run_20260903_155408';
if nargin >= 1; CANONICAL_RUN_ID = varargin{1}; end

fprintf('\n%s\n  PED TARGETED EXTENSION\n  Canonical: %s\n%s\n\n', ...
    repmat('=',1,60), CANONICAL_RUN_ID, repmat('=',1,60));

% Determine project root from this file's location
this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir); this_dir = pwd; end

% Project root is parent of this extension folder (if running from subdir)
% or the VsPredict_NRR_v5 directory itself
% Search for project root containing the canonical run
search_dirs = {this_dir, fileparts(this_dir), pwd, ...
    fullfile(this_dir,'..'), fullfile(pwd,'..'), ...
    'C:\Drive E\VsPredict_NRR_v5', ...
    'C:\Drive E\Machine Learning\BLU 2026\Hasil\VsPredict_NRR_v5'};
project_root = '';
for i = 1:numel(search_dirs)
    candidate = search_dirs{i};
    if isempty(candidate); continue; end
    if isfolder(fullfile(candidate,'runs',CANONICAL_RUN_ID))
        project_root = candidate;
        fprintf('    Project root: %s\n', project_root);
        break;
    end
end
if isempty(project_root)
    % Last resort: search from pwd upward
    d = pwd;
    for k=1:5
        if isfolder(fullfile(d,'runs',CANONICAL_RUN_ID))
            project_root = d; break;
        end
        d = fileparts(d);
    end
end
assert(~isempty(project_root), ...
    'Cannot find project root containing runs/%s. cd to VsPredict_NRR_v5 first.', ...
    CANONICAL_RUN_ID);

addpath(genpath(this_dir));
addpath(genpath(project_root));

main_ped_targeted_extension(project_root, CANONICAL_RUN_ID);
end
