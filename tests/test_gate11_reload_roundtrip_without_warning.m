function result = test_gate11_reload_roundtrip_without_warning()
% TEST: Gate 11 round-trip code must use struct load (no deploy_rt warning).
src=fileread(fullfile(fileparts(fileparts(mfilename('fullpath'))),...
    '+nrr_eval','gate11_freeze_deployment.m'));
if contains(src,'clear deploy_rt')
    result=struct('name','test_gate11_reload_roundtrip_without_warning','status','FAIL',...
        'message','clear deploy_rt still present — will cause warning');
elseif contains(src,"S = load(tmp_f, 'deploy')") || contains(src,'S=load(tmp_f')
    result=struct('name','test_gate11_reload_roundtrip_without_warning','status','PASS',...
        'message','Uses struct load — no warning expected');
else
    result=struct('name','test_gate11_reload_roundtrip_without_warning','status','FAIL',...
        'message','Cannot verify round-trip implementation');
end
end
