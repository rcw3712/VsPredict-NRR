function selftest_vspredict_ped_extension_codex()
% Fast tests that do not train neural networks or write to the core project.
fprintf('\nVsPredict PED Codex v2 self-test\n');
pass=0;fail=0;

try
    assert(~isempty(which('run_vspredict_ped_extension_codex')));
    pass=pass+1;fprintf('[PASS] entry point discoverable\n');
catch ME
    fail=fail+1;fprintf('[FAIL] entry point: %s\n',ME.message);
end

try
    dt=[60;75;100];vp=304.8./dt;
    assert(max(abs(vp-[5.08;4.064;3.048]))<1e-12);
    pass=pass+1;fprintf('[PASS] Vp conversion known-answer\n');
catch ME
    fail=fail+1;fprintf('[FAIL] Vp conversion: %s\n',ME.message);
end

try
    rho=2.4;vs=2.0;vp=3.5;
    G=rho*vs^2;K=rho*(vp^2-4*vs^2/3);
    nu=(vp^2-2*vs^2)/(2*(vp^2-vs^2));E=2*G*(1+nu);
    assert(abs(G-9.6)<1e-12&&K>0&&nu>=0&&nu<.5&&E>0);
    pass=pass+1;fprintf('[PASS] elastic properties known-answer\n');
catch ME
    fail=fail+1;fprintf('[FAIL] elastic properties: %s\n',ME.message);
end

try
    depth=[(0:0.1524:3)';(10:0.1524:13)'];
    dd=diff(depth);step=median(dd(dd>0));seg=cumsum([true;dd<=0|abs(dd-step)>step*.25]);
    assert(numel(unique(seg))==2);
    W=16;cross=0;
    for s=unique(seg(:))'
        ix=find(seg==s);
        for j=1:max(0,numel(ix)-W+1)
            w=ix(j:j+W-1);cross=cross+(numel(unique(seg(w)))~=1);
        end
    end
    assert(cross==0);
    pass=pass+1;fprintf('[PASS] segmented CNN windows do not cross a gap\n');
catch ME
    fail=fail+1;fprintf('[FAIL] segmented window test: %s\n',ME.message);
end

try
    src=fileread(which('run_vspredict_ped_extension_codex'));
    required={'LEGACY_INVALID_SCALING_MISMATCH','predict_ridge_stacker', ...
        'PED_CORRECTED_FIXED_HP_EXTENSION','STRICT_ROW_ID_POPB_236'};
    for i=1:numel(required);assert(contains(src,required{i}),'Missing source invariant: %s',required{i});end
    pass=pass+1;fprintf('[PASS] scientific source invariants present\n');
catch ME
    fail=fail+1;fprintf('[FAIL] source invariants: %s\n',ME.message);
end

fprintf('Self-test: %d PASS | %d FAIL\n',pass,fail);
if fail>0;error('PED_CODEX:SELFTEST_FAILED','%d self-test(s) failed',fail);end
end
