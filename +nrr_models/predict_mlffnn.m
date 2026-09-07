function pred = predict_mlffnn(model, X)
% NRR_MODELS.PREDICT_MLFFNN  Apply fitted MLFFNN.
raw=predict(model.net,single(X));
pred=double(raw(:));
end
