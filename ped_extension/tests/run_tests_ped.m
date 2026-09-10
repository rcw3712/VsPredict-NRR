% TESTS for VsPredict PED Extension
% Run from VsPredict_PED_Extension folder: run_tests_ped

function run_tests_ped()
fprintf('\n%s\n  PED Extension Unit Tests\n%s\n\n', repmat('=',1,50), repmat('=',1,50));
n_pass = 0; n_fail = 0;

%% Test: physics.vp_from_dt
try
    Vp = physics.vp_from_dt(74.59);
    assert(abs(Vp - 304.8/74.59) < 1e-10, 'vp_from_dt arithmetic');
    assert(abs(Vp - 4.087) < 0.001, 'vp_from_dt value range');
    Vp_popA = physics.vp_from_dt(114.56);
    assert(abs(Vp_popA - 304.8/114.56) < 1e-10, 'vp_from_dt PopA');
    fprintf('PASS  physics.vp_from_dt\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  physics.vp_from_dt: %s\n', ME.message); n_fail=n_fail+1;
end

%% Test: physics.elastic_properties — known values
try
    % Typical carbonate: Vp=3.5 km/s, Vs=2.0 km/s, rho=2.4 g/cm3
    p = physics.elastic_properties(2.0, 3.5, 2.4);
    G_exp = 2.4 * 2.0^2;   % = 9.6 GPa
    K_exp = 2.4 * (3.5^2 - 4/3*2.0^2);
    nu_exp = (3.5^2 - 2*2.0^2) / (2*(3.5^2 - 2.0^2));
    E_exp = 2*G_exp*(1+nu_exp);
    assert(abs(p.G - G_exp) < 1e-8, 'G formula');
    assert(abs(p.K - K_exp) < 1e-8, 'K formula');
    assert(abs(p.nu - nu_exp) < 1e-8, 'nu formula');
    assert(abs(p.E - E_exp) < 1e-8, 'E formula');
    assert(p.gate_ALL_OK, 'gate_ALL_OK for valid carbonate');
    assert(abs(p.VpVs - 3.5/2.0) < 1e-8, 'VpVs ratio');
    fprintf('PASS  physics.elastic_properties (valid carbonate)\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  physics.elastic_properties: %s\n', ME.message); n_fail=n_fail+1;
end

%% Test: physics.elastic_properties — expected failure (Vp < sqrt(2)*Vs)
try
    % Over-predicted Vs (like Ridge stacker failure): Vs > Vp/sqrt(2)
    p = physics.elastic_properties(3.0, 3.5, 2.4);  % Vp/Vs = 1.167 < sqrt(2)
    assert(~p.gate_VpVs_sqrt2, 'should fail VpVs gate');
    assert(~p.gate_nu_valid,   'should fail nu gate when Vp/Vs < sqrt(2)');
    assert(~p.gate_ALL_OK,     'should fail ALL_OK');
    fprintf('PASS  physics.elastic_properties (expected gate failure)\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  physics.elastic_properties gate failure: %s\n', ME.message); n_fail=n_fail+1;
end

%% Test: validation.normalize_table_schema
try
    schema.MODEL = 'string';
    schema.R2    = 'double';
    T = table({'ridge'}, {-2.6162}, 'VariableNames', {'MODEL','R2'});
    T2 = validation.normalize_table_schema(T, schema);
    assert(isstring(T2.MODEL), 'MODEL should be string');
    fprintf('PASS  validation.normalize_table_schema\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  validation.normalize_table_schema: %s\n', ME.message); n_fail=n_fail+1;
end

%% Test: canonical numerical values
try
    canon = struct('ridgePopAR2',-2.6162,'ridgePopBR2',-5.2708,...
        'directPopAR2',0.6831,'cvPooledR2',0.6632,'dtZ',7.85,'dtKS',1.000);
    tol = 1e-4;
    assert(abs(canon.ridgePopAR2 + 2.6162) < tol, 'ridgePopAR2');
    assert(abs(canon.ridgePopBR2 + 5.2708) < tol, 'ridgePopBR2');
    assert(abs(canon.directPopAR2 - 0.6831) < tol, 'directPopAR2');
    assert(abs(canon.cvPooledR2 - 0.6632) < tol, 'cvPooledR2');
    assert(abs(canon.dtZ - 7.85) < 0.01, 'dtZ');
    assert(abs(canon.dtKS - 1.000) < tol, 'dtKS');
    fprintf('PASS  canonical numerical assertions\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  canonical numerical assertions: %s\n', ME.message); n_fail=n_fail+1;
end

%% Test: table schema safety (empty table vertcat)
try
    schema2.MODEL = 'string'; schema2.N = 'double';
    T_empty = table(strings(0,1), zeros(0,1), 'VariableNames', {'MODEL','N'});
    T_full  = table("ridge", 329, 'VariableNames', {'MODEL','N'});
    T_empty = validation.normalize_table_schema(T_empty, schema2);
    T_full  = validation.normalize_table_schema(T_full, schema2);
    T_cat   = [T_empty; T_full];
    assert(height(T_cat) == 1, 'vertcat height');
    fprintf('PASS  table schema safety (empty+full vertcat)\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  table schema safety: %s\n', ME.message); n_fail=n_fail+1;
end

%% Test: circular block sample
try
    n = 100; bl = 10;
    rng(42);
    idx = circ_block_sample(n, bl);
    assert(numel(idx) == n, 'sample length');
    assert(all(idx >= 1 & idx <= n), 'index bounds');
    fprintf('PASS  circ_block_sample\n'); n_pass=n_pass+1;
catch ME
    fprintf('FAIL  circ_block_sample: %s\n', ME.message); n_fail=n_fail+1;
end

fprintf('\n%s\n  Tests: %d PASS | %d FAIL\n%s\n\n', ...
    repmat('-',1,50), n_pass, n_fail, repmat('-',1,50));
if n_fail > 0
    error('Unit tests FAIL: %d failures', n_fail);
end
end

function idx = circ_block_sample(n, bl)
n_blocks = ceil(n/bl);
starts   = randi(n, n_blocks, 1);
idx = zeros(n_blocks*bl,1);
for k=1:n_blocks
    for j=0:bl-1
        idx((k-1)*bl+j+1) = mod(starts(k)-1+j,n)+1;
    end
end
idx = idx(1:n);
end
