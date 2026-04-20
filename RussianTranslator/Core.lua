-- Shared namespace — see the long note in Dictionary.lua for why we
-- cannot use the `local x, ns = ...` trick on a 2.4.3 client.
RussianTranslatorNS = RussianTranslatorNS or {}
local ns = RussianTranslatorNS
local addonName = "RussianTranslator"

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local PREFIX        = "|cff55ddff[Russian]|r "
local ORIG_COLOR    = "|cff888888"      -- grey, original cyrillic in (parens)
local ORIG_RESET    = "|r"
local UNKNOWN_COLOR = "|cffffa040"      -- orange, untranslated tokens kept as cyrillic
local UNKNOWN_RESET = "|r"
local NAME_COLOR    = "|cff88cc88"      -- soft green, identified as player nickname
local NAME_RESET    = "|r"
local LOG_CAP       = 400               -- max log rows kept per session

-- Chat events we filter. Covers every player-visible channel in WoW 2.4.3.
-- Grouped for readability; Blizzard fires these instead of a single unified
-- event because different channels carry different metadata (language,
-- channel index, raid warning flag, etc.).
local CHAT_EVENTS = {
    -- Local / proximity
    "CHAT_MSG_SAY",                 -- /say
    "CHAT_MSG_YELL",                -- /yell

    -- Group chat
    "CHAT_MSG_PARTY",               -- /p  (also used for party-leader on 2.4.3)
    "CHAT_MSG_RAID",                -- /r
    "CHAT_MSG_RAID_LEADER",         -- raid leader messages
    "CHAT_MSG_RAID_WARNING",        -- /rw

    -- Guild
    "CHAT_MSG_GUILD",               -- /g  (gchat)
    "CHAT_MSG_OFFICER",             -- /o  (officer chat)

    -- Private messages
    "CHAT_MSG_WHISPER",             -- /w incoming
    "CHAT_MSG_WHISPER_INFORM",      -- /w outgoing (your own whispers echoed)

    -- Battlegrounds (added for v0.6.1 — was the only big gap)
    "CHAT_MSG_BATTLEGROUND",        -- /bg
    "CHAT_MSG_BATTLEGROUND_LEADER", -- BG leader

    -- Custom numbered channels: General (1), Trade (2), LocalDefense (22),
    -- Global (6 on many private servers), etc.
    "CHAT_MSG_CHANNEL",

    -- Emotes
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",

    -- NPC speech
    "CHAT_MSG_MONSTER_SAY",
    "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_MONSTER_WHISPER",
    "CHAT_MSG_MONSTER_EMOTE",
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local session   -- volatile; mirrored to RT_DB on logout / reload
local db        -- alias to RT_DB after ADDON_LOADED

-- ---------------------------------------------------------------------------
-- Small utilities that must be visible everywhere below
-- ---------------------------------------------------------------------------

local function Msg(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ddff[RT]|r " .. tostring(text))
    end
end

local function HexDump(s, n)
    n = n or 24
    if type(s) ~= "string" then return "(nil)" end
    local parts = {}
    local len = math.min(#s, n)
    for i = 1, len do
        parts[i] = string.format("%02X", s:byte(i))
    end
    if #s > n then parts[#parts + 1] = "..." end
    return table.concat(parts, " ")
end

-- Append a log row to the current session. Capped at LOG_CAP rows.
-- Safe to call before session exists (silently drops).
local function Log(tag, fields)
    if not session then return end
    local row = fields or {}
    row.t   = date("%H:%M:%S")
    row.tag = tag
    local log = session.log
    log[#log + 1] = row
    if #log > LOG_CAP then
        -- drop oldest half in one shot so we don't pay table.remove each call
        local keep = {}
        local from = math.floor(LOG_CAP / 2)
        for i = from, #log do keep[#keep + 1] = log[i] end
        session.log = keep
    end
end

-- ---------------------------------------------------------------------------
-- UTF-8 / Cyrillic helpers
-- ---------------------------------------------------------------------------

local function HasUtf8Cyrillic(s)
    return s:find("[\208\209][\128-\191]") ~= nil
end

local function ToLower(s)
    s = s:lower()
    s = s:gsub("([\208\209][\128-\191])", function(ch)
        return ns.CYR_LOWER[ch] or ch
    end)
    return s
end

local function Transliterate(s)
    return (s:gsub("([\208\209][\128-\191])", function(ch)
        return ns.TRANSLIT[ch] or ch
    end))
end

-- ---------------------------------------------------------------------------
-- Unknown-token log (dictionary growth)
-- ---------------------------------------------------------------------------

local function LogUnknown(token, sampleLine)
    if not session or not token or token == "" then return end
    local u = session.unknowns
    local entry = u[token]
    if entry then
        entry.count = entry.count + 1
    else
        u[token] = { count = 1, sample = sampleLine }
        session.unknownDistinct = session.unknownDistinct + 1
    end
end

-- ---------------------------------------------------------------------------
-- Addressee detection
-- ---------------------------------------------------------------------------
-- Figures out whether the first Cyrillic word of a message is a nickname
-- being addressed. Five cascading rules (first match wins):
--
--   1. It's a sender we've seen speaking this session (knownNames roster).
--   2. The first word is ITSELF an address-context token (question word
--      like "кто"/"где"/"как" or 2nd-person pronoun) → NOT a nickname.
--      This stops false positives like "Кто ты" marking "кто" as a nick.
--   3. The very next Cyrillic token is an address-context word (`ты`,
--      `где`, `дай`, `скажи`, etc.). "Мукк ты где?" or "Мукк дай инв".
--   4. Vocative punctuation `,` `;` `:` `!` right after first word, AND
--      first word is NOT a dictionary word (avoids listings like
--      "Кара, БТ, ШХ" being mis-tagged).
--   5. First word is NOT in the dictionary and there IS more content.
--      Unknown-at-start is usually a proper noun / nick.
--
-- If any rule fires, the token is also auto-added to knownNames so future
-- messages in the same session recognise it without re-deriving.

local ADDRESS_CONTEXT = {
    -- 2nd-person pronouns (someone is talking TO you)
    ["ты"]=true, ["вы"]=true,
    ["тебя"]=true, ["тебе"]=true, ["тобой"]=true, ["тобою"]=true,
    ["вас"]=true, ["вам"]=true, ["вами"]=true,
    -- question words used in direct address ("Nick, where are you?")
    ["где"]=true, ["куда"]=true, ["откуда"]=true,
    ["когда"]=true, ["почему"]=true, ["зачем"]=true,
    -- common imperatives directed at a single addressee
    ["дай"]=true, ["дайте"]=true, ["скажи"]=true, ["скажите"]=true,
    ["помоги"]=true, ["помогите"]=true, ["кинь"]=true, ["киньте"]=true,
    ["приди"]=true, ["придите"]=true, ["иди"]=true, ["идите"]=true,
    ["слушай"]=true, ["слушайте"]=true, ["пиши"]=true, ["пишите"]=true,
    ["жди"]=true, ["ждите"]=true, ["бери"]=true, ["возьми"]=true,
    ["возьмите"]=true, ["отвечай"]=true, ["ответь"]=true,
    ["напиши"]=true, ["напишите"]=true, ["забери"]=true, ["принеси"]=true,
    ["сюда"]=true, ["подойди"]=true,
    ["стоп"]=true, ["молчи"]=true, ["заткнись"]=true,
    ["смотри"]=true, ["смотрите"]=true, ["глянь"]=true, ["глянь-ка"]=true,
    ["вернись"]=true, ["выходи"]=true, ["заходи"]=true,
    -- question words that work either-or; user must type capital for start
    ["что"]=true, ["чё"]=true, ["чо"]=true, ["че"]=true,
    ["кто"]=true, ["какой"]=true, ["какая"]=true, ["какие"]=true,
    ["сколько"]=true, ["кому"]=true, ["кого"]=true, ["кем"]=true,
}

local function DetectAddressee(lowered)
    if not session or not session.knownNames then return nil end

    local s, e = lowered:find("[%w\128-\255]+")
    if not s then return nil end
    local firstWord = lowered:sub(s, e)
    if not HasUtf8Cyrillic(firstWord) then return nil end

    -- Rule 1: seen as sender this session → nick.
    if session.knownNames[firstWord] then return firstWord end
    -- Rule 2: first word is itself an address-context token → NOT nick.
    if ADDRESS_CONTEXT[firstWord] then return nil end

    -- Peek at what follows.
    local tail = lowered:sub(e + 1)
    local nextPunct = tail:match("^([,;:!])")
    local nextWord  = tail:match("^[%p%s]+([%w\128-\255]+)")
                    or tail:match("^%s*([%w\128-\255]+)")
    local isCyrNext = nextWord and HasUtf8Cyrillic(nextWord)

    -- Rule 3: next Cyrillic token is an address-context word → nick.
    if isCyrNext and ADDRESS_CONTEXT[nextWord] then return firstWord end
    -- Rule 4: vocative punct after, AND first word not in dictionary → nick.
    if nextPunct and not ns.WORDS[firstWord] then return firstWord end
    -- Rule 5: unknown word at start, message continues → nick.
    if not ns.WORDS[firstWord] and tail:match("%S") then return firstWord end
    return nil
end

-- ---------------------------------------------------------------------------
-- Translation pipeline
-- ---------------------------------------------------------------------------

local function ApplyPhrases(lowered)
    local subs = {}
    local id = 0
    for _, key in ipairs(ns.PHRASE_ORDER) do
        local idx = lowered:find(key, 1, true)
        while idx do
            id = id + 1
            local ph = "\1" .. id .. "\1"
            subs[ph] = ns.PHRASES[key]
            lowered = lowered:sub(1, idx - 1) .. ph .. lowered:sub(idx + #key)
            idx = lowered:find(key, idx + #ph, true)
        end
    end
    return lowered, subs
end

local function RestorePhrases(s, subs)
    if not subs or not next(subs) then return s end
    return (s:gsub("\1(%d+)\1", function(n)
        return subs["\1" .. n .. "\1"] or ""
    end))
end

-- isFirstCyrillic: true if this is the FIRST Cyrillic token of the message.
-- Used for player-name disambiguation: Russian chat often starts with a name
-- when addressing someone ("Кара, ты где?"). If we've seen that exact string
-- as a sender in this session it's almost certainly a nickname there, not a
-- homonym dictionary word. Inside the message the same token is probably a
-- real word and still gets translated normally.
local function TranslateToken(token, sampleLine, isFirstCyrillic)
    if token:find("^\1") then return token, true end
    if not HasUtf8Cyrillic(token) then return token, true end

    -- Player-name override, only at message start.
    if isFirstCyrillic and session and session.knownNames
       and session.knownNames[token] then
        return NAME_COLOR .. token .. NAME_RESET, true
    end

    local hit = ns.WORDS[token]
    if hit then return hit, true end
    LogUnknown(token, sampleLine)
    -- Keep the original Cyrillic so the user can still read the word, but
    -- wrap it in an orange colour code so it's visually obvious that this
    -- token was not in the dictionary. We still log it for dictionary growth.
    return UNKNOWN_COLOR .. token .. UNKNOWN_RESET, false
end

-- Returns (rewritten, normalizedUtf8, encoding) or nil if no Cyrillic.
local function Translate(msg)
    if not msg or msg == "" then return nil end
    local normalized, enc = ns.NormalizeCyrillic(msg)
    if enc == "ascii" then return nil end

    local lowered = ToLower(normalized)

    -- ------------------------------------------------------------------
    -- Numeric shorthand preprocessors
    -- ------------------------------------------------------------------
    -- Russian chat shortens common suffixes onto numbers without spaces:
    --   "5к"   = 5 000 gold          -> "5K"
    --   "20г"  = 20 gold             -> "20g"
    --   "1дд"  = 1 dps               -> "1 dps"
    --   "2хил" = 2 healers           -> "2 healers"
    --   "3танк"= 3 tanks             -> "3 tanks"
    --
    -- WORD-BOUNDARY RULE: we must NOT swallow the first Cyrillic letter of
    -- a longer word. In "28 крита" the raw regex `(%d+)%s*к` would match
    -- "28 к" + eat the "к" of "крита", turning it into "28Kрита" — bug
    -- reported from real chat. Fix: require that the character following
    -- the suffix is either end-of-string, whitespace, ASCII punctuation,
    -- OR anything that is NOT a Cyrillic letter lead byte (\208/\209) and
    -- NOT an alphanumeric. We apply it with two gsub passes per suffix:
    -- (a) in-string where the follow byte is anchor-safe, (b) end-of-line.
    --
    -- Cyrillic bytes used below:
    --   к = \208\186      г = \208\179
    --   дд lower = \208\180\208\180
    --   хил lower = \209\133\208\184\208\187
    --   танк lower = \209\130\208\176\208\189\208\186
    --
    -- "<num>к" -> "<num>K"  (thousand)
    lowered = lowered:gsub("(%d[%d%.,]*)%s*\208\186([^%w\208\209])", "%1K%2")
    lowered = lowered:gsub("(%d[%d%.,]*)%s*\208\186$",               "%1K")
    -- "<num>г" -> "<num>g"  (gold) - same boundary rule
    lowered = lowered:gsub("(%d[%d%.,]*)%s*\208\179([^%w\208\209])", "%1g%2")
    lowered = lowered:gsub("(%d[%d%.,]*)%s*\208\179$",               "%1g")
    -- "<num>дд" -> "<num> dps"
    lowered = lowered:gsub("(%d)\208\180\208\180",                   "%1 dps")
    -- "<num>хил" / "<num>хилл" -> "<num> healer"
    lowered = lowered:gsub("(%d)\209\133\208\184\208\187\208\187?",  "%1 healer")
    -- "<num>танк" -> "<num> tank"
    lowered = lowered:gsub("(%d)\209\130\208\176\208\189\208\186",   "%1 tank")
    -- "<num>рейт" -> "<num> rating"  (e.g. "1712рейт")
    lowered = lowered:gsub("(%d+)\209\128\208\181\208\185\209\130",  "%1 rating")
    -- "<num>мин" -> "<num> min"
    lowered = lowered:gsub("(%d+)\208\188\208\184\208\189",          "%1 min")
    -- "<num>сек" -> "<num> sec"
    lowered = lowered:gsub("(%d+)\209\129\208\181\208\186",          "%1 sec")
    -- "<num>лвл" -> "<num> lvl"
    lowered = lowered:gsub("(%d+)\208\187\208\178\208\187",          "%1 lvl")

    -- ------------------------------------------------------------------
    -- Slavic smiley convention
    -- ------------------------------------------------------------------
    -- Russian (and other Slavic) chat drops the colon in :) and writes
    -- just ) or )))) to express happiness. Sad faces are ((. An English
    -- reader sees a stray unmatched paren and the message looks broken.
    --
    -- Heuristic: count paren pairs. If close > open, the excess ")"s are
    -- smileys; if open > close, the excess "("s are sad faces. When
    -- balanced (e.g. normal parenthetical like "кто на кару (хс)?"), we
    -- leave everything alone.
    --
    -- We avoid double-prefixing cases like ":)" -> "::)" by requiring
    -- the char before a multi-paren run not to be ":" (so the user's
    -- existing colon is respected).
    local opens, closes = 0, 0
    for _ in lowered:gmatch("%(") do opens  = opens  + 1 end
    for _ in lowered:gmatch("%)") do closes = closes + 1 end

    if closes > opens then
        -- )) / ))) / )))) runs (skip if already prefixed with ":")
        lowered = lowered:gsub("([^:])(%)%)+)",                "%1:%2")
        lowered = lowered:gsub("^(%)%)+)",                     ":%1")
        -- trailing single ) after letter/cyrillic, with or without space
        lowered = lowered:gsub("([%w\128-\255])%)%s*$",        "%1 :)")
        lowered = lowered:gsub("([%w\128-\255])%s+%)%s*$",     "%1 :)")
    end
    if opens > closes then
        lowered = lowered:gsub("([^:])(%(%(+)",                "%1:%2")
        lowered = lowered:gsub("^(%(%(+)",                     ":%1")
        lowered = lowered:gsub("([%w\128-\255])%(%s*$",        "%1 :(")
        lowered = lowered:gsub("([%w\128-\255])%s+%(%s*$",     "%1 :(")
    end

    -- Detect an addressee BEFORE phrases get substituted. The 5 rules are
    -- in DetectAddressee(); if any fires we auto-add the word to the
    -- session roster so follow-up messages are recognised without
    -- re-running the heuristic.
    local addressee = DetectAddressee(lowered)
    if addressee and session and session.knownNames then
        session.knownNames[addressee] = (session.knownNames[addressee] or 0) + 1
    end

    local withPh, subs = ApplyPhrases(lowered)
    -- Track whether we've already seen a Cyrillic token — only the first
    -- one is eligible for the "is this a player name being addressed?"
    -- check. (Mid-message occurrences default to normal translation.)
    local seenFirstCyr = false
    local out = withPh:gsub("[%w\128-\255\1]+", function(tok)
        local isFirst = false
        if (not seenFirstCyr) and HasUtf8Cyrillic(tok) and not tok:find("^\1") then
            isFirst = true
            seenFirstCyr = true
        end
        return (TranslateToken(tok, normalized, isFirst))
    end)
    out = RestorePhrases(out, subs)

    session.messagesTranslated = session.messagesTranslated + 1
    return out, normalized, enc
end

-- ---------------------------------------------------------------------------
-- Chat filter
-- ---------------------------------------------------------------------------
-- IMPORTANT — filter signature on WoW 2.4.3 is  function(msg, ...)  where
-- `...` is the rest of the chat event args (sender, language, channelName,
-- target, flags, zoneChannelID, channelIndex, channelBaseName).
--
-- There is NO `self` and NO `event` passed. That was added in later patches
-- (WotLK / Cataclysm). Confirmed by reading Timed/Modules/Chat.lua which is
-- a working TBC addon that does exactly this:
--     function Timed.ChatFilter(msg)  return false, msg  end
--
-- Because the filter receives no event name, we close over it at registration
-- time: we build a per-event closure in RegisterFilters() that calls a shared
-- FilterImpl with the event name threaded in.

local function FilterImpl(eventName, msg, ...)
    if not db or db.enabled == false then return false end
    if not session then return false end
    if type(msg) ~= "string" or msg == "" then return false end

    session.messagesSeen = session.messagesSeen + 1
    session.filterCalls  = session.filterCalls + 1

    -- Track sender as a known nickname. The first varg after msg in every
    -- chat event is the sender name (player nick). Store in lowercase,
    -- Cyrillic nicks only — ASCII nicks never collide with our dictionary.
    local sender = (select(1, ...))
    if type(sender) == "string" and sender ~= "" then
        -- Strip realm suffix ("Name-Realm" is rare on 2.4.3 but harmless).
        local bare = sender:match("^([^%-]+)") or sender
        local low = bare:lower()
        if ns.DetectCyrillicEncoding(low) ~= "ascii" then
            -- Store in the same CP1251->UTF-8 normalised form we match tokens in.
            low = ns.NormalizeCyrillic(low)
            session.knownNames[low] = (session.knownNames[low] or 0) + 1
        end
    end

    local enc = ns.DetectCyrillicEncoding(msg)
    local bytes = HexDump(msg, 20)

    if not session.encodingsSeen[enc] then
        session.encodingsSeen[enc] = true
        Log("encoding-first-seen", {
            event = eventName, enc = enc, bytes = bytes, msg = msg,
        })
    end

    if db.debug then
        Msg(string.format("|cffffff00DBG|r %s enc=%s bytes=%s | %s",
            tostring(eventName), tostring(enc), tostring(bytes), tostring(msg)))
    end

    local translated, normalized = Translate(msg)

    if (session.filterCalls % 5) == 1 or translated then
        Log("chat", {
            event = eventName, enc = enc, bytes = bytes,
            raw = msg, translated = translated,
        })
    end

    if not translated then
        return false
    end

    local out = PREFIX .. translated
    if db.showOrig then
        out = out .. "  " .. ORIG_COLOR .. "(" .. (normalized or msg) .. ")" .. ORIG_RESET
    end
    return false, out, ...
end

-- Wrap the filter in a pcall so a bug in our pipeline never breaks the
-- entire chat frame for the user. On error we log and pass through.
local function SafeFilterImpl(eventName, msg, ...)
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(FilterImpl, eventName, msg, ...)
    if ok then
        return a, b, c, d, e, f, g, h, i, j
    end
    Log("filter-error", { event = eventName, err = tostring(a), msg = msg })
    if db and db.debug then
        Msg("|cffff5555DBG err|r " .. tostring(eventName) .. ": " .. tostring(a))
    end
    return false  -- pass message through unchanged
end

local function BuildFilter(eventName)
    return function(msg, ...)
        return SafeFilterImpl(eventName, msg, ...)
    end
end

-- ---------------------------------------------------------------------------
-- Session / SavedVariables lifecycle
-- ---------------------------------------------------------------------------

local function InitSession()
    local stamp = date("%Y-%m-%d_%H-%M-%S")
    session = {
        started             = stamp,
        ended               = nil,
        messagesSeen        = 0,
        messagesTranslated  = 0,
        filterCalls         = 0,
        unknownDistinct     = 0,
        unknowns            = {},
        encodingsSeen       = {},
        log                 = {},
        -- RAM-only roster of Cyrillic nicknames that spoke in this session.
        -- Keyed by lowercase nick (Cyrillic form). Used to skip translating
        -- homonyms at message-start — see TranslateToken. Intentionally NOT
        -- saved to SavedVariables: a nickname that had a Russian alt-meaning
        -- should be re-proven every session, not inherited forever.
        knownNames          = {},
    }
    table.insert(db.sessions, session)
    while #db.sessions > (db.maxSessions or 50) do
        table.remove(db.sessions, 1)
    end
    Log("session-start", { addon = addonName, version = "0.2.0" })
end

local function InitDB()
    RT_DB = RT_DB or {}
    db = RT_DB
    if db.enabled      == nil then db.enabled      = true  end
    if db.showOrig     == nil then db.showOrig     = true  end
    if db.debug        == nil then db.debug        = false end
    if db.autoChatLog  == nil then db.autoChatLog  = true  end  -- /chatlog on login
    if db.maxSessions  == nil then db.maxSessions  = 50    end
    db.sessions = db.sessions or {}
end

-- Turn on /chatlog so WoW dumps every chat line to
-- <WoW>\Logs\WoWChatLog.txt. 2.4.3 doesn't remember the flag between
-- sessions, so without this the user has to retype /chatlog every login
-- (and loses the current session's buffer if they forget).
-- LoggingChat() with no args returns the current state on 2.4.3.
local function EnsureChatLog()
    if type(LoggingChat) ~= "function" then
        Log("chatlog", { ok = false, reason = "LoggingChat API missing" })
        return false
    end
    local already = LoggingChat()
    if not already then
        LoggingChat(true)
    end
    Log("chatlog", { ok = true, was_on = already and true or false })
    return true
end

-- ---------------------------------------------------------------------------
-- Interface Options panel
-- ---------------------------------------------------------------------------
-- Blizzard's Interface Options framework arrived in 2.4 so we can register
-- a settings panel that shows up under:
--   Game Menu (Esc) -> Interface -> AddOns -> Russian Translator
-- All toggles flip a db.* field directly, so every click persists to
-- SavedVariables on the next /reload or logout — same place the slash
-- commands write.

local optionsPanel  -- cached so we can re-open via /rt options

local function InitUI()
    if optionsPanel then return optionsPanel end

    local panel = CreateFrame("Frame")
    panel.name = "Russian Translator"
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Russian Translator")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetText("Russian -> English chat translator. Settings persist across sessions.")

    -- Helper: make a checkbox wired to a db field. Getter/setter keeps the
    -- UI and the SavedVariables in sync without needing any refresh logic.
    local function makeCheckbox(name, label, anchorFrame, yOff, getter, setter)
        local cb = CreateFrame("CheckButton", "RT_Opt_"..name, panel,
                               "InterfaceOptionsCheckButtonTemplate")
        if anchorFrame == panel then
            cb:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, yOff)
        else
            cb:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOff)
        end
        local text = _G[cb:GetName() .. "Text"]
        if text then text:SetText(label) end
        cb:SetScript("OnShow", function(self)
            self:SetChecked(getter() and 1 or nil)
        end)
        cb:SetScript("OnClick", function(self)
            setter(self:GetChecked() and true or false)
        end)
        return cb
    end

    local cbEnabled = makeCheckbox("Enabled",
        "Enable translation",
        panel, -24,
        function() return db and db.enabled end,
        function(v) db.enabled = v; Msg("translation = "..(v and "ON" or "OFF")) end)

    local cbOrig = makeCheckbox("ShowOrig",
        "Show original Cyrillic in parentheses after translation",
        cbEnabled, -4,
        function() return db and db.showOrig end,
        function(v) db.showOrig = v; Msg("show original = "..tostring(v)) end)

    local cbChatLog = makeCheckbox("ChatLog",
        "Auto-enable /chatlog on login (writes WoW\\Logs\\WoWChatLog.txt)",
        cbOrig, -4,
        function() return db and db.autoChatLog end,
        function(v)
            db.autoChatLog = v
            if v and type(LoggingChat) == "function" and not LoggingChat() then
                LoggingChat(true)
            elseif (not v) and type(LoggingChat) == "function" and LoggingChat() then
                LoggingChat(false)
            end
            Msg("auto /chatlog = "..tostring(v))
        end)

    local cbDebug = makeCheckbox("Debug",
        "Debug mode (print hex dump of every message to chat)",
        cbChatLog, -4,
        function() return db and db.debug end,
        function(v) db.debug = v; Msg("debug = "..tostring(v)) end)

    -- Footnote
    local footer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    footer:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -16)
    footer:SetText("Tip: type /rt help in chat for all commands, /rt names for the session nickname roster.")

    if type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
    end
    optionsPanel = panel
    return panel
end

local function RegisterFilters()
    local ok = 0
    local fail = 0
    if type(ChatFrame_AddMessageEventFilter) ~= "function" then
        Log("filters-registered", { ok = 0, fail = #CHAT_EVENTS, has_api = false })
        return 0, #CHAT_EVENTS
    end
    for _, ev in ipairs(CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(ev, BuildFilter(ev))
        ok = ok + 1
    end
    Log("filters-registered", { ok = ok, fail = fail, has_api = true })
    return ok, fail
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

local function CmdDump()
    if not session then Msg("no session"); return end
    Msg(("session %s  seen=%d  translated=%d  filterCalls=%d  unknown-distinct=%d"):format(
        session.started, session.messagesSeen,
        session.messagesTranslated, session.filterCalls, session.unknownDistinct))

    local encs = {}
    for e in pairs(session.encodingsSeen) do encs[#encs + 1] = e end
    Msg("encodings seen: " .. (table.concat(encs, ", ") == "" and "(none)" or table.concat(encs, ", ")))

    local list = {}
    for tok, e in pairs(session.unknowns) do
        list[#list + 1] = { tok = tok, count = e.count }
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    local shown = 0
    for i = 1, #list do
        Msg(("  %d x  %s"):format(list[i].count, list[i].tok))
        shown = shown + 1
        if shown >= 10 then break end
    end
    if shown == 0 then Msg("  (no unknown tokens yet)") end
end

local function CmdLog(nStr)
    if not session then Msg("no session"); return end
    local n = tonumber(nStr) or 20
    local log = session.log
    local from = math.max(1, #log - n + 1)
    Msg(("activity log (last %d of %d rows):"):format(math.min(n, #log), #log))
    for i = from, #log do
        local r = log[i]
        local s = r.t .. " " .. r.tag
        if r.event then s = s .. " " .. r.event end
        if r.enc then   s = s .. " enc=" .. r.enc end
        if r.ok ~= nil or r.fail ~= nil then
            s = s .. " ok=" .. tostring(r.ok) .. " fail=" .. tostring(r.fail)
        end
        if r.has_api ~= nil then s = s .. " api=" .. tostring(r.has_api) end
        if r.raw then s = s .. " | " .. tostring(r.raw) end
        if r.translated then s = s .. " -> " .. tostring(r.translated) end
        Msg("  " .. s)
    end
end

local function CmdTest(rest)
    if rest == nil or rest == "" then
        Msg("usage: /rt test <cyrillic text>")
        return
    end
    Msg("input:  [" .. rest .. "]")
    Msg("bytes:  " .. HexDump(rest, 40))
    local enc = ns.DetectCyrillicEncoding(rest)
    Msg("detected encoding: " .. enc)
    local normalized = ns.NormalizeCyrillic(rest)
    if normalized ~= rest then
        Msg("normalized bytes: " .. HexDump(normalized, 40))
    end
    local tr, norm, e = Translate(rest)
    if tr then
        Msg("translated: " .. tr)
    else
        Msg("translated: (no cyrillic detected -> pipeline skipped)")
    end
end

local function CmdHelp()
    Msg("commands:")
    Msg("  /rt on | off         - enable/disable translation")
    Msg("  /rt orig             - toggle showing original next to translation")
    Msg("  /rt debug            - toggle per-message debug prints in chat")
    Msg("  /rt chatlog on|off   - toggle auto /chatlog at login (default on)")
    Msg("  /rt status           - show current settings + counters")
    Msg("  /rt dump             - session stats + top unknowns")
    Msg("  /rt log [N]          - print last N activity-log rows (default 20)")
    Msg("  /rt test <text>      - run a test string through the pipeline")
    Msg("  /rt reregister       - re-register chat filters (diagnostic)")
    Msg("  /rt names            - list Cyrillic nicks seen this session")
    Msg("  /rt options          - open the options panel (Esc > Interface > AddOns)")
    Msg("  /rt clear            - wipe all stored sessions")
end

SLASH_RT1 = "/rt"
SlashCmdList["RT"] = function(input)
    input = input or ""
    local cmd, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "help" then
        CmdHelp()
    elseif cmd == "on" then
        db.enabled = true;  Msg("ON")
    elseif cmd == "off" then
        db.enabled = false; Msg("OFF")
    elseif cmd == "orig" then
        db.showOrig = not db.showOrig
        Msg("showOrig = " .. tostring(db.showOrig))
    elseif cmd == "debug" then
        db.debug = not db.debug
        Msg("debug = " .. tostring(db.debug))
    elseif cmd == "chatlog" then
        local arg = (rest or ""):lower()
        if arg == "on" or arg == "" then
            db.autoChatLog = true
            EnsureChatLog()
            Msg("auto /chatlog = on (persists across sessions via SavedVariables)")
        elseif arg == "off" then
            db.autoChatLog = false
            if type(LoggingChat) == "function" then LoggingChat(false) end
            Msg("auto /chatlog = off")
        else
            local now = (type(LoggingChat) == "function") and LoggingChat() and "logging" or "not logging"
            Msg(("auto /chatlog setting = %s; WoW currently %s"):format(
                tostring(db.autoChatLog), now))
        end
    elseif cmd == "dump" then
        CmdDump()
    elseif cmd == "log" then
        CmdLog(rest)
    elseif cmd == "test" then
        CmdTest(rest)
    elseif cmd == "reregister" then
        local ok, fail = RegisterFilters()
        Msg(("re-registered filters ok=%d fail=%d"):format(ok, fail))
    elseif cmd == "options" or cmd == "config" then
        local p = optionsPanel or InitUI()
        -- Blizzard's 2.4 call: InterfaceOptionsFrame_OpenToCategory selects by
        -- panel OR by name. Called twice to work around a well-known single-
        -- click bug where the first call opens the root, the second selects.
        if type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            InterfaceOptionsFrame_OpenToCategory(p)
            InterfaceOptionsFrame_OpenToCategory(p)
        elseif InterfaceOptionsFrame then
            InterfaceOptionsFrame:Show()
        else
            Msg("Interface Options not available on this client.")
        end
    elseif cmd == "names" then
        if not session or not session.knownNames then
            Msg("no session / no names tracked")
        else
            local list = {}
            for name, cnt in pairs(session.knownNames) do
                list[#list + 1] = { name = name, cnt = cnt }
            end
            table.sort(list, function(a, b) return a.cnt > b.cnt end)
            Msg(("%d cyrillic nicks tracked this session:"):format(#list))
            local shown = 0
            for i = 1, #list do
                Msg(("  %d x  %s"):format(list[i].cnt, list[i].name))
                shown = shown + 1
                if shown >= 30 then
                    Msg(("  ... (%d more)"):format(#list - shown))
                    break
                end
            end
        end
    elseif cmd == "clear" then
        db.sessions = {}; InitSession()
        Msg("all sessions cleared")
    elseif cmd == "status" then
        local chatlog_now = "n/a"
        if type(LoggingChat) == "function" then
            chatlog_now = LoggingChat() and "on" or "off"
        end
        local nameCount = 0
        if session and session.knownNames then
            for _ in pairs(session.knownNames) do nameCount = nameCount + 1 end
        end
        Msg(("enabled=%s  showOrig=%s  debug=%s  autoChatLog=%s  chatlog-now=%s  sessions=%d  nicks=%d"):format(
            tostring(db.enabled), tostring(db.showOrig),
            tostring(db.debug), tostring(db.autoChatLog),
            chatlog_now, #db.sessions, nameCount))
        if session then
            Msg(("current: seen=%d translated=%d filterCalls=%d"):format(
                session.messagesSeen, session.messagesTranslated, session.filterCalls))
        end
    else
        Msg("unknown command: " .. cmd)
        CmdHelp()
    end
end

-- ---------------------------------------------------------------------------
-- Event wiring
-- ---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        InitUI()
        -- We can't Log() yet (session not created), so print straight to chat.
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        InitSession()
        local ok, fail = RegisterFilters()
        local chatlog = "off"
        if db.autoChatLog then
            if EnsureChatLog() then chatlog = "on" end
        end
        Msg("|cffffcc00made by Grzegorz Korycki (Poczwarka)|r")
        Msg(("loaded (session %s). filters=%d chatlog=%s. /rt help"):format(
            session.started, ok, chatlog))
    elseif event == "PLAYER_LOGOUT" then
        if session then
            session.ended = date("%Y-%m-%d_%H-%M-%S")
            Log("session-end", {})
        end
    end
end)
