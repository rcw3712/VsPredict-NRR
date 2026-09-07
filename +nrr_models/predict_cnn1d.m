function pred = predict_cnn1d(model, X)
% NRR_MODELS.PREDICT_CNN1D  Apply fitted CNN1D with sliding-window logic.
if isempty(model.net); pred=nan(size(X,1),1); return; end
W=model.window; n=size(X,1); nf=size(X,2); ns=n-W+1;
if ns<=0; pred=nan(n,1); return; end
Xw=zeros(W,1,nf,ns,'single');
for j=1:ns; Xw(:,1,:,j)=reshape(single(X(j:j+W-1,:)),W,1,nf); end
pw=squeeze(double(predict(model.net,Xw))); pw=pw(:);
pred=nan(n,1); half=floor(W/2);
for j=1:numel(pw); idx=j+half; if idx<=n; pred(idx)=pw(j); end; end
pred=fillmissing(pred,'nearest');
end
