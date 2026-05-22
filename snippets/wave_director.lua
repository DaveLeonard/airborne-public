-- wave_director.lua
-- Data-driven wave director for Playdate arcade games.
-- Shows caps, late scheduled spawns, endless scaling, and approach audio timing.

local pd <const> = playdate

local WaveDirector = {}
WaveDirector.__index = WaveDirector

local BASE_WAVES <const> = {
  { scouts = 5,  heavies = 0, elites = 0, durationMs = 60000, spawnScale = 0.75, scoutCap = 2 },
  { scouts = 10, heavies = 1, elites = 0, durationMs = 52000, spawnScale = 1.15, scoutCap = 3, heavyCap = 1 },
  { scouts = 14, heavies = 2, elites = 1, durationMs = 50000, spawnScale = 1.35, scoutCap = 4, heavyCap = 2, eliteCap = 1 },
}

local function clone(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

function WaveDirector.new(opts)
  return setmetatable({
    waves = opts and opts.waves or BASE_WAVES,
    factories = opts and opts.factories or {},
    sound = opts and opts.sound,
    waveIndex = 0,
    spawned = {},
    screenCounts = { scouts = 0, heavies = 0, elites = 0 },
    lastSpawnMs = { scouts = 0, heavies = 0 },
  }, WaveDirector)
end

function WaveDirector:buildWave(index)
  if index <= #self.waves then
    return clone(self.waves[index])
  end

  local base = self.waves[#self.waves]
  local extra = index - #self.waves
  return {
    scouts = base.scouts + extra * 4,
    heavies = base.heavies + math.floor(extra / 2),
    elites = base.elites + math.floor(extra / 4),
    durationMs = math.max(42000, (base.durationMs or 50000) - extra * 250),
    spawnScale = math.min((base.spawnScale or 1) + extra * 0.08, 2.2),
    scoutCap = math.min((base.scoutCap or 4) + math.floor(extra / 3), 8),
    heavyCap = base.heavyCap or 2,
    eliteCap = base.eliteCap or 1,
  }
end

function WaveDirector:startNextWave(nowMs)
  self.waveIndex = self.waveIndex + 1
  self.currentWave = self:buildWave(self.waveIndex)
  self.waveStartMs = nowMs or pd.getCurrentTimeMilliseconds()
  self.spawned = { scouts = 0, heavies = 0, elites = 0 }
  self.lastSpawnMs = { scouts = 0, heavies = 0 }

  -- Elites read better if they arrive near the end instead of instantly.
  self.eliteSchedule = {}
  local eliteTotal = self.currentWave.elites or 0
  local startFrac, endFrac = 0.62, 0.92
  for i = 1, eliteTotal do
    local frac = eliteTotal == 1 and endFrac or startFrac + (i - 1) * ((endFrac - startFrac) / math.max(eliteTotal - 1, 1))
    self.eliteSchedule[i] = self.waveStartMs + math.floor(self.currentWave.durationMs * frac) + math.random(-700, 700)
  end
  self.eliteScheduleIndex = 1

  -- Approach warning before the first elite appears.
  self.incomingEliteAtMs = nil
end

function WaveDirector:trySpawn(kind, nowMs, intervalMs, cap, factory)
  if self.spawned[kind] >= (self.currentWave[kind] or 0) then
    return
  end
  if self.screenCounts[kind] >= cap then
    return
  end
  if nowMs - (self.lastSpawnMs[kind] or 0) < intervalMs then
    return
  end

  factory()
  self.spawned[kind] = self.spawned[kind] + 1
  self.screenCounts[kind] = self.screenCounts[kind] + 1
  self.lastSpawnMs[kind] = nowMs
end

function WaveDirector:update(nowMs)
  if not self.currentWave then
    self:startNextWave(nowMs)
  end

  local wave = self.currentWave
  local spawnScale = wave.spawnScale or 1

  self:trySpawn("scouts", nowMs, math.floor(math.random(3800, 7200) / spawnScale), wave.scoutCap or 3, self.factories.scout)
  self:trySpawn("heavies", nowMs, math.floor(math.random(12000, 20000) / spawnScale), wave.heavyCap or 1, self.factories.heavy)

  local scheduledAt = self.eliteSchedule and self.eliteSchedule[self.eliteScheduleIndex or 1]
  if scheduledAt and self.spawned.elites < (wave.elites or 0) and self.screenCounts.elites < (wave.eliteCap or 1) then
    if not self.incomingEliteAtMs and nowMs >= scheduledAt - 4000 then
      self.incomingEliteAtMs = scheduledAt
      if self.sound then
        self.sound:setVolume(0.05, 0.05)
        self.sound:play()
        local fade = pd.timer.new(4000, 0.05, 1.0, playdate.easingFunctions.inCubic)
        fade.updateCallback = function(timer)
          if self.sound and self.sound.setVolume then
            self.sound:setVolume(timer.value, timer.value)
          end
        end
      end
    end

    if nowMs >= scheduledAt then
      self.factories.elite()
      self.spawned.elites = self.spawned.elites + 1
      self.screenCounts.elites = self.screenCounts.elites + 1
      self.eliteSchedule[self.eliteScheduleIndex] = nil
      self.eliteScheduleIndex = self.eliteScheduleIndex + 1
      self.incomingEliteAtMs = nil
    end
  end

  if nowMs - self.waveStartMs >= (wave.durationMs or 50000) then
    self:startNextWave(nowMs)
  end
end

return WaveDirector
