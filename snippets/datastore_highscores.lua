-- datastore_highscores.lua
-- Defensive Playdate datastore highscore helper.
-- Handles old save formats, coercion, sorting, and fixed-size top lists.

local pd <const> = playdate

local Highscores = {}
Highscores.__index = Highscores

local DEFAULT_NAMES <const> = { "PLAYER", "ACE001", "PILOT2", "CADET3", "ROOKIE" }

local function normalizeName(name, fallback)
  local out = tostring(name or "")
  out = string.upper(out)
  out = string.sub(out, 1, 6)
  if out == "" then
    out = fallback or "PLAYER"
  end
  return out
end

local function sortScores(scores)
  table.sort(scores, function(a, b)
    return ((a and a.score) or 0) > ((b and b.score) or 0)
  end)
end

local function defaultScores(seedScore)
  local scores = {}
  scores[1] = { name = DEFAULT_NAMES[1], score = tonumber(seedScore) or 0 }
  for i = 2, 5 do
    scores[i] = { name = DEFAULT_NAMES[i], score = 0 }
  end
  return scores
end

local function coerceScores(rawScores)
  if type(rawScores) ~= "table" then
    return nil
  end

  local legacyNameMap <const> = {
    AAA = "ACE001",
    PLY = "PLAYER",
    ROK = "ROOKIE",
  }

  local out = {}
  for i = 1, 10 do
    local entry = rawScores[i]
    if type(entry) == "table" then
      local name = normalizeName(entry.name, "---")
      name = legacyNameMap[name] or name
      out[#out + 1] = {
        name = string.sub(name, 1, 6),
        score = tonumber(entry.score) or 0,
      }
    end
  end

  if #out == 0 then
    return nil
  end

  sortScores(out)
  while #out > 5 do
    out[#out] = nil
  end
  return out
end

function Highscores.new(datastoreKey)
  return setmetatable({
    datastoreKey = datastoreKey or "save",
    scores = defaultScores(0),
    lastPlayerName = "PLAYER",
  }, Highscores)
end

function Highscores:load()
  local data = pd.datastore.read(self.datastoreKey) or pd.datastore.read() or {}

  self.scores = coerceScores(data.highscores) or defaultScores(data.hiscore or 0)
  self.lastPlayerName = normalizeName(data.lastPlayerName, "PLAYER")

  local topScore = (self.scores[1] and self.scores[1].score) or 0
  self.hiscore = math.max(tonumber(data.hiscore) or 0, topScore)
  return self.scores
end

function Highscores:qualifies(score)
  local s = tonumber(score) or 0
  if s <= 0 then
    return false
  end

  local lowest = (self.scores[#self.scores] and self.scores[#self.scores].score) or 0
  return #self.scores < 5 or s > lowest
end

function Highscores:record(score, playerName)
  local s = tonumber(score) or 0
  if not self:qualifies(s) then
    return false
  end

  local name = normalizeName(playerName, self.lastPlayerName)
  self.lastPlayerName = name

  self.scores[#self.scores + 1] = { name = name, score = s }
  sortScores(self.scores)
  while #self.scores > 5 do
    self.scores[#self.scores] = nil
  end

  self.hiscore = math.max(self.hiscore or 0, (self.scores[1] and self.scores[1].score) or 0)
  return true
end

function Highscores:save(extraData)
  local data = extraData or {}
  data.highscores = self.scores
  data.hiscore = self.hiscore or 0
  data.lastPlayerName = self.lastPlayerName or "PLAYER"
  pd.datastore.write(data, self.datastoreKey)
end

return Highscores
