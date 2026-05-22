-- crank_dual_weapon_aim.lua
-- Shared Playdate crank aiming for two weapon modes.
-- Inspired by Airborne's cannon/mortar split: one crank, two remembered aim states.

local pd <const> = playdate

local DualWeaponAim = {
  ticksPerRevolution = 6,
  crankTurnsDivisor = 3,
  activeMode = "cannon",

  cannonDirection = 0,
  cannonAngleRad = 0,
  cannonCos = 1,
  cannonSin = 0,
  cannonDirty = true,

  mortarDirection = 0,
  mortarAngleRad = math.rad(-78),
  mortarCos = math.cos(math.rad(-78)),
  mortarSin = math.sin(math.rad(-78)),
  mortarDirty = true,
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function DualWeaponAim:setMode(mode)
  if mode == "mortar" then
    self.activeMode = "mortar"
  else
    self.activeMode = "cannon"
  end
end

function DualWeaponAim:updateFromCrank()
  local ticks = pd.getCrankTicks(self.ticksPerRevolution)
  if not ticks or ticks == 0 then
    return
  end

  local delta = ticks / self.crankTurnsDivisor
  if self.activeMode == "mortar" then
    self.mortarDirection = self.mortarDirection + delta
    self.mortarDirty = true
  else
    self.cannonDirection = self.cannonDirection + delta
    self.cannonDirty = true
  end
end

function DualWeaponAim:updateCannonCache()
  if not self.cannonDirty then
    return
  end

  -- Match the projectile model. If your bullet moves by dx=3 and dy=-1+direction,
  -- deriving the visual angle from the same numbers keeps the barrel honest.
  local dx = 3
  local dy = -1 + self.cannonDirection
  local deg = math.deg(math.atan(dy, dx))
  deg = clamp(deg, -80, 15)

  self.cannonAngleRad = math.rad(deg)
  self.cannonCos = math.cos(self.cannonAngleRad)
  self.cannonSin = math.sin(self.cannonAngleRad)
  self.cannonDirty = false
end

function DualWeaponAim:updateMortarCache()
  if not self.mortarDirty then
    return
  end

  local range = self.mortarDirection / 3
  range = clamp(range, 0, 3.9)

  local t = range / 3.9
  local minDeg = -78
  local maxDeg = -35
  local deg = minDeg + (maxDeg - minDeg) * t

  self.mortarAngleRad = math.rad(deg)
  self.mortarCos = math.cos(self.mortarAngleRad)
  self.mortarSin = math.sin(self.mortarAngleRad)
  self.mortarDirty = false
end

function DualWeaponAim:getVector(mode)
  if mode == "mortar" then
    self:updateMortarCache()
    return self.mortarAngleRad, self.mortarCos, self.mortarSin
  end

  self:updateCannonCache()
  return self.cannonAngleRad, self.cannonCos, self.cannonSin
end

function DualWeaponAim:getSpawnPoint(mode, baseX, baseY, barrelLength)
  local _, cosAng, sinAng = self:getVector(mode)
  local len = barrelLength or 10
  return math.floor(baseX + cosAng * len), math.floor(baseY + sinAng * len)
end

function DualWeaponAim:drawBarrel(mode, baseX, baseY, barrelLength, gfx)
  gfx = gfx or playdate.graphics
  local x2, y2 = self:getSpawnPoint(mode, baseX, baseY, barrelLength)
  gfx.setColor(gfx.kColorBlack)
  gfx.setLineWidth(2)
  gfx.drawLine(baseX, baseY, x2, y2)
  gfx.setLineWidth(1)
end

-- Example loop:
--
-- DualWeaponAim:setMode(playerIsUsingMortar and "mortar" or "cannon")
-- DualWeaponAim:updateFromCrank()
-- DualWeaponAim:drawBarrel("cannon", playerX + 12, playerY + 8, 10)
--
-- if firePressed then
--   local x, y = DualWeaponAim:getSpawnPoint(DualWeaponAim.activeMode, muzzleX, muzzleY, 8)
--   spawnProjectile(x, y, DualWeaponAim.activeMode)
-- end

return DualWeaponAim
