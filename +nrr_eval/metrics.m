function m = metrics(yt, yp)
% NRR_EVAL.METRICS  Compute R², RMSE, MAE, bias.
ok=isfinite(yt)&isfinite(yp);
m.r2=nrr_eval.r2(yt(ok),yp(ok));
m.rmse=sqrt(mean((yt(ok)-yp(ok)).^2));
m.mae=mean(abs(yt(ok)-yp(ok)));
m.bias=mean(yp(ok)-yt(ok));
m.n=sum(ok);
end
