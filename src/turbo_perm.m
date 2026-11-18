function perm = turbo_perm(N, seed)
%TURBO_PERM Turbo 交织器置换向量（收发两端共用，保证一致）
%
%   perm = turbo_perm(N, seed)
%
% 采用固定种子的伪随机交织：v(j) = u(perm(j))。
% 使用局部 RandStream，不影响全局 rng 状态。

persistent cachedN cachedSeed cachedPerm
if isempty(cachedN) || cachedN ~= N || cachedSeed ~= seed
    s = RandStream('mt19937ar', 'Seed', seed);
    cachedPerm = randperm(s, N);
    cachedPerm = cachedPerm(:);
    cachedN = N;
    cachedSeed = seed;
end
perm = cachedPerm;
end
