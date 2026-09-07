function pred = predict_dffnn(model, X)
% NRR_MODELS.PREDICT_DFFNN  Apply fitted DFFNN.
raw=predict(model.net,single(X));
pred=double(raw(:));
end
