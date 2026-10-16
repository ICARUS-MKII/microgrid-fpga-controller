%% ICARUS controller parameters (per unit)
Ts = 50e-6; EnPSS = 1;          % sim settings (keep, model needs them)
f = 60; VLL = 480;              % system frequency, bus line-line voltage

% load ratings (must match the load blocks)
Pind  = 80e3; Qind  = 25e3;     % industrial (W, var)
Pres  = 80e3; Qres  = 25e3;     % residential (W, var)
Pcrit = 40e3; Qcrit = 25e3;     % critical (W, var)

Sind  = sqrt(Pind^2  + Qind^2);  % industrial |S| (VA)
Sres  = sqrt(Pres^2  + Qres^2);  % residential |S| (VA)
Scrit = sqrt(Pcrit^2 + Qcrit^2); % critical |S| (VA)
Sgrid = sqrt((Pind+Pres+Pcrit)^2 + (Qind+Qres+Qcrit)^2); % total through POC (add P and Q first)

% per-unit bases
P.Vb  = VLL/sqrt(3);                                   % base phase V (rms)
P.Ib  = sqrt(2)*[Sind Sres Scrit Sgrid]/(sqrt(3)*VLL); % base peak I [ind res crit grid]

% thresholds (pu)
P.kOC = 2.0;                    % branch overcurrent pickup (pu)
P.kG  = 2.0;                    % grid overcurrent pickup (pu)
P.kZ  = 0.1;                    % "grid current ~0" (pu), ~36 A, above ADC noise
P.kUV = 0.5;                    % undervoltage pickup (pu)

% timing (samples)
P.N   = round(1/(2*f*Ts));      % half-cycle RMS window (167)
P.nZ  = P.N;                    % POC-open confirm: half cycle (167 samples, ~8.3 ms)
P.nUV = round(1e-3/Ts);         % blackout pickup, 1 ms (20 samples)
P.nOC = round(0.5e-3/Ts);       % overcurrent / bus fault pickup, 0.5 ms (10 samples)

% fake "ADC" module
P.nb  = 12;                     % ADC bits
P.FSv = 2*sqrt(2)*P.Vb;         % voltage range: +-2 pu peak (~+-784 V)
P.FSi = 10*P.Ib;                % current ranges: +-10 pu peak [ind res crit grid]
P.ns  = 0.002;                  % noise: 0.2% of full scale (rms)
P.nD  = 1;                      % loop delay in samples (1 = same as now)