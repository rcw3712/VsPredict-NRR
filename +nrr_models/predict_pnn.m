function pred = predict_pnn(model, X)
% NRR_MODELS.PREDICT_PNN  Nadaraya-Watson prediction.
sg=model.spread; Xt=model.X_tr; yt=model.y_tr;
pred=zeros(size(X,1),1);
for i=1:size(X,1)
    d2=sum((Xt-X(i,:)).^2,2);
    w=exp(-d2/(2*sg^2)); sw=sum(w);
    if sw<1e-300; pred(i)=mean(yt); else; pred(i)=(w'*yt)/sw; end
end
end
