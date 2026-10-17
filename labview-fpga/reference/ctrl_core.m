function [c, st] = ctrl_core(st, Vmin, Ii, Ir, Ic, Ig, P)
% Decision core of ctrl(): everything after the measurements.
% Inputs are per-unit magnitudes, so this part does not depend on how the
% signals reach the myRIO. This is what the LabVIEW FPGA "core" must match.
% c = [cGrid cInd cRes cCrit cBat], 0 = closed, 1 = open.
oc  = (Ii > P.kOC) || (Ir > P.kOC) || (Ic > P.kOC);
gHi = Ig > P.kG;

% overcurrent must last P.nOC samples before trip (latching)
st.ci = cnt(st.ci, Ii > P.kOC); if st.ci > P.nOC, st.tI = 1; end
st.cr = cnt(st.cr, Ir > P.kOC); if st.cr > P.nOC, st.tR = 1; end
st.cc = cnt(st.cc, Ic > P.kOC); if st.cc > P.nOC, st.tC = 1; end

% bus fault: grid overcurrent without a branch overcurrent (latching)
st.cb = cnt(st.cb, gHi && ~oc); if st.cb > P.nOC, st.bf = 1; end

% hold-off after any fault (RMS window remembers the dip)
if oc || gHi
    st.h = P.N;
elseif st.h > 0
    st.h = st.h - 1;
end

% blackout counter (paused during hold-off)
if st.h > 0
    st.n = 0;
else
    st.n = cnt(st.n, Vmin < P.kUV);
end
if st.n > P.nUV, st.shd = 1; end

% battery after POC confirmed open
if st.shd && Ig < P.kZ
    st.m = st.m + 1;
else
    st.m = 0;
end
if st.m > P.nZ && ~st.bf, st.isl = 1; end

c = [max(st.shd, st.bf), max(st.shd, st.tI), max(st.shd, st.tR), st.tC, 1 - st.isl];
end

function c = cnt(c, on)
% up/down counter: +1 when true, -1 when false, not below 0
if on
    c = c + 1;
else
    c = max(c - 1, 0);
end
end
