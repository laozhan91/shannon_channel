function v = opt_get(s, name, default)
%OPT_GET 从结构体安全读取字段（不存在或为空时返回默认值）
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
