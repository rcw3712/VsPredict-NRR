function result = test_fit_frozen_deployment_single_api()
% TEST: fit_frozen_deployment with same inputs produces identical output.
cfg=config_nrr_v5(); cfg.dr.train_n=0;   % bypass n check for small test
n=64; k=cfg.cv.n_outer; feats=cfg.data.features;
T=array2table(randn(n,numel(feats)),'VariableNames',feats);
T.VS=rand(n,1)*2+1; T.DEPTH=(1:n)'; T.ROW_ID=(1:n)'; T.WELL_ID=repmat({'W'},n,1);
T.DTS=304.8./T.VS; T.DT=randn(n,1)+70; T.VP=randn(n,1)+4;
T.VPVS=T.VP./T.VS; T.VSH=rand(n,1); T.NPHI=rand(n,1);
cfg.cv.n_outer=2; cfg.cv.n_inner=2; cfg.dr.train_n=n;
hp=nrr_models.default_hp(cfg);
try
    dep1=nrr_eval.fit_frozen_deployment(T,hp,42,cfg);
    dep2=nrr_eval.fit_frozen_deployment(T,hp,42,cfg);
    assert(abs(dep1.roundtrip_rmse-dep2.roundtrip_rmse)<1e-10,...
        'Two calls with same inputs differ: %.6f vs %.6f',...
        dep1.roundtrip_rmse,dep2.roundtrip_rmse);
    result=struct('name','test_fit_frozen_deployment_single_api','status','PASS',...
        'message',sprintf('rt_rmse=%.4f identical',dep1.roundtrip_rmse));
catch e
    result=struct('name','test_fit_frozen_deployment_single_api','status','FAIL',...
        'message',e.message);
end
end
