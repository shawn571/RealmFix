-- !RealmFix 2.3: temporary workaround for WoW Forever client build 71037 (Nov 18 2026),
-- where GetRealmName() and GetNormalizedRealmName() return "".
--
-- When the game gives a real name, it is passed through unchanged and remembered for that
-- server number. When the game gives "", the name is looked up from the character's GUID
-- ("Player-<server>-<id>"), using, in order: names the game gave earlier, names you
-- confirmed or set, then the built-in SEED table. An unknown server number is left blank:
-- !RealmFix never guesses.
--
-- Names it finds in Altoholic's data (DataStore's saved character list) are only used after
-- you confirm them in a popup, with the detected name filled in.
-- Loads before DataStore because of the "!" in the folder name.
--
-- /realmfix          status: what the game returns now and which name is used
-- /realmfix confirm  accept the realm name detected from Altoholic for this character
-- /realmfix set <realm name>   advanced: name this character's realm yourself
-- /realmfix report   copyable report of known realms, to post as a GitHub "Realm report"

local VERSION = "2.3"
local ISSUES_URL = "github.com/shawn571/RealmFix/issues"

-- Server number -> realm name, from community realm reports. Add more via GitHub issues.
local SEED = {
  ["6796"] = "CAMWOW US2 Realm 1 PvE",
}
-- Used only if the GUID isn't available yet when the realm is first asked for.
-- "" means never guess (recommended).
local DEFAULT = ""
local LOG_MAX = 40

local MISMATCH_WARNING = "If this doesn't exactly match the realm name Altoholic shows " ..
  "(spelling, capitals and spaces), DataStore/Altoholic will file your characters under a " ..
  "new, separate realm, with duplicate characters."

local origGet, origNorm = GetRealmName, GetNormalizedRealmName
local resolved, resolvedHow          -- cached for this session once known
local logged = {}
local unknownServer                  -- server number we couldn't name this session
local knownNames = {}                -- realm names DataStore has saved (for checks)
local setPending                     -- { sid, name } waiting for /realmfix set confirm

local function msg(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99!RealmFix|r " .. text) end
end

local function db()
  -- RealmFixDB is loaded right after this file runs, before DataStore's files run.
  if type(RealmFixDB) ~= "table" then RealmFixDB = {} end
  local d = RealmFixDB
  d.map = d.map or {}          -- server -> realm name in use
  d.src = d.src or {}          -- server -> "game" | "confirmed" | "player"
  d.pending = d.pending or {}  -- server -> name detected from Altoholic, not yet confirmed
  d.log = d.log or {}
  for sid, s in pairs(d.src) do -- 2.2 used detected names without asking: ask now instead
    if s == "datastore" then
      d.pending[sid] = d.pending[sid] or d.map[sid]
      d.map[sid], d.src[sid] = nil, nil
    end
  end
  return d
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

local function trim(s)
  return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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

-- Put a name in use for a server. src: "game" | "confirmed" | "player".
local function save(sid, name, src)
  if not sid or type(name) ~= "string" or name == "" then return false end
  local d = db()
  if d.map[sid] and d.map[sid] ~= name then note("changed(" .. tostring(d.map[sid]) .. ")", sid, name) end
  d.map[sid], d.src[sid] = name, src
  d.pending[sid] = nil
  return true
end

local function lookup(sid)
  if not sid then return nil end
  return db().map[sid] or SEED[sid]
end

local function resolve()
  local r = origGet()
  local sid = myServer()
  if r ~= nil and r ~= "" then
    if db().map[sid] ~= r then save(sid, r, "game") end
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

-- Read Altoholic's data (DataStore's saved character list): characters saved before the bug
-- have their realm in the key "Account.Realm.Name", with their GUIDs in the same order.
-- Detected names are only offered for confirmation. Read-only: DataStore's data is never changed.
local function detectFromDataStore()
  local ids, guids = _G.DataStore_CharacterIDs, _G.DataStore_CharacterGUIDs
  if type(_G.DataStore_RealmNames) == "table" then
    for _, long in pairs(_G.DataStore_RealmNames) do
      if type(long) == "string" and long ~= "" then knownNames[long] = true end
    end
  end
  if type(ids) ~= "table" or type(ids.List) ~= "table" or type(guids) ~= "table" then return 0 end
  local d, found = db(), 0
  for i, key in ipairs(ids.List) do
    local realm = type(key) == "string" and key:match("^[^%.]*%.(.*)%.[^%.]*$")
    local sid = serverOf(guids[i])
    if realm and realm ~= "" then knownNames[realm] = true end
    if realm and realm ~= "" and sid and not d.map[sid] and SEED[sid] ~= realm and d.pending[sid] ~= realm then
      d.pending[sid] = realm
      found = found + 1
    end
  end
  return found
end

local function realmList()
  local seen, list = {}, {}
  local d = db()
  for sid, name in pairs(d.map) do seen[sid] = true; list[#list + 1] = { sid, name, d.src[sid] or "saved" } end
  for sid, name in pairs(d.pending) do
    if not seen[sid] then seen[sid] = true; list[#list + 1] = { sid, name, "detected in Altoholic, not confirmed" } end
  end
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
  if unknownServer and not lookup(unknownServer) and not db().pending[unknownServer] then
    lines[#lines + 1] = "  " .. unknownServer .. " = (unknown: please add its realm name and ruleset)"
  end
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

-- Accepting a name from the confirmation popup (or /realmfix confirm).
local function acceptDetected(sid, detected, typed, reload)
  typed = trim(typed)
  if typed == "" then typed = detected end
  if typed ~= detected and not knownNames[typed] then
    msg("not saved: \"" .. typed .. "\" isn't the name Altoholic has (\"" .. detected .. "\"). " ..
        MISMATCH_WARNING .. " If you're sure, use /realmfix set " .. typed)
    return false
  end
  save(sid, typed, "confirmed")
  msg("confirmed: server " .. sid .. " = " .. typed .. ".")
  if reload and ReloadUI then ReloadUI() else msg("Type /reload to apply it.") end
  return true
end

local function getEditBox(popup)
  return popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
end

local function askConfirm(sid, detected)
  local ok = pcall(function()
    StaticPopupDialogs["REALMFIX_CONFIRM"] = {
      text = "|cff33ff99!RealmFix|r\nThe game isn't giving this character's realm name.\n\n" ..
             "Detected from Altoholic: |cffffd100%s|r\n\nCheck this is your realm. " ..
             MISMATCH_WARNING .. "\n\nConfirm and reload?",
      button1 = "Confirm and reload",
      button2 = "Not now",
      hasEditBox = true,
      editBoxWidth = 280,
      OnShow = function(self)
        local eb = getEditBox(self)
        if eb then eb:SetText(self.data.name); eb:HighlightText() end
      end,
      OnAccept = function(self)
        local eb = getEditBox(self)
        acceptDetected(self.data.sid, self.data.name, eb and eb:GetText() or self.data.name, true)
      end,
      EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        acceptDetected(p.data.sid, p.data.name, self:GetText(), true)
        p:Hide()
      end,
      EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("REALMFIX_CONFIRM", detected, nil, { sid = sid, name = detected })
  end)
  if not ok then
    msg("detected this realm in Altoholic as \"" .. detected .. "\". If that's right, type /realmfix confirm.")
  end
end

local function status()
  local game = origGet()
  local name, how = resolve()
  local sid = myServer()
  msg(string.format("game returns: \"%s\"  |  using: \"%s\" (%s)  |  server: %s",
    tostring(game), tostring(name), tostring(how), tostring(sid)))
  if game ~= nil and game ~= "" then
    msg("The game is returning the realm name again: you can test removing !RealmFix.")
  elseif how == "unknown" and sid and db().pending[sid] then
    msg("Altoholic has this realm as \"" .. db().pending[sid] .. "\". Type /realmfix confirm to use it.")
  elseif how == "unknown" then
    msg("This realm's name isn't known. Please post /realmfix report at " .. ISSUES_URL ..
        ". Advanced: /realmfix set <exact realm name>.")
  end
end

SLASH_REALMFIX1 = "/realmfix"
SlashCmdList.REALMFIX = function(input)
  input = trim(input)
  local cmd, rest = input:match("^(%S*)%s*(.*)$")
  cmd, rest = (cmd or ""):lower(), trim(rest)
  local sid = myServer()
  if cmd == "" or cmd == "status" then
    status()
  elseif cmd == "confirm" then
    local p = sid and db().pending[sid]
    if p then acceptDetected(sid, p, p, false)
    else msg("nothing detected to confirm for this character. See /realmfix.") end
  elseif cmd == "set" then
    if rest:lower() == "confirm" and setPending then
      save(setPending.sid, setPending.name, "player")
      msg("saved: server " .. setPending.sid .. " = " .. setPending.name .. ". Type /reload to apply it.")
      setPending = nil
    elseif rest == "" then
      msg("advanced: /realmfix set <exact realm name, as Altoholic shows it>. Only use this if you know the exact name.")
    elseif not sid then
      msg("can't read this character's server number yet; try again in a moment.")
    elseif knownNames[rest] or db().pending[sid] == rest then
      save(sid, rest, "player")
      msg("saved: server " .. sid .. " = " .. rest .. ". Type /reload to apply it.")
    else
      setPending = { sid = sid, name = rest }
      msg("|cffff5555Warning:|r \"" .. rest .. "\" doesn't match any realm name Altoholic has saved. " ..
          MISMATCH_WARNING .. " Only continue if you know this is the exact name: type /realmfix set confirm")
    end
  elseif cmd == "forget" then
    local d = db()
    if rest ~= "" and (d.map[rest] or d.pending[rest]) then
      d.map[rest], d.src[rest], d.pending[rest] = nil, nil, nil
      msg("forgot server " .. rest .. ". Type /reload to apply.")
    else
      msg("usage: /realmfix forget <server number>  (see /realmfix report)")
    end
  elseif cmd == "report" then
    showReport()
  else
    msg("commands: /realmfix (status), /realmfix confirm, /realmfix report, " ..
        "/realmfix forget <server>, advanced: /realmfix set <realm name>")
  end
end

-- After login: if this character's realm is unknown, offer the name found in Altoholic.
local function afterLogin()
  detectFromDataStore()
  local game = origGet()
  if game ~= nil and game ~= "" then return end
  local sid = myServer()
  if not sid or lookup(sid) then
    if sid and resolvedHow ~= "guid" then msg("realm name known now (" .. lookup(sid) .. "). Type /reload once to apply it.") end
    return
  end
  local p = db().pending[sid]
  if p then
    askConfirm(sid, p)
  else
    msg("the game isn't giving a realm name, and this realm (server " .. sid .. ") isn't known yet. " ..
        "Please post /realmfix report at " .. ISSUES_URL .. " so it can be added.")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == "DataStore" then
    local n = detectFromDataStore()
    if n > 0 then note("detected+" .. n, nil, "") end
  elseif event == "PLAYER_LOGIN" then
    if C_Timer and C_Timer.After then C_Timer.After(3, afterLogin) else afterLogin() end
  end
end)
