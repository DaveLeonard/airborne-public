-- playdate_object_pool.lua
-- Bounded pooling pattern for Playdate sprites.
-- Inspired by Airborne's bullets, missiles, grenades, and explosion sprites.

local pd <const> = playdate

local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(opts)
  assert(opts and opts.create, "ObjectPool.new requires a create() function")

  return setmetatable({
    create = opts.create,
    reset = opts.reset,
    onRelease = opts.onRelease,
    pool = {},
    poolCount = 0,
    poolMax = opts.poolMax or 32,
    active = {},
    freeIds = {},
    freeIdsCount = 0,
    freeIdsMax = opts.freeIdsMax or 256,
    nextId = 1,
  }, ObjectPool)
end

function ObjectPool:acquireId()
  if self.freeIdsCount > 0 then
    local id = self.freeIds[self.freeIdsCount]
    self.freeIds[self.freeIdsCount] = nil
    self.freeIdsCount = self.freeIdsCount - 1
    return id
  end

  local id = self.nextId
  self.nextId = self.nextId + 1
  return id
end

function ObjectPool:releaseId(id)
  if not id then
    return
  end

  if self.freeIdsCount < self.freeIdsMax then
    self.freeIdsCount = self.freeIdsCount + 1
    self.freeIds[self.freeIdsCount] = id
  end
end

function ObjectPool:spawn(...)
  local id = self:acquireId()
  local obj

  if self.poolCount > 0 then
    obj = self.pool[self.poolCount]
    self.pool[self.poolCount] = nil
    self.poolCount = self.poolCount - 1

    if obj.add then
      obj:add()
    end
    if self.reset then
      self.reset(obj, ...)
    elseif obj.reset then
      obj:reset(...)
    end
  else
    obj = self.create(...)
  end

  obj._poolId = id
  self.active[id] = obj
  return obj, id
end

function ObjectPool:release(id)
  local obj = self.active[id]
  if not obj then
    return
  end

  self.active[id] = nil
  self:releaseId(id)

  if self.onRelease then
    self.onRelease(obj)
  end
  if obj.remove then
    obj:remove()
  end

  if self.poolCount < self.poolMax then
    self.poolCount = self.poolCount + 1
    self.pool[self.poolCount] = obj
  end
end

function ObjectPool:cleanup(isExpired)
  for id, obj in pairs(self.active) do
    if (not obj) or isExpired(obj) then
      self:release(id)
    end
  end
end

-- Example usage:
--
-- local bulletPool = ObjectPool.new({
--   poolMax = 64,
--   create = function(x, y, angle)
--     return Bullet(x, y, angle)
--   end,
--   reset = function(bullet, x, y, angle)
--     bullet:reset(x, y, angle)
--   end,
-- })
--
-- bulletPool:spawn(30, 190, playdate.getCrankPosition())
-- bulletPool:cleanup(function(bullet)
--   local x, y = bullet:getPosition()
--   return x < -20 or x > 420 or y < -20 or y > 260 or bullet:getTag() == TAGS.dead
-- end)

return ObjectPool
