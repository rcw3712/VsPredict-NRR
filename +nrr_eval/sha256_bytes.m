function h = sha256_bytes(data)
% NRR_EVAL.SHA256_BYTES  SHA-256 using ONLY mod, floor, and power-of-2 arithmetic.
%   No bitand, bitxor, bitshift, or uint32 — avoids all MATLAB saturation issues.

M  = 2^32;
M1 = M - 1;   % 0xFFFFFFFF

H = [1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225];

K = [1116352408,1899447441,3049323471,3921009573, ...
     961987163,1508970993,2453635748,2870763221, ...
     3624381080,310598401,607225278,1426881987, ...
     1925078388,2162078206,2614888103,3248222580, ...
     3835390401,4022224774,264347078,604807628, ...
     770255983,1249150122,1555081692,1996064986, ...
     2554220882,2821834349,2952996808,3210313671, ...
     3336571891,3584528711,113926993,338241895, ...
     666307205,773529912,1294757372,1396182291, ...
     1695183700,1986661051,2177026350,2456956037, ...
     2730485921,2820302411,3259730800,3345764771, ...
     3516065817,3600352804,4094571909,275423344, ...
     430227734,506948616,659060556,883997877, ...
     958139571,1322822218,1537002063,1747873779, ...
     1955562222,2024104815,2227730452,2361852424, ...
     2428436474,2756734187,3204031479,3329325298];

% Padding
msg = double(data(:)');
L = numel(msg);
msg = [msg, 128];
while mod(numel(msg),64) ~= 56
    msg = [msg, 0];
end
lb = L*8;
for bi = 7:-1:0
    msg = [msg, mod(floor(lb / 2^(bi*8)), 256)];
end

n = numel(msg)/64;
W = zeros(1,64);

for ci = 1:n
    blk = msg((ci-1)*64+1:ci*64);
    for i = 1:16
        W(i) = blk((i-1)*4+1)*16777216 + blk((i-1)*4+2)*65536 + ...
               blk((i-1)*4+3)*256     + blk((i-1)*4+4);
    end
    for i = 17:64
        s0 = XR(XR(RR(W(i-15),7),RR(W(i-15),18)),SR(W(i-15),3));
        s1 = XR(XR(RR(W(i-2),17),RR(W(i-2),19)),SR(W(i-2),10));
        W(i) = md(W(i-16)+s0+W(i-7)+s1);
    end
    a=H(1);b=H(2);c=H(3);d=H(4);e=H(5);f=H(6);g=H(7);hv=H(8);
    for i = 1:64
        S1 = XR(XR(RR(e,6),RR(e,11)),RR(e,25));
        ch = XR(AN(e,f),AN(M1-md(e),g));
        t1 = md(hv+S1+ch+K(i)+W(i));
        S0 = XR(XR(RR(a,2),RR(a,13)),RR(a,22));
        mj = XR(XR(AN(a,b),AN(a,c)),AN(b,c));
        t2 = md(S0+mj);
        hv=g;g=f;f=e;e=md(d+t1);d=c;c=b;b=a;a=md(t1+t2);
    end
    H(1)=md(H(1)+a);H(2)=md(H(2)+b);H(3)=md(H(3)+c);H(4)=md(H(4)+d);
    H(5)=md(H(5)+e);H(6)=md(H(6)+f);H(7)=md(H(7)+g);H(8)=md(H(8)+hv);
end

parts = cell(1,8);
for i=1:8; parts{i}=lower(dec2hex(H(i),8)); end
h = strjoin(parts,'');
end

function y = md(x);  y = mod(x, 2^32); end

function y = RR(x,n)  % right rotate 32-bit
x = mod(x,2^32);
y = mod(floor(x/2^n) + mod(x,2^n)*2^(32-n), 2^32);
end

function y = SR(x,n)  % logical right shift
y = floor(mod(x,2^32)/2^n);
end

function y = AN(a,b)  % bitwise AND via pure arithmetic
% De Morgan decomposition into 1-bit operations using arithmetic
a = mod(a,2^32); b = mod(b,2^32); y = 0;
for k = 0:31
    ba = mod(floor(a/2^k),2);
    bb = mod(floor(b/2^k),2);
    y  = y + ba*bb*2^k;
end
end

function y = XR(a,b)  % bitwise XOR via pure arithmetic
a = mod(a,2^32); b = mod(b,2^32); y = 0;
for k = 0:31
    ba = mod(floor(a/2^k),2);
    bb = mod(floor(b/2^k),2);
    y  = y + mod(ba+bb,2)*2^k;
end
end
