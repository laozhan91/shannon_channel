function mask = puncture_mask(L, rateIndex)
%PUNCTURE_MASK 母码（1/3）打孔图案
%
%   mask = puncture_mask(L, rateIndex)   返回 3L x 1 逻辑向量
%
% 母码每个时刻输出 3 个比特：[系统位 s, 编码器1 校验 p1, 编码器2 校验 p2]
% true 表示该比特被发送。系统位始终发送。
%
%   1/3 : 全发送                     -> 3   bit/时刻
%   1/2 : 时刻交替发送 p1 / p2        -> 2   bit/时刻
%   2/3 : 每 4 个时刻发送 2 个校验位   -> 1.5 bit/时刻
%   3/4 : 每 6 个时刻发送 2 个校验位   -> 4/3 bit/时刻

k = (0:L-1).';
mask = true(3*L, 1);
switch rateIndex
    case 1        % 1/3
        % 全保留
    case 2        % 1/2
        mask(2:3:end) = (mod(k,2) == 0);   % p1 @ k 偶
        mask(3:3:end) = (mod(k,2) == 1);   % p2 @ k 奇
    case 3        % 2/3
        mask(2:3:end) = (mod(k,4) == 0);   % p1 @ k ≡ 0 (mod 4)
        mask(3:3:end) = (mod(k,4) == 2);   % p2 @ k ≡ 2 (mod 4)
    case 4        % 3/4
        mask(2:3:end) = (mod(k,6) == 0);   % p1 @ k ≡ 0 (mod 6)
        mask(3:3:end) = (mod(k,6) == 3);   % p2 @ k ≡ 3 (mod 6)
    otherwise
        error('puncture_mask: 未知的 rateIndex = %d', rateIndex);
end
end
