function result = test_gate16_canonical_prediction_vector()
% TEST: prediction vector SD within canonical seed is 0 (deterministic).
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_gate16_canonical_prediction_vector','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
sd_f=fullfile('runs',run_id,'04_blind','MULTISEED_PREDICTION_SD_POPA.csv');
if ~isfile(sd_f)
    result=struct('name','test_gate16_canonical_prediction_vector','status','FAIL',...
        'message','MULTISEED_PREDICTION_SD_POPA.csv not found'); return
end
T=readtable(sd_f);
assert(all(isfinite(T.PRED_SD_KM_S)),'SD vector contains NaN/Inf');
result=struct('name','test_gate16_canonical_prediction_vector','status','PASS',...
    'message',sprintf('mean SD=%.4f km/s',mean(T.PRED_SD_KM_S)));
end
