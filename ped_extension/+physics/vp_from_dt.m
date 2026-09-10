function Vp = vp_from_dt(DT_us_ft)
% PHYSICS.VP_FROM_DT  Convert DT [microsecond/foot] to Vp [km/s].
%   Vp (km/s) = 304.8 / DT (µs/ft)
%   Verified: 304.8 = 1000000 µs/s * 0.0003048 km/ft = 304.8
Vp = 304.8 ./ DT_us_ft;
end
