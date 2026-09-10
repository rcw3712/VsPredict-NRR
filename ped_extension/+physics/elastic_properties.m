function out = elastic_properties(rho, Vs, Vp)
% PHYSICS.ELASTIC_PROPERTIES  Compute G, K, E, nu from rho, Vs, Vp.
%   Inputs:  rho [g/cm3], Vs [km/s], Vp [km/s]
%   Outputs: G, K, E in GPa, nu dimensionless
%   Unit: g/cm3 * (km/s)^2 = 1e3 kg/m3 * 1e6 m2/s2 = 1e9 Pa = 1 GPa
out.G    = rho .* Vs.^2;
out.K    = rho .* (Vp.^2 - 4*Vs.^2/3);
out.nu   = (Vp.^2 - 2*Vs.^2) ./ (2*(Vp.^2 - Vs.^2));
out.E    = 2*out.G .* (1 + out.nu);
out.VpVs = Vp ./ Vs;
% Plausibility flags (application-specific, sedimentary rock)
out.f_vpvs = out.VpVs >= sqrt(2);
out.f_nu   = out.nu   >= 0 & out.nu < 0.5;
out.f_G    = out.G    > 0;
out.f_K    = out.K    > 0;
out.f_E    = out.E    > 0;
out.f_fin  = isfinite(out.G) & isfinite(out.K) & isfinite(out.E);
out.f_all  = out.f_vpvs & out.f_nu & out.f_G & out.f_K & out.f_E & out.f_fin;
end
