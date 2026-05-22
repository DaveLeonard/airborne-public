-- splash_damage_hitboxes.lua
-- Fair splash damage checks for Playdate sprites.
-- Uses squared distance for point targets and nearest-point distance for rectangles.

local SplashDamage = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function withinRadius2(cx, cy, ex, ey, radius)
  local dx = cx - ex
  local dy = cy - ey
  return (dx * dx + dy * dy) <= (radius * radius)
end

function SplashDamage.pointTarget(sprite, ex, ey, radius, offsetX, offsetY)
  if not sprite or not sprite.getPosition then
    return false
  end

  local x, y = sprite:getPosition()
  local cx = x + (offsetX or 0)
  local cy = y + (offsetY or 0)
  return withinRadius2(cx, cy, ex, ey, radius)
end

function SplashDamage.rectTarget(sprite, ex, ey, radius, rect)
  if not sprite or not sprite.getPosition or not rect then
    return false
  end

  local x, y = sprite:getPosition()
  local left = x + (rect.x or 0)
  local top = y + (rect.y or 0)
  local right = left + (rect.w or 0)
  local bottom = top + (rect.h or 0)

  -- Nearest point on the rectangle to the explosion center.
  -- This makes edge hits feel fair for large enemies like tanks or bosses.
  local nx = clamp(ex, left, right)
  local ny = clamp(ey, top, bottom)
  return withinRadius2(nx, ny, ex, ey, radius)
end

function SplashDamage.apply(opts)
  assert(opts and opts.ex and opts.ey and opts.radius, "SplashDamage.apply requires ex, ey, and radius")

  local killed = 0
  local tags = opts.tags or {}
  local onHit = opts.onHit or function(sprite)
    if sprite.setTag and opts.deadTag then
      sprite:setTag(opts.deadTag)
    end
  end

  for _, sprite in pairs(opts.sprites or {}) do
    if sprite and sprite.getTag then
      local tag = sprite:getTag()
      local rule = tags[tag]
      if rule then
        local hit = false
        if rule.rect then
          hit = SplashDamage.rectTarget(sprite, opts.ex, opts.ey, opts.radius, rule.rect)
        else
          hit = SplashDamage.pointTarget(sprite, opts.ex, opts.ey, opts.radius, rule.offsetX, rule.offsetY)
        end

        if hit then
          onHit(sprite, tag)
          killed = killed + 1
        end
      end
    end
  end

  return killed
end

-- Example usage:
--
-- local killed = SplashDamage.apply({
--   ex = impactX,
--   ey = impactY,
--   radius = 16,
--   sprites = enemies,
--   deadTag = TAGS.dead,
--   tags = {
--     [TAGS.infantry] = { offsetX = 7.5, offsetY = 10 },
--     [TAGS.runner] = { offsetX = 7.5, offsetY = 10 },
--     [TAGS.tank] = { rect = { x = 0, y = 25, w = 40, h = 14 } },
--   },
--   onHit = function(sprite, tag)
--     if sprite.onDestroyed then
--       sprite:onDestroyed(tag)
--     else
--       sprite:setTag(TAGS.dead)
--     end
--   end,
-- })

return SplashDamage
