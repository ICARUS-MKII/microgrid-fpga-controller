function c = myrio_step(x, hw)
% one TCP round trip: send 15 int16 counts, wait for 5 uint8 commands
persistent t
if hw == 0
    c = [0 0 0 0 1];                    % dry run: "no faults ever"
    return
end
if isempty(t)
    t = tcpclient('172.22.11.2', 6340, 'Timeout', 2); % IP and port: confirm with Ahmed
end
write(t, int16(x));                     % 30 bytes, little-endian
c = double(read(t, 5, 'uint8'));        % cGrid cInd cRes cCrit cBat
end