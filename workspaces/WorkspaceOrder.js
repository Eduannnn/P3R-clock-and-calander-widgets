.pragma library

function deleteLua(id) {
    if (!Number.isInteger(id) || id <= 1) return "";
    return `
if p3rWorkspaceActions then
  p3rWorkspaceActions.delete(${id})
else
  local current, active = hl.get_workspace(${id}), hl.get_active_workspace()
  if current then
    local destination = 1
    for _, workspace in ipairs(hl.get_workspaces()) do
      if workspace.id > destination and workspace.id < ${id} then destination = workspace.id end
    end
    local windows = hl.get_workspace_windows(current)
    hl.workspace_rule({workspace="${id}",persistent=false})
    hl.exec_scheduled_prop_refresh_immediately()
    for _, window in ipairs(windows) do
      if window.fullscreen ~= 0 or window.fullscreen_client ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen_state({internal=0,client=0,action="set",window=window}))
      end
      hl.dispatch(hl.dsp.window.move({workspace=tostring(destination),follow=false,window=window}))
    end
    hl.dispatch(hl.dsp.focus({workspace=tostring(active and active.id ~= ${id} and active.id or destination)}))
  end
end`;
}

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
