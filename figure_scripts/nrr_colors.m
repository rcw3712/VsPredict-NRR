function c = nrr_colors()
% NRR_COLORS  Return NRR publication color palette.
c.ridge     = [0.722 0.329 0.071];   % brown-red: primary model failure
c.dr        = [0.204 0.416 0.588];   % steel blue: direct ridge post-hoc
c.wellA     = [0.204 0.416 0.588];   % steel blue
c.wellB     = [0.843 0.376 0.271];   % salmon-red
c.overlap   = [0.7 0.7 0.7];         % grey: excluded rows
c.popB_excl = [0.988 0.733 0.533];   % light orange: Vp/Vs excluded
c.pass      = [0.133 0.545 0.133];   % green
c.fail      = [0.722 0.329 0.071];   % brown-red
c.zero_line = [0.3 0.3 0.3];         % dark grey reference
c.threshold = [0.0 0.0 0.0];         % black threshold line
end
