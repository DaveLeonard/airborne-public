-- dithered_banner_sprite.lua
-- Cheap animated text banner for Playdate.
-- It precomputes dithered fade frames once, then only swaps images in update().

local pd <const> = playdate
local gfx <const> = pd.graphics

class("DitheredBanner").extends(gfx.sprite)

function DitheredBanner:init(text, opts)
  DitheredBanner.super.init(self)

  opts = opts or {}
  self.text = tostring(text or "READY")
  self.font = opts.font or gfx.getSystemFont()
  self.holdMs = opts.holdMs or 900
  self.fadeMs = opts.fadeMs or 500
  self.scale = opts.scale or 2
  self.zIndex = opts.zIndex or 1000
  self.finished = false

  self.pulse = opts.pulse or false
  self.pulseHz = opts.pulseHz or 8
  self.pulseMinScale = opts.pulseMinScale or self.scale * 0.9
  self.pulseMaxScale = opts.pulseMaxScale or self.scale * 1.15

  self.zoomIn = opts.zoomIn or false
  self.zoomInMs = opts.zoomInMs or 120
  self.zoomInFromScale = opts.zoomInFromScale or self.scale * 1.55

  local paddingX = opts.paddingX or 16
  local paddingY = opts.paddingY or 10
  local textW = self.font:getTextWidth(self.text)
  local textH = self.font:getHeight()
  local w = textW + paddingX * 2
  local h = textH + paddingY * 2

  self.baseImage = gfx.image.new(w, h, gfx.kColorClear)
  gfx.pushContext(self.baseImage)
    gfx.setFont(self.font)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned(self.text, w / 2, (h - textH) / 2, kTextAlignment.center)
  gfx.popContext()

  self.fadeStepCount = opts.fadeStepCount or 9
  self.fadeSteps = {}
  local dither = opts.ditherType or gfx.image.kDitherTypeBayer8x8
  for i = 0, self.fadeStepCount - 1 do
    local alpha = i / (self.fadeStepCount - 1)
    self.fadeSteps[i] = self.baseImage:fadedImage(alpha, dither)
  end

  self.startMs = pd.getCurrentTimeMilliseconds()
  self:setCenter(opts.centerX or 0.5, opts.centerY or 0.5)
  self:moveTo(opts.x or 200, opts.y or 120)
  self:setZIndex(self.zIndex)
  self:setIgnoresDrawOffset(opts.ignoresDrawOffset ~= false)
  self:setScale(self.scale)
  self:setImage(self.fadeSteps[self.fadeStepCount - 1])
  self:add()
end

function DitheredBanner:isFinished()
  return self.finished
end

function DitheredBanner:update()
  if self.finished then
    return
  end

  local elapsed = pd.getCurrentTimeMilliseconds() - self.startMs

  if elapsed < self.holdMs then
    self:setImage(self.fadeSteps[self.fadeStepCount - 1])

    if self.zoomIn and elapsed < self.zoomInMs then
      local t = elapsed / self.zoomInMs
      t = 1 - (1 - t) * (1 - t)
      self:setScale(self.zoomInFromScale + (self.scale - self.zoomInFromScale) * t)
    elseif self.pulse then
      local phase = (math.sin((elapsed / 1000) * self.pulseHz * math.pi * 2) * 0.5) + 0.5
      self:setScale(self.pulseMinScale + (self.pulseMaxScale - self.pulseMinScale) * phase)
    else
      self:setScale(self.scale)
    end

    return
  end

  local fadeT = (elapsed - self.holdMs) / self.fadeMs
  if fadeT >= 1 then
    self.finished = true
    self:remove()
    return
  end

  local alpha = 1 - fadeT
  local idx = math.floor(alpha * (self.fadeStepCount - 1) + 0.5)
  if idx < 0 then idx = 0 end
  if idx > self.fadeStepCount - 1 then idx = self.fadeStepCount - 1 end
  self:setImage(self.fadeSteps[idx])
end

return DitheredBanner
