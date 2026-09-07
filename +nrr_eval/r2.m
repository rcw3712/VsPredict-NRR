function v = r2(yt, yp)
ss_res=sum((yt-yp).^2); ss_tot=sum((yt-mean(yt)).^2);
if ss_tot<eps; v=NaN; else; v=1-ss_res/ss_tot; end
end
