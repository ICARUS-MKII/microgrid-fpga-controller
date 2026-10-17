% Check that the integer FPGA model (ctrl_fpga) makes the same decisions as
% the Simulink controller (ctrl_ref, a copy of ctrl() in the model), and
% export test vectors for the LabVIEW FPGA VI.
% Run from this folder:  run_tests
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', '..', 'matlab-simulink', 'ICARUS_params.m'));
K = fpga_constants(P);
outDir = fullfile(here, 'vectors'); if ~exist(outDir, 'dir'), mkdir(outDir); end

T  = 0.25;  t = (0:round(T/Ts)-1)'*Ts;  tf = 0.05;   % fault at 50 ms
ph = [0 -2*pi/3 2*pi/3];
wave = @(amp) amp(:).*sin(2*pi*f*t + ph);           % amp: per-sample peak, Nx1
step = @(a, b) a + (b - a)*(t >= tf);               % value a before tf, b after
Vpk  = sqrt(2)*P.Vb;

% name, V (pu), I ind/res/crit/grid (pu of each base), noise on/off
S = {
 'normal',      step(1,1),    step(1,1), step(1,1), step(1,1), step(1,1),   0
 'normal_noise',step(1,1),    step(1,1), step(1,1), step(1,1), step(1,1),   1
 'blackout',    step(1,0.05), step(1,0.05), step(1,0.05), step(1,0.05), step(1,0), 1
 'short_ind',   step(1,0.6),  step(1,6), step(1,1), step(1,1), step(1,3),   1
 'short_crit',  step(1,0.6),  step(1,1), step(1,1), step(1,6), step(1,3),   1
 'bus_fault',   step(1,0.3),  step(1,1), step(1,1), step(1,1), step(1,6),   1
};

rng(1);
allOk = true;
for s = 1:size(S,1)
    name = S{s,1}; noise = S{s,7};
    v  = wave(S{s,2}*Vpk);
    iI = wave(S{s,3}*P.Ib(1)); iR = wave(S{s,4}*P.Ib(2));
    iC = wave(S{s,5}*P.Ib(3)); iG = wave(S{s,6}*P.Ib(4));

    % fake ADC, same as the model's meas(): noise, clip, 12-bit quantise
    cv = adcCounts(v,  P.FSv,    P, noise);
    cI = adcCounts(iI, P.FSi(1), P, noise); cR = adcCounts(iR, P.FSi(2), P, noise);
    cC = adcCounts(iC, P.FSi(3), P, noise); cG = adcCounts(iG, P.FSi(4), P, noise);
    lsbV = 2*P.FSv/2^P.nb; lsbI = 2*P.FSi/2^P.nb;

    n = numel(t); cRef = zeros(n,5); cFp = zeros(n,5); dFp = zeros(n,5);
    sr = []; sf = [];
    for k = 1:n
        [cRef(k,:), sr] = ctrl_ref(sr, cv(k,:)*lsbV, cI(k,:)*lsbI(1), cR(k,:)*lsbI(2), ...
                                   cC(k,:)*lsbI(3), cG(k,:)*lsbI(4), P);
        [cFp(k,:), sf, dFp(k,:)] = ctrl_fpga(sf, cv(k,:), cI(k,:), cR(k,:), cC(k,:), cG(k,:), K);
    end

    bad = find(any(cRef ~= cFp, 2), 1);
    if isempty(bad)
        fprintf('%-13s MATCH   ', name);
    else
        fprintf('%-13s MISMATCH first at sample %d (t = %.2f ms)  ', name, bad, t(bad)*1e3);
        allOk = false;
    end
    fprintf('final [cGrid cInd cRes cCrit cBat] = [%d %d %d %d %d]', cFp(end,:));
    first = find(any(cFp ~= cFp(1,:), 2), 1);
    if ~isempty(first), fprintf('  first change at %.2f ms', t(first)*1e3); end
    fprintf('\n');

    % test vector: one row per 50 us sample, raw counts in, expected commands out
    M = [ (0:n-1)', cv, cI, cR, cC, cG, cFp ];
    hdr = 'sample,va,vb,vc,iInd_a,iInd_b,iInd_c,iRes_a,iRes_b,iRes_c,iCrit_a,iCrit_b,iCrit_c,iGrid_a,iGrid_b,iGrid_c,cGrid,cInd,cRes,cCrit,cBat';
    fid = fopen(fullfile(outDir, [name '.csv']), 'w'); fprintf(fid, '%s\n', hdr); fclose(fid);
    writematrix(M, fullfile(outDir, [name '.csv']), 'WriteMode', 'append');

    % core-only vector: decision core inputs (counts^2) and expected commands
    Mc = [ (0:n-1)', dFp, cFp ];
    fid = fopen(fullfile(outDir, [name '_core.csv']), 'w');
    fprintf(fid, 'sample,sMin,qInd,qRes,qCrit,qGrid,cGrid,cInd,cRes,cCrit,cBat\n'); fclose(fid);
    writematrix(Mc, fullfile(outDir, [name '_core.csv']), 'WriteMode', 'append');
end

fprintf('\nFPGA constants (counts / counts^2):\n'); disp(K);
if allOk, fprintf('All scenarios match.\n'); else, fprintf('Some scenarios do NOT match.\n'); end

function c = adcCounts(x, FS, P, noise)
% signed 12-bit counts, clipped to -2048..2047
y = x + noise*P.ns*FS*randn(size(x));
lsb = 2*FS/2^P.nb;
c = round(y/lsb);
c = min(max(c, -2^(P.nb-1)), 2^(P.nb-1)-1);
end
