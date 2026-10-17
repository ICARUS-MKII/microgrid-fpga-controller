function [c, st, d] = ctrl_fpga(st, cv, cI, cR, cC, cG, K)
% Integer model of the FPGA controller. One call = one 50 us loop iteration.
% cv, cI, cR, cC, cG: 1x3 signed ADC counts (phase a,b,c) for bus voltage and
% the industrial, residential, critical and grid currents.
% Uses only integer add, multiply, compare: the LabVIEW FPGA VI should do
% exactly these operations, in this order.
if isempty(st)
    st.buf = K.sInit*ones(K.N,3, 'int64');   % FPGA: block memory, 3 x N x U32
    st.s   = K.N*K.sInit*ones(1,3, 'int64'); % FPGA: 3 running sums (U32)
    st.k   = 1;                              % FPGA: write address 0..N-1
    st.ci = 0; st.cr = 0; st.cc = 0; st.cb = 0;
    st.tI = 0; st.tR = 0; st.tC = 0; st.bf = 0;
    st.h = 0; st.n = 0; st.shd = 0; st.m = 0; st.isl = 0;
end

% --- input stage (this is the part that changes with the channel plan) ---
x2 = int64(cv).^2;                           % 3 squares, each <= 2048^2
st.s = st.s + x2 - st.buf(st.k,:);
st.buf(st.k,:) = x2;
st.k = st.k + 1; if st.k > K.N, st.k = 1; end
sMin = min(st.s);                            % weakest phase

qI = sum(int64(cI).^2); qR = sum(int64(cR).^2);
qC = sum(int64(cC).^2); qG = sum(int64(cG).^2);
d = double([sMin qI qR qC qG]);              % decision core inputs

% --- decision core (same structure as ctrl_core.m) ---
ocI = qI > K.thrOC(1); ocR = qR > K.thrOC(2); ocC = qC > K.thrOC(3);
oc  = ocI || ocR || ocC;
gHi = qG > K.thrG;

st.ci = cnt(st.ci, ocI); if st.ci > K.nOC, st.tI = 1; end
st.cr = cnt(st.cr, ocR); if st.cr > K.nOC, st.tR = 1; end
st.cc = cnt(st.cc, ocC); if st.cc > K.nOC, st.tC = 1; end
st.cb = cnt(st.cb, gHi && ~oc); if st.cb > K.nOC, st.bf = 1; end

if oc || gHi
    st.h = K.N;
elseif st.h > 0
    st.h = st.h - 1;
end

if st.h > 0
    st.n = 0;
else
    st.n = cnt(st.n, sMin < K.thrUV);
end
if st.n > K.nUV, st.shd = 1; end

if st.shd && qG < K.thrZ
    st.m = st.m + 1;
else
    st.m = 0;
end
if st.m > K.nZ && ~st.bf, st.isl = 1; end

c = [max(st.shd, st.bf), max(st.shd, st.tI), max(st.shd, st.tR), st.tC, 1 - st.isl];
end

function c = cnt(c, on)
if on
    c = c + 1;
else
    c = max(c - 1, 0);
end
end
