-- !RealmFix 2.0: temporary workaround for Forever client build 71037 (Nov 18 2026),
-- where GetRealmName() and GetNormalizedRealmName() return "".
-- When the game gives a real name, it is passed through unchanged and remembered for that
-- server number. When the game gives "", the name is looked up from the character's GUID
-- ("Player-<server>-<id>"). Loads before DataStore because of the "!" in the folder name.
-- /realmfix prints what the game returns now, so you can tell when Blizzard has fixed it.

-- Server number -> realm name. The server number is the first number in a character's
-- GUID ("Player-<server>-<id>"). Add your own realms here; realms the game names while
-- this add-on is loaded are learned automatically and saved in RealmFixDB.
local SEED = {
  ["6796"] = "CAMWOW US2 Realm 1 PvE",
}
-- Used only if the GUID isn't available yet when the realm is first asked for (logged as
-- "default"). Set it to your main realm, or to "" to never guess.
local DEFAULT = "CAMWOW US2 Realm 1 PvE"
local LOG_MAX = 40

local origGet, origNorm = GetRealmName, GetNormalizedRealmName
local resolved, resolvedHow          -- cached for this session once known from a GUID or the game
local logged = {}

local function db()
  -- RealmFixDB is loaded right after this file runs, before DataStore's files run.
  if type(RealmFixDB) ~= "table" then RealmFixDB = {} end
  RealmFixDB.map = RealmFixDB.map or {}
  RealmFixDB.log = RealmFixDB.log or {}
  return RealmFixDB
end

local function serverOf(guid)
  return type(guid) == "string" and guid:match("^Player%-(%d+)%-") or nil
end

local function note(how, sid, name)
  if logged[how] then return end
  logged[how] = true
  local log = db().log
  log[#log + 1] = { at = time and time() or 0, how = how, server = sid, realm = name,
                    game = tostring(origGet and origGet()), build = select(2, GetBuildInfo()) }
  while #log > LOG_MAX do table.remove(log, 1) end
end

local function lookup(sid)
  if not sid then return nil end
  local m = db().map
  return m[sid] or SEED[sid]
end

local function resolve()
  local r = origGet()
  local sid = serverOf(UnitGUID and UnitGUID("player"))
  if r ~= nil and r ~= "" then
    if sid then db().map[sid] = r end         -- learn real names whenever the game gives them
    note("game", sid, r)
    return r, "game"
  end
  if resolved then return resolved, resolvedHow end
  local name = lookup(sid)
  if name then
    resolved, resolvedHow = name, "guid"
    note("guid", sid, name)
    return name, "guid"
  end
  if sid then
    -- A realm never seen before: refuse to guess so no character is filed on the wrong realm.
    note("unknown-server", sid, "")
    return r or "", "unknown"
  end
  note("default", nil, DEFAULT)               -- GUID not available yet this early in login
  return DEFAULT, "default"
end

GetRealmName = function()
  return (resolve())
end

GetNormalizedRealmName = function()
  local r = origNorm and origNorm()
  if r ~= nil and r ~= "" then return r end
  local name = resolve()
  if name == "" then return r end
  return (name:gsub("[%s%-]", ""))
end

SLASH_REALMFIX1 = "/realmfix"
SlashCmdList.REALMFIX = function()
  local game = origGet()
  local name, how = resolve()
  local sid = serverOf(UnitGUID("player"))
  print(string.format("|cff33ff99!RealmFix|r game returns: \"%s\"  |  using: \"%s\" (%s)  |  server: %s",
    tostring(game), tostring(name), tostring(how), tostring(sid)))
  if game ~= nil and game ~= "" then
    print("|cff33ff99!RealmFix|r The game is returning the realm name again: you can test removing !RealmFix.")
  end
end
