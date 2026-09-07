function val = getfield_default(s, field, default)
% NRR_EVAL.GETFIELD_DEFAULT  Return struct field value or default if absent.
if isfield(s, field)
    val = s.(field);
else
    val = default;
end
end
