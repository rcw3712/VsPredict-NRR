function m = eval_pop(y_true, y_pred, mask, label)
% NRR_EVAL.EVAL_POP  Evaluate model on a population mask.
yt=y_true(mask); yp=y_pred(mask);
ok=isfinite(yt)&isfinite(yp);
m=nrr_eval.metrics(yt(ok),yp(ok));
fprintf('[eval]   %-32s n=%d R²=%+.4f RMSE=%.4f bias=%+.4f\n',...
    label,m.n,m.r2,m.rmse,m.bias);
end
