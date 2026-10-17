function [c, st, d] = ctrl_ref(st, v, iInd, iRes, iCrit, iGrid, P)
% Reference copy of the Controller block ctrl() in ICARUS_IEEE39BusSystem_ADC.slx.
% Same math, but state is passed in/out (st) instead of persistent variables,
% so test scripts can reset it. Call with st = [] to initialise.
% c = [cGrid cInd cRes cCrit cBat], 0 = closed, 1 = open.
% d = intermediate values (per unit) for checking the FPGA core.
if isempty(st)
    st.isl = 0; st.shd = 0; st.bf = 0; st.tI = 0; st.tR = 0; st.tC = 0;
    st.n = 0; st.m = 0; st.h = 0;
    st.ci = 0; st.cr = 0; st.cc = 0; st.cb = 0;
    st.buf = P.Vb^2*ones(P.N,3);
    st.s = P.N*P.Vb^2*ones(1,3);
    st.k = 1;
end

% per-phase RMS voltage (sliding window)
x2 = v(:)'.^2;
st.s = st.s + x2 - st.buf(st.k,:);
st.buf(st.k,:) = x2;
st.k = st.k + 1; if st.k > P.N, st.k = 1; end
Vmin = min(sqrt(max(st.s,0)/P.N))/P.Vb;

% currents in per unit
Ii = sqrt(2/3*sum(iInd.^2))/P.Ib(1);
Ir = sqrt(2/3*sum(iRes.^2))/P.Ib(2);
Ic = sqrt(2/3*sum(iCrit.^2))/P.Ib(3);
Ig = sqrt(2/3*sum(iGrid.^2))/P.Ib(4);

d = [Vmin Ii Ir Ic Ig];
[c, st] = ctrl_core(st, Vmin, Ii, Ir, Ic, Ig, P);
end
