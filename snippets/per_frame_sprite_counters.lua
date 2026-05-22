-- per_frame_sprite_counters.lua
-- Cache expensive global sprite/table counts once per frame.
-- Useful when many Playdate sprites ask "how many enemies are on screen?"

local pd <const> = playdate

local SpriteCounters = {
  processedAtMs = -1,
  airborne = 0,
  grounded = 0,
  total = 0,
}

local TAGS <const> = {
  airborne = 1,
  infantry = 2,
  runner = 3,
  stuck = 4,
}

local function isGrounded(tag)
  return tag == TAGS.infantry or tag == TAGS.runner
end

local function isTracked(tag)
  return tag == TAGS.airborne or tag == TAGS.infantry or tag == TAGS.runner or tag == TAGS.stuck
end

local function isAirborne(sprite, tag)
  if tag ~= TAGS.airborne or not sprite or not sprite.getPosition then
    return false
  end

  local _, y = sprite:getPosition()
  return y and y < 202
end

function SpriteCounters:updateOncePerFrame(spriteTable, nowMs)
  nowMs = nowMs or pd.getCurrentTimeMilliseconds()
  if self.processedAtMs == nowMs then
    return
  end

  self.processedAtMs = nowMs
  self.airborne = 0
  self.grounded = 0
  self.total = 0

  for key, sprite in pairs(spriteTable) do
    if not sprite or not sprite.getTag then
      spriteTable[key] = nil
    else
      local tag = sprite:getTag()
      if isTracked(tag) then
        self.total = self.total + 1
      end
      if isGrounded(tag) then
        self.grounded = self.grounded + 1
      end
      if isAirborne(sprite, tag) then
        self.airborne = self.airborne + 1
      end
    end
  end
end

function SpriteCounters:canSpawnAirborne(spriteTable, maxAirborne, maxTotal, nowMs)
  self:updateOncePerFrame(spriteTable, nowMs)
  return self.airborne < maxAirborne and self.total < maxTotal
end

function SpriteCounters:groundedCount(spriteTable, nowMs)
  self:updateOncePerFrame(spriteTable, nowMs)
  return self.grounded
end

-- Optional: maintain counters immediately when your game changes tags.
-- This avoids waiting until the next scan in systems that need exact values.
function SpriteCounters:setTrackedTag(sprite, newTag)
  if not sprite then
    return
  end

  local oldTag = sprite._trackedTag
  if oldTag == newTag then
    sprite:setTag(newTag)
    return
  end

  if isTracked(oldTag) then
    self.total = math.max(0, self.total - 1)
  end
  if isGrounded(oldTag) then
    self.grounded = math.max(0, self.grounded - 1)
  end
  if isAirborne(sprite, oldTag) then
    self.airborne = math.max(0, self.airborne - 1)
  end

  sprite:setTag(newTag)
  sprite._trackedTag = newTag

  if isTracked(newTag) then
    self.total = self.total + 1
  end
  if isGrounded(newTag) then
    self.grounded = self.grounded + 1
  end
  if isAirborne(sprite, newTag) then
    self.airborne = self.airborne + 1
  end
end

return SpriteCounters
