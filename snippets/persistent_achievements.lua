-- persistent_achievements.lua
-- Persistent achievements for Playdate games without taking ownership of your save file.
-- Store the returned state inside your existing datastore table.

local pd <const> = playdate

local PersistentAchievements = {}
PersistentAchievements.__index = PersistentAchievements

local function emptyState()
  return {
    version = 1,
    unlocked = {},
    counters = {},
  }
end

local function coerceState(raw, definitions)
  local state = emptyState()
  if type(raw) ~= "table" then
    return state
  end

  if type(raw.unlocked) == "table" then
    for id, value in pairs(raw.unlocked) do
      if definitions[id] and value then
        state.unlocked[id] = value
      end
    end
  end

  if type(raw.counters) == "table" then
    for key, value in pairs(raw.counters) do
      if type(key) == "string" and type(value) == "number" then
        state.counters[key] = math.max(0, value)
      end
    end
  end
  return state
end

function PersistentAchievements.new(definitionList, opts)
  assert(type(definitionList) == "table", "Achievement definitions are required")

  local byId = {}
  for i = 1, #definitionList do
    local definition = definitionList[i]
    assert(definition.id and definition.title, "Each achievement needs id and title")
    byId[definition.id] = definition
  end

  opts = opts or {}
  return setmetatable({
    list = definitionList,
    definitions = byId,
    state = emptyState(),
    pendingNotifications = {},
    onUnlocked = opts.onUnlocked,
  }, PersistentAchievements)
end

-- Load only this subsystem from a larger save table.
function PersistentAchievements:loadFromSave(saveData)
  local raw = type(saveData) == "table" and saveData.achievements or nil
  self.state = coerceState(raw, self.definitions)
  self.pendingNotifications = {}
  return self.state
end

-- Merge the achievement state into a save table owned by the game.
function PersistentAchievements:writeToSave(saveData)
  saveData = saveData or {}
  saveData.achievements = self.state
  return saveData
end

function PersistentAchievements:isUnlocked(id)
  return self.state.unlocked[id] ~= nil
end

function PersistentAchievements:unlockedCount()
  local count = 0
  for i = 1, #self.list do
    if self:isUnlocked(self.list[i].id) then
      count = count + 1
    end
  end
  return count
end

function PersistentAchievements:unlock(id)
  local definition = self.definitions[id]
  if not definition or self:isUnlocked(id) then
    return false
  end

  self.state.unlocked[id] = {
    earnedAt = pd.getSecondsSinceEpoch(),
  }
  self.pendingNotifications[#self.pendingNotifications + 1] = definition
  if self.onUnlocked then
    self.onUnlocked(definition)
  end
  return true
end

-- Record an event such as "wave_cleared" or "missile_intercepted".
-- An event achievement may optionally provide a predicate(payload, state).
function PersistentAchievements:recordEvent(eventName, payload)
  for i = 1, #self.list do
    local definition = self.list[i]
    if definition.event == eventName and not self:isUnlocked(definition.id) then
      local matches = not definition.predicate or definition.predicate(payload or {}, self.state)
      if matches then
        self:unlock(definition.id)
      end
    end
  end
end

-- Counters survive between runs; use them for long-term milestones.
function PersistentAchievements:increment(counterName, amount)
  amount = amount or 1
  local newValue = (self.state.counters[counterName] or 0) + amount
  self.state.counters[counterName] = math.max(0, newValue)

  for i = 1, #self.list do
    local definition = self.list[i]
    if definition.counter == counterName and not self:isUnlocked(definition.id) then
      if self.state.counters[counterName] >= (definition.target or 1) then
        self:unlock(definition.id)
      end
    end
  end
  return self.state.counters[counterName]
end

-- Use this to display unlock banners one at a time.
function PersistentAchievements:popNotification()
  if #self.pendingNotifications == 0 then
    return nil
  end
  return table.remove(self.pendingNotifications, 1)
end

-- Reset achievements only. Highscores/options remain in the owning save table.
-- Put this action behind a confirmation screen.
function PersistentAchievements:reset()
  self.state = emptyState()
  self.pendingNotifications = {}
end

-- Example:
--
-- local Decorations = PersistentAchievements.new({
--   {
--     id = "first_wave",
--     title = "FIRST SORTIE",
--     event = "wave_cleared",
--     predicate = function(data) return data.wave >= 1 end,
--   },
--   {
--     id = "intercept",
--     title = "MISSILE INTERCEPT",
--     event = "missile_intercepted",
--   },
--   {
--     id = "veteran",
--     title = "TOUR OF DUTY",
--     counter = "wavesCleared",
--     target = 10,
--   },
-- })
--
-- local save = playdate.datastore.read() or {}
-- Decorations:loadFromSave(save)
--
-- function onWaveCleared(wave)
--   Decorations:recordEvent("wave_cleared", { wave = wave })
--   Decorations:increment("wavesCleared")
--   playdate.datastore.write(Decorations:writeToSave(save))
-- end
--
-- function drawUnlockBanner()
--   local earned = Decorations:popNotification()
--   if earned then
--     showBanner("DECORATION: " .. earned.title)
--   end
-- end
--
-- function confirmAchievementReset()
--   Decorations:reset()
--   playdate.datastore.write(Decorations:writeToSave(save))
-- end

return PersistentAchievements
