function tail = rsc_terminate(s, T)
%RSC_TERMINATE 计算把 RSC 状态归零所需的 3 个尾比特
%
%   tail = rsc_terminate(s, T)
%
% 对递归（反馈）卷积码，补 0 并不能使状态归零，必须输入与寄存器内容
% 相关的比特：令每步反馈 fb = u ⊕ a2 ⊕ a3 = 0 即可逐步清零寄存器。

a1 = bitget(s, 3);
a2 = bitget(s, 2);
a3 = bitget(s, 1);

u1 = mod(a2 + a3, 2);   % 状态 -> (0, a1, a2)
u2 = mod(a1 + a2, 2);   % 状态 -> (0, 0, a1)
u3 = a1;                % 状态 -> (0, 0, 0)
tail = [u1; u2; u3];

% 自检：归零必须成功
st = s;
for k = 1:3
    st = T.NS(st+1, tail(k)+1);
end
if st ~= 0
    error('rsc_terminate: 归零失败（末状态 %d）。', st);
end
end
