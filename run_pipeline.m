% RUN_PIPELINE.M  Entry point — VsPredict_NRR_v5 canonical run (seed=42).
%
% Usage (MATLAB, from VsPredict_NRR_v5 directory):
%   >> clear classes
%   >> run_pipeline
%
% For non-canonical seed (testing only):
%   >> main_nrr_pipeline(pwd, 'seed', 7)

here = fileparts(mfilename('fullpath'));
run  = main_nrr_pipeline(here);
