-- Attunement blockers: one "Blocked:" line per raid the player can't enter yet.
-- Pure: the caller passes readers for item location and quest completion.
local _, ns = ...
local Attune = {}
ns.Attune = Attune

-- opts: raids (keys of ns.Attunements, e.g. {"ONYXIA"}), faction ("Alliance" | "Horde"),
-- itemPlace(itemID) -> "bags" | "bank" | nil, questDone(questID) -> boolean.
-- Returns a list of { raid, text, done, total, next } (done/total/next: the attunement chain).
function Attune.blockers(opts)
  local out = {}
  for _, key in ipairs(opts.raids) do
    local a = ns.Attunements[key]
    if a then
      local place = opts.itemPlace(a.item)
      if place == "bank" then
        out[#out + 1] = { raid = a.raid,
          text = "Blocked: " .. a.itemName .. " is in your bank (carry it into " .. a.raid .. ")" }
      elseif place ~= "bags" then
        local chain = a.chains[opts.faction] or {}
        local done, nextStep = 0, nil
        for _, q in ipairs(chain) do
          if opts.questDone(q[1]) then
            done = done + 1
          elseif not nextStep then
            nextStep = q[2]
          end
        end
        out[#out + 1] = { raid = a.raid, text = "Blocked: " .. a.itemName .. " missing for " .. a.raid,
          done = done, total = #chain, next = nextStep }
      end
    end
  end
  return out
end
