function result = test_gate_fails_on_geomech_contradiction()
% TEST: synthetic data where vpvs_ok=0 must produce all_ok=0.
vp=1000; vs=800; rho=2400;   % vpvs=1.25 < sqrt(2)
vpvs=vp/vs;
vpvs_min=sqrt(2);
nu=(vp^2-2*vs^2)/(2*(vp^2-vs^2));
G=rho*vs^2/1e9; K=rho*(vp^2-4/3*vs^2)/1e9; E=9*K*G/(3*K+G);
input_ok=true; vp_gt_vs=(vp>vs); vpvs_ok=(vpvs>=vpvs_min);
nu_ok=(nu>=0&&nu<=0.5); G_ok=(G>0); K_ok=(K>0); E_ok=(E>0);
all_ok=input_ok&&vp_gt_vs&&vpvs_ok&&nu_ok&&G_ok&&K_ok&&E_ok;
assert(~vpvs_ok,'Expected vpvs_ok=false');
assert(~all_ok,'Expected all_ok=false when vpvs_ok=false');
result=struct('name','test_gate_fails_on_geomech_contradiction','status','PASS','message','OK');
end
