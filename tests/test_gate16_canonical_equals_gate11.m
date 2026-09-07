function result = test_gate16_canonical_equals_gate11()
% TEST: Gate 16 seed=42 must produce identical predictions to Gate 12.
f=fullfile('runs','CANONICAL_RUN_POINTER.txt');
if ~isfile(f)
    result=struct('name','test_gate16_canonical_equals_gate11','status','FAIL',...
        'message','No canonical run'); return
end
T=readtable(f,'ReadVariableNames',false); run_id=strtrim(string(T{1,1})); run_id=run_id(1);
g12=fullfile('runs',run_id,'04_blind','PRIMARY_BLIND_ROW_PREDICTIONS.csv');
g16=fullfile('runs',run_id,'04_blind','MULTISEED_EXACT_PIPELINE_METRICS.csv');
if ~isfile(g12)||~isfile(g16)
    result=struct('name','test_gate16_canonical_equals_gate11','status','FAIL',...
        'message','CSV not found'); return
end
T12=readtable(g12); T16=readtable(g16);
canon=T16(T16.IS_CANONICAL==1,:);
if height(canon)==0
    result=struct('name','test_gate16_canonical_equals_gate11','status','FAIL',...
        'message','No canonical row in MULTISEED'); return
end
is_popa = logical(T12.IS_POPA);
r2_g12=1-sum((T12.VS_measured(is_popa)-T12.VS_pred_raw(is_popa)).^2)/...
    sum((T12.VS_measured(is_popa)-mean(T12.VS_measured(is_popa))).^2);
assert(abs(r2_g12-canon.R2_POPA(1))<1e-4,...
    'G12 PopA R2=%.4f vs G16 seed42 PopA R2=%.4f (diff=%.2e)',...
    r2_g12,canon.R2_POPA(1),abs(r2_g12-canon.R2_POPA(1)));
result=struct('name','test_gate16_canonical_equals_gate11','status','PASS',...
    'message',sprintf('max_diff=%.2e',abs(r2_g12-canon.R2_POPA(1))));
end
