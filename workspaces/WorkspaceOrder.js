.pragma library

function movePlan(ids, source, target) {
    const sorted = ids.slice().sort((a, b) => a - b);
    if (sorted.some(id => !Number.isInteger(id) || id <= 0)
        || new Set(sorted).size !== sorted.length) throw new Error("Invalid workspace IDs");
    const order = sorted.slice();
    const from = order.indexOf(source), to = order.indexOf(target);
    if (from < 0 || to < 0) throw new Error("Workspace no longer exists");
    order.splice(to, 0, order.splice(from, 1)[0]);
    return order.map((id, index) => ({ from: id, to: sorted[index] })).filter(pair => pair.from !== pair.to);
}

function reorderLua(plan) {
    if (plan.length === 0) return "";
    if (plan.some(p => !Number.isInteger(p.from) || !Number.isInteger(p.to) || p.from <= 0 || p.to <= 0))
        throw new Error("Invalid workspace reorder");
    const rows = plan.map(p => "{original=" + p.from + ",target=" + p.to + ",current=" + p.from + "}").join(",");
    return `
local plan = {${rows}}
local largest = 0
for _, ws in ipairs(hl.get_workspaces()) do if ws.id and ws.id > largest then largest = ws.id end end
assert(largest + #plan * 2 + 100 < 4294967295, "No temporary workspace IDs available")
for _, p in ipairs(plan) do assert(hl.get_workspace(p.original), "Workspace no longer exists") end
local function move(p, id)
  local result = hl.dispatch(hl.dsp.workspace.change_id({workspace=p.current, id=id}))
  assert(result and result.ok, result and result.error or "Could not reorder workspace")
  p.current = id
end
local ok, message = pcall(function()
  for i, p in ipairs(plan) do move(p, largest + 100 + i) end
  for _, p in ipairs(plan) do move(p, p.target) end
end)
if not ok then
  local restored = pcall(function()
    for i, p in ipairs(plan) do move(p, largest + 100 + #plan + i) end
    for _, p in ipairs(plan) do move(p, p.original) end
  end)
  error(restored and ("Reorder cancelled: " .. tostring(message)) or "Reorder failed; check workspace IDs")
end`;
}
