-- !RealmFix 2.2: temporary workaround for WoW Forever client build 71037 (Nov 18 2026),
-- where GetRealmName() and GetNormalizedRealmName() return "".
--
-- When the game gives a real name, it is passed through unchanged and remembered for that
-- server number. When the game gives "", the name is looked up from the character's GUID
-- ("Player-<server>-<id>"), using, in order: names you set with /realmfix set, names learned
-- (from the game, or from DataStore's saved character list), then the built-in SEED table.
-- An unknown server number is left blank: !RealmFix never guesses.
-- Loads before DataStore because of the "!" in the folder name.
--
-- /realmfix          status: what the game returns now and which name is used
-- /realmfix set <realm name>   save the realm name for the character you're playing
-- /realmfix report   copyable report of known realms, to post as a GitHub "Realm report"

local VERSION = "2.2"
local ISSUES_URL = "github.com/shawn571/RealmFix/issues"

-- Server number -> realm name, from community realm reports. Add more via GitHub issues.
local SEED = {
  ["6796"] = "CAMWOW US2 Realm 1 PvE",
}
-- Used only if the GUID isn't available yet when the realm is first asked for.
-- "" means never guess (recommended).
local DEFAULT = ""
local LOG_MAX = 40

local origGet, origNorm = GetRealmName, GetNormalizedRealmName
local resolved, resolvedHow          -- cached for this session once known
local logged = {}
local unknownServer                  -- server number we couldn't name this session

local function msg(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99!RealmFix|r " .. text) end
end

local function db()
  -- RealmFixDB is loaded right after this file runs, before DataStore's files run.
  if type(RealmFixDB) ~= "table" then RealmFixDB = {} end
  RealmFixDB.map = RealmFixDB.map or {}      -- server -> realm name (learned or set)
  RealmFixDB.src = RealmFixDB.src or {}      -- server -> "game" | "datastore" | "player"
  RealmFixDB.log = RealmFixDB.log or {}
  return RealmFixDB
end

local function serverOf(guid)
  return type(guid) == "string" and guid:match("^Player%-(%d+)%-") or nil
end

local function myServer()
  return serverOf(UnitGUID and UnitGUID("player"))
end

local function buildNumber()
  if GetBuildInfo then return tostring(select(2, GetBuildInfo())) end
  return "?"
end

local function note(how, sid, name)
  local key = how .. ":" .. tostring(sid)
  if logged[key] then return end
  logged[key] = true
  local log = db().log
  log[#log + 1] = { at = time and time() or 0, how = how, server = sid, realm = name,
                    game = tostring(origGet and origGet()), build = buildNumber() }
  while #log > LOG_MAX do table.remove(log, 1) end
end

-- Save a name for a server. Returns true if it was new or changed.
local function learn(sid, name, src)
  if not sid or type(name) ~= "string" or name == "" then return false end
  local d = db()
  if d.src[sid] == "player" and src ~= "player" then return false end -- your own choice wins
  if d.map[sid] == name then
    if not d.src[sid] then d.src[sid] = src end
    return false
  end
  if d.map[sid] and d.map[sid] ~= name then note("conflict(" .. tostring(d.map[sid]) .. ")", sid, name) end
  d.map[sid] = name
  d.src[sid] = src
  return true
end

local function lookup(sid)
  if not sid then return nil end
  local m = db().map
  return m[sid] or SEED[sid]
end

local function resolve()
  local r = origGet()
  local sid = myServer()
  if r ~= nil and r ~= "" then
    learn(sid, r, "game")
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
    unknownServer = sid
    note("unknown-server", sid, "")
    return r or "", "unknown"
  end
  if DEFAULT ~= "" then
    note("default", nil, DEFAULT)
    return DEFAULT, "default"
  end
  note("no-guid", nil, "")
  return r or "", "unknown"
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

-- Learn server -> realm from DataStore's saved character list (characters it saw before the
-- bug still have their realm in the key "Account.Realm.Name", and their GUIDs in the same order).
-- Read-only: DataStore's data is never changed.
local function learnFromDataStore()
  local ids, guids = _G.DataStore_CharacterIDs, _G.DataStore_CharacterGUIDs
  if type(ids) ~= "table" or type(ids.List) ~= "table" or type(guids) ~= "table" then return 0 end
  local added = 0
  for i, key in ipairs(ids.List) do
    local realm = type(key) == "string" and key:match("^[^%.]*%.(.*)%.[^%.]*$")
    local sid = serverOf(guids[i])
    if realm and realm ~= "" and sid then
      if learn(sid, realm, "datastore") then added = added + 1 end
    end
  end
  return added
end

local function realmList()
  local seen, list = {}, {}
  local d = db()
  for sid, name in pairs(d.map) do seen[sid] = true; list[#list + 1] = { sid, name, d.src[sid] or "learned" } end
  for sid, name in pairs(SEED) do if not seen[sid] then list[#list + 1] = { sid, name, "built-in" } end end
  table.sort(list, function(a, b) return tonumber(a[1]) < tonumber(b[1]) end)
  return list
end

-- Report text: realm data only. No character names, no GUIDs.
local function reportText()
  local lines = {
    "!RealmFix " .. VERSION .. " realm report",
    "client build: " .. buildNumber() .. "   locale: " .. tostring(GetLocale and GetLocale() or "?"),
    "game realm name now: \"" .. tostring(origGet()) .. "\"",
    "current server number: " .. tostring(myServer() or "?"),
    "known realms (server = name [source]):",
  }
  for _, e in ipairs(realmList()) do
    lines[#lines + 1] = "  " .. e[1] .. " = " .. e[2] .. " [" .. e[3] .. "]"
  end
  if unknownServer then lines[#lines + 1] = "  " .. unknownServer .. " = (unknown, please add its realm name)" end
  lines[#lines + 1] = "Region (Americas/Oceania, Europe, other) and whether you play from AU: "
  return table.concat(lines, "\n")
end

local reportFrame
local function showReport()
  local text = reportText()
  db().lastReport = text
  local ok = pcall(function()
    if not reportFrame then
      local f = CreateFrame("Frame", "RealmFixReportFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
      f:SetSize(520, 300)
      f:SetPoint("CENTER")
      f:SetFrameStrata("DIALOG")
      f:SetMovable(true)
      f:EnableMouse(true)
      f:RegisterForDrag("LeftButton")
      f:SetScript("OnDragStart", f.StartMoving)
      f:SetScript("OnDragStop", f.StopMovingOrSizing)
      if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
        f:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
      end
      local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      title:SetPoint("TOPLEFT", 12, -10)
      title:SetText("!RealmFix realm report: press Ctrl+C, then post it at " .. ISSUES_URL)
      local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", 2, 2)
      local sf = CreateFrame("ScrollFrame", "RealmFixReportScroll", f, "UIPanelScrollFrameTemplate")
      sf:SetPoint("TOPLEFT", 12, -32)
      sf:SetPoint("BOTTOMRIGHT", -30, 12)
      local eb = CreateFrame("EditBox", nil, sf)
      eb:SetMultiLine(true)
      eb:SetFontObject(ChatFontNormal)
      eb:SetWidth(470)
      eb:SetAutoFocus(false)
      eb:SetScript("OnEscapePressed", function() f:Hide() end)
      sf:SetScrollChild(eb)
      f.edit = eb
      tinsert(UISpecialFrames, "RealmFixReportFrame")
      reportFrame = f
    end
    reportFrame.edit:SetText(text)
    reportFrame:Show()
    reportFrame.edit:SetFocus()
    reportFrame.edit:HighlightText()
  end)
  if not ok then
    msg("couldn't open the report window; here it is in chat (also saved in RealmFixDB.lastReport):")
    for line in text:gmatch("[^\n]+") do msg(line) end
  end
end

local function status()
  local game = origGet()
  local name, how = resolve()
  msg(string.format("game returns: \"%s\"  |  using: \"%s\" (%s)  |  server: %s",
    tostring(game), tostring(name), tostring(how), tostring(myServer())))
  if game ~= nil and game ~= "" then
    msg("The game is returning the realm name again: you can test removing !RealmFix.")
  elseif how == "unknown" then
    msg("This realm's name isn't known. Type /realmfix set <exact realm name>, then /reload.")
  end
end

SLASH_REALMFIX1 = "/realmfix"
SlashCmdList.REALMFIX = function(input)
  input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = input:match("^(%S*)%s*(.*)$")
  cmd = (cmd or ""):lower()
  if cmd == "" or cmd == "status" then
    status()
  elseif cmd == "set" then
    local sid = myServer()
    if rest == "" then
      msg("usage: /realmfix set <exact realm name, as in the realm list>")
    elseif not sid then
      msg("can't read this character's server number yet; try again in a moment.")
    else
      learn(sid, rest, "player")
      msg("saved: server " .. sid .. " = " .. rest .. ". Type /reload to apply it.")
    end
  elseif cmd == "forget" then
    local d = db()
    if rest ~= "" and d.map[rest] then
      d.map[rest], d.src[rest] = nil, nil
      msg("forgot server " .. rest .. ". Type /reload to apply.")
    else
      msg("usage: /realmfix forget <server number>  (see /realmfix report)")
    end
  elseif cmd == "report" then
    showReport()
  else
    msg("commands: /realmfix (status), /realmfix set <realm name>, /realmfix forget <server>, /realmfix report")
  end
end

-- Events: learn from DataStore once its saved data is loaded; tell the player if that
-- (or anything else) means a /reload would now fix this character's realm.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == "DataStore" then
    local added = learnFromDataStore()
    if added > 0 then
      db().learnedAt = time and time() or 0
      note("datastore+" .. added, nil, "")
    end
  elseif event == "PLAYER_LOGIN" then
    if learnFromDataStore() > 0 then note("datastore-login", nil, "") end
    local game = origGet()
    if (game == nil or game == "") and resolvedHow ~= "guid" then
      local sid = myServer()
      if sid and lookup(sid) then
        msg("learned this realm's name (" .. lookup(sid) .. "). Type /reload once to apply it.")
      elseif sid then
        msg("the game isn't giving a realm name, and server " .. sid .. " isn't known yet. " ..
            "Type /realmfix set <exact realm name>, then /reload. Please also post /realmfix report at " .. ISSUES_URL)
      end
    end
  end
end)
