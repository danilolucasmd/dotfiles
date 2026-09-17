-- Fall back to the last device actually used, not the highest-priority one.
--
-- WirePlumber already keeps every output and input ever picked as a
-- most-recently-used stack in ~/.local/state/wireplumber/default-nodes, head
-- first. What it does with that stack is the problem. Upstream's
-- `default-nodes/find-stored-default-node` scores a stored device as
--
--     priority.session + 20001 - i        (i = slot in the stack)
--
-- so being one slot fresher is worth a single point while the hardware's own
-- `priority.session` differs by tens. The stack order is decorative and the
-- raw priority decides. Take the earbuds out and put them in their case and the
-- output does not go back to what was playing before them; it goes to the
-- highest-priority device ever selected on this machine, which on this box was
-- the onboard S/PDIF that nothing is plugged into.
--
-- The obvious fix was a rule demoting that one S/PDIF by node name, and it was
-- rejected: it hardcodes a PCI address, so new audio hardware silently stops
-- being handled. This hook is the general form of the same intent. It reads the
-- stack WirePlumber is already maintaining and picks the first entry that is
-- currently available, which is the definition of "the last one I used".
--
-- Deliberately additive: nothing upstream is disabled, and the hook declines to
-- choose in the two cases where upstream is already right.
--
--   * The configured device is still present. Then this is not a fallback at
--     all, it is a normal selection, and `find-selected-default-node` has it.
--     Bowing out here also means a fresh pick never races the state file, which
--     is written a second after the fact: the file is only ever consulted once
--     the configured device is gone, by which point the entries below it have
--     been settled for a long time.
--   * Nothing in the stack is available. A device never chosen before, on a
--     machine whose audio hardware just changed entirely, has no MRU answer to
--     give, so `find-best-default-node`'s hardware ranking is left to stand.
--
-- Applies to sinks, sources and cameras alike: the stack is kept per
-- `default-node.type` and the argument for outputs is the argument for inputs.

log = Log.open_topic ("s-default-nodes")

state = State ("default-nodes")

SimpleEventHook {
  name = "default-nodes/find-mru-default-node",
  -- Last of the four finders, so the value set here is what
  -- `apply-default-node` writes. `after` on every one of them rather than just
  -- `before = apply`: the scores are compared, not accumulated, and running
  -- last is the whole mechanism by which this wins.
  after = { "default-nodes/find-selected-default-node",
            "default-nodes/find-stored-default-node",
            "default-nodes/find-best-default-node" },
  before = { "default-nodes/apply-default-node" },
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-default-node" },
    },
  },
  execute = function (event)
    local props = event:get_properties ()
    local def_node_type = props ["default-node.type"]
    local available_nodes = event:get_data ("available-nodes")

    available_nodes = available_nodes and available_nodes:parse ()
    if not available_nodes then
      return
    end

    local function is_available (name)
      for _, node_props in ipairs (available_nodes) do
        if node_props ["node.name"] == name then
          return true
        end
      end
      return false
    end

    local source = event:get_source ()
    local metadata_om = source:call ("get-object-manager", "metadata")
    local metadata = metadata_om:lookup {
      Constraint { "metadata.name", "=", "default" },
    }
    local configured = metadata and
        metadata:find (0, "default.configured." .. def_node_type)

    -- Still plugged in: not a fallback, leave it to the hook that owns it.
    if configured and is_available (Json.Raw (configured):parse ().name) then
      return
    end

    -- Walk the stack head first. The keys are the bare one and then a `.N`
    -- run from 0, and a gap ends the stack rather than being skipped over.
    local key_base = "default.configured." .. def_node_type
    local key = key_base
    local index = 0
    local state_table = state:load ()

    while true do
      local name = state_table [key]
      if not name then
        return
      end

      if is_available (name) then
        log:info ("most recent available " .. def_node_type .. " is " .. name)
        -- Above the 30000 `find-selected-default-node` uses, so the intent is
        -- unambiguous to any hook added after this one.
        event:set_data ("selected-node-priority", 40000)
        event:set_data ("selected-node", name)
        return
      end

      key = key_base .. "." .. tostring (index)
      index = index + 1
    end
  end
}:register ()
