-- timed_fx_sequence.lua
-- Tiny timeline helper for Playdate explosions, screen shake, and audio cleanup.
-- Useful for game-over beats, boss deaths, or scripted arcade moments.

local pd <const> = playdate

local TimedFxSequence = {}
TimedFxSequence.__index = TimedFxSequence

function TimedFxSequence.new(opts)
  opts = opts or {}
  return setmetatable({
    events = opts.events or {},
    nextIndex = 1,
    startMs = opts.startMs or pd.getCurrentTimeMilliseconds(),
    finished = false,
    onFinished = opts.onFinished,
  }, TimedFxSequence)
end

function TimedFxSequence:update(nowMs)
  if self.finished then
    return true
  end

  nowMs = nowMs or pd.getCurrentTimeMilliseconds()
  local elapsed = nowMs - self.startMs
  local i = self.nextIndex

  while self.events[i] and elapsed >= self.events[i].at do
    local event = self.events[i]
    if event.fn then
      event.fn(event, elapsed)
    end
    i = i + 1
  end

  self.nextIndex = i
  if i > #self.events then
    self.finished = true
    if self.onFinished then
      self.onFinished()
    end
  end

  return self.finished
end

local function screenShake(durationMs, magnitude)
  local timer = pd.timer.new(durationMs, magnitude or 2, 0)
  timer.updateCallback = function(t)
    local m = math.floor(t.value)
    playdate.display.setOffset(math.random(-m, m), math.random(-m, m))
  end
  timer.timerEndedCallback = function()
    playdate.display.setOffset(0, 0)
  end
  return timer
end

local function fadeOutAndStop(sample, durationMs)
  if not sample or not sample.getVolume then
    return nil
  end

  local left = sample:getVolume()
  left = left or 1
  local timer = pd.timer.new(durationMs or 1000, left, 0)
  timer.updateCallback = function(t)
    if sample.setVolume then
      sample:setVolume(t.value, t.value)
    end
  end
  timer.timerEndedCallback = function()
    if sample.stop then
      sample:stop()
    end
    if sample.setVolume then
      sample:setVolume(1, 1)
    end
  end
  return timer
end

TimedFxSequence.screenShake = screenShake
TimedFxSequence.fadeOutAndStop = fadeOutAndStop

-- Example usage:
--
-- local seq = TimedFxSequence.new({
--   events = {
--     { at = 0, fn = function() spawnExplosion(baseX, baseY, 4) end },
--     { at = 120, fn = function() screenShake(350, 3) end },
--     { at = 250, fn = function() spawnExplosion(baseX - 18, baseY + 8, 2) end },
--     { at = 500, fn = function() spawnExplosion(baseX + 22, baseY - 6, 2) end },
--     { at = 850, fn = function() fadeOutAndStop(loopingAmbience, 900) end },
--   },
--   onFinished = function()
--     enterGameOverScreen()
--   end,
-- })
--
-- function playdate.update()
--   seq:update()
--   gfx.sprite.update()
--   pd.timer.updateTimers()
-- end

return TimedFxSequence
