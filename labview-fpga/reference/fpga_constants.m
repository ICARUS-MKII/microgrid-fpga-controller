function K = fpga_constants(P)
% Integer constants for the FPGA, derived from ICARUS_params.m (struct P).
% The FPGA works on raw signed ADC counts (12 bit, -2048..2047) and compares
% squared values, so it needs no sqrt or division. Every threshold here is
% in counts or counts^2.
lsbV = 2*P.FSv/2^P.nb;               % volts per count
lsbI = 2*P.FSi/2^P.nb;               % amps per count [ind res crit grid]

VbC = P.Vb/lsbV;                     % base phase voltage in counts
IbC = P.Ib./lsbI;                    % base peak current in counts [ind res crit grid]

K.N     = P.N;                       % RMS window length (samples)
K.nOC   = P.nOC;                     % pickup counts
K.nUV   = P.nUV;
K.nZ    = P.nZ;

% voltage: Vmin < kUV  <=>  min(sum of N squared samples) < N*(kUV*Vb)^2
K.thrUV = floor(P.N*(P.kUV*VbC)^2);
K.sInit = round(VbC^2);              % each window slot starts at Vb^2 (nominal)

% currents: I > k  <=>  ia^2+ib^2+ic^2 > 1.5*(k*Ib)^2   (since I = sqrt(2/3*sum)/Ib)
K.thrOC = floor(1.5*(P.kOC*IbC(1:3)).^2);   % [ind res crit]
K.thrG  = floor(1.5*(P.kG *IbC(4))^2);      % grid overcurrent
K.thrZ  = floor(1.5*(P.kZ *IbC(4))^2);      % grid current ~0
end
