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
-- Nickname handling
-- ---------------------------------------------------------------------------
-- The ONLY source of truth for "this token is a player nickname" is the
-- sender field from the chat event itself (FilterImpl, below). Heuristic
-- promotion from mid-message context was removed in v0.9.4 because it
-- produced false positives on short Russian function words like `ну`, `за`,
-- `об`, `ку`, `ах` whenever they appeared before a pronoun or punctuation.
--
-- Real WoW character names are min 3 Cyrillic characters; short tokens that
-- look like nicks aren't nicks, they're prepositions/particles.

-- ---------------------------------------------------------------------------
-- Translation pipeline
-- ---------------------------------------------------------------------------

-- Item/spell/quest/etc chat-link extraction. WoW links look like:
--   |cffXXXXXXXX|Hitem:21853:0:0:0:0:0:0:0|h[Сапоги из ткани Пустоты]|h|r
-- ToLower would turn the start sigil |H into |h, breaking link parsing
-- (WoW would treat it as an unmatched end-of-link). We extract every link
-- into a pair of byte-0x02 placeholders that survive ToLower (ascii-lower
-- only changes letters, and our placeholder body is already lowercase),
-- ApplyPhrases, and the token gsub (because \2 isn't in the token class).
-- The inner [name] text is left exposed BETWEEN the placeholders so it
-- still goes through normal translation.
local function ExtractLinks(s)
    local subs = {}
    local n = 0
    s = s:gsub("(|c%x+|H[^|]+|h)%[(.-)%](|h|r)", function(start_, name, fin)
        n = n + 1
        local sk = "\2ls" .. n .. "\2"
        local ek = "\2le" .. n .. "\2"
        subs[sk] = start_ .. "["
        subs[ek] = "]" .. fin
        return sk .. name .. ek
    end)
    return s, subs
end

local function RestoreLinks(s, subs)
    if not subs or not next(subs) then return s end
    for key, val in pairs(subs) do
        s = s:gsub(key, function() return val end, 1)
    end
    return s
end

-- Returns true if byte at `pos` is part of a "word":
-- ASCII A-Z/a-z, digits, or any UTF-8 multibyte (covers Cyrillic letters).
-- Used to enforce word boundaries on phrase substitution so phrases like "и то"
-- don't chew letters out of words like "или+только".
local function isWordByte(s, pos)
    if pos < 1 or pos > #s then return false end
    local b = s:byte(pos)
    if b >= 65 and b <= 90 then return true end
    if b >= 97 and b <= 122 then return true end
    if b >= 48 and b <= 57 then return true end
    if b >= 128 then return true end
    return false
end

local function ApplyPhrases(lowered)
    local subs = {}
    local id = 0
    -- Always iterate core phrases first (longest-first order).
    for _, key in ipairs(ns.PHRASE_ORDER) do
        local idx = lowered:find(key, 1, true)
        while idx do
            local endPos = idx + #key
            local beforeOk = (idx == 1) or not isWordByte(lowered, idx - 1)
            local afterOk = (endPos > #lowered) or not isWordByte(lowered, endPos)
            if beforeOk and afterOk then
                id = id + 1
                local ph = "\1" .. id .. "\1"
                subs[ph] = ns.PHRASES[key]
                lowered = lowered:sub(1, idx - 1) .. ph .. lowered:sub(endPos)
                idx = lowered:find(key, idx + #ph, true)
            else
                idx = lowered:find(key, idx + 1, true)
            end
        end
    end
    -- Then iterate extra (Kaikki) phrases if loaded and lite mode is off.
    if ns.PHRASE_ORDER_EXTRA and not (db and db.liteMode) then
        for _, key in ipairs(ns.PHRASE_ORDER_EXTRA) do
            local idx = lowered:find(key, 1, true)
            while idx do
                local endPos = idx + #key
                local beforeOk = (idx == 1) or not isWordByte(lowered, idx - 1)
                local afterOk = (endPos > #lowered) or not isWordByte(lowered, endPos)
                if beforeOk and afterOk then
                    id = id + 1
                    local ph = "\1" .. id .. "\1"
                    subs[ph] = ns.PHRASES_EXTRA[key]
                    lowered = lowered:sub(1, idx - 1) .. ph .. lowered:sub(endPos)
                    idx = lowered:find(key, idx + #ph, true)
                else
                    idx = lowered:find(key, idx + 1, true)
                end
            end
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

-- ---------------------------------------------------------------------------
-- Lemmatization fallback
-- ---------------------------------------------------------------------------
-- Russian inflection produces 6-18 forms per noun (6 cases × 2 numbers)
-- and 30+ forms per adjective. Storing every form in the dictionary bloats
-- it by ~10×. Instead, after a direct dictionary miss, try stripping common
-- case endings and reconstructing the nominative-singular base form. The
-- first rule whose candidate hits ns.WORDS wins.
--
-- Rules are ordered by: (a) longer suffixes before shorter, (b) more
-- specific before more generic. This gives the correct resolution for
-- the common ambiguities (e.g. "дорогу" tries добавить "-а" → "дорога"
-- before trying bare strip → "дорог").
--
-- Suffixes and addbacks are UTF-8 literal strings (2 bytes per Cyrillic
-- letter), stored in the Lua source file directly.
local LEMMA_RULES = {
    -- 3-letter suffixes (plural inst. / adjective forms)
    {"ами","а"}, {"ами",""},
    {"ями","я"}, {"ями",""},
    {"ыми","ый"}, {"ыми","ой"}, {"ыми","ые"},
    {"ими","ий"}, {"ими","ие"},
    {"ого","ый"}, {"ого","ой"}, {"его","ий"}, {"его","ее"},
    {"ому","ый"}, {"ому","ой"}, {"ему","ий"},
    -- Past-tense reflexive
    {"лись","ться"}, {"лась","ться"}, {"лось","ться"},
    -- 3rd person plural reflexive (try -ться AND -ть, both happen)
    {"ются","ться"}, {"ются","ть"},
    {"утся","ться"}, {"утся","ть"},
    {"атся","аться"}, {"атся","ать"},
    {"ятся","яться"}, {"ятся","ять"}, {"ятся","ить"},
    -- Reflexive imperative (-йся → -ться)
    {"йся","ться"}, {"йтесь","ться"},
    -- Imperative (-ай/-яй/-ой/-уй → -ать/-ять/-оть/-овать)
    {"айте","ать"}, {"яйте","ять"},
    {"ай","ать"}, {"яй","ять"},
    {"уйте","овать"}, {"уй","овать"},
    {"ите","ить"}, {"ите","еть"},  -- plural imp or 2pl present
    -- Irregular stems (помочь, беречь, печь family)
    {"огла","очь"}, {"огли","очь"}, {"ёг","ечь"}, {"егла","ечь"},
    -- "-ешь/-ишь" 2sg present
    {"ешь","ать"}, {"ешь","ать"}, {"ешь","еть"},
    {"ишь","ить"},
    -- 2-letter suffixes
    {"ах","а"}, {"ах",""},
    {"ях","я"}, {"ях",""},
    {"ам","а"}, {"ам",""},
    {"ям","я"}, {"ям",""},
    {"ов",""}, {"ёв",""}, {"ев",""},
    {"ей","ь"}, {"ей",""},
    {"ий","ие"}, {"ий",""},
    {"ою","а"}, {"ею","я"},
    {"ой","а"}, {"ой","ая"}, {"ой","ой"},
    {"ем",""}, {"ом",""}, {"ём",""},
    {"ая","ый"}, {"яя","ий"},
    {"ое","ый"}, {"ее","ий"},
    {"ые","ый"}, {"ие","ий"},
    {"ую","ая"}, {"юю","яя"}, {"ую",""},
    -- Past-tense verbs (strip, add "-ть")
    {"ли","ть"}, {"ла","ть"}, {"ло","ть"}, {"лся","ться"},
    -- Present-tense 3rd person
    {"ют","ть"}, {"ут","ть"}, {"ят","ить"}, {"ат","ать"},
    {"ет","ть"}, {"ит","ить"}, {"ешь","ть"}, {"ишь","ить"},
    -- 1-letter suffixes (2-byte)
    {"у","а"}, {"у",""}, {"ю","я"}, {"ю","ь"},  {"ю",""},
    {"а",""}, {"я",""}, {"я","й"},
    {"е","а"}, {"е","я"}, {"е","ь"}, {"е",""},
    {"и","а"}, {"и","я"}, {"и","ь"}, {"и",""},
    {"ы",""},
    {"л","ть"}, {"й",""},
    -- Zero-ending fallbacks (add a fem nominative ending)
    {"","а"}, {"","я"}, {"","ь"},
}

-- ---------------------------------------------------------------------------
-- WordLookup helper (consults core + optional extra dict based on liteMode)
-- ---------------------------------------------------------------------------
-- ns.WORDS is the always-loaded core (~75k entries: WoW-specific + top
-- frequencies + TBC emulator DB). ns.WORDS_EXTRA is the optional Kaikki
-- Wiktionary pack (~350k) loaded via Dictionary_Full.lua. When
-- db.liteMode is true, we only consult core — effectively running on a
-- reduced vocabulary even if the Full pack is loaded.
-- Defensive: reject Kaikki values that are bare grammatical metadata
-- ("accusative singular of", "genitive plural of", etc.) so the lemmatizer
-- gets a chance to derive a real translation from the base form.
-- Belt-and-suspenders alongside ingestion-time filtering.
local function isZombieGloss(s)
    if not s then return false end
    if s:find("singular of$") or s:find("plural of$") then return true end
    if s:find("^plural of") or s:find("^singular of") then return true end
    if s:find(" form of$") or s:find("^form of") then return true end
    if s:find(" tense of$") or s:find(" participle of$") then return true end
    if s:find("imperative of$") or s:find("conditional of$") then return true end
    if s:find("diminutive of$") or s:find("augmentative of$") then return true end
    if s:find("comparative of$") or s:find("superlative of$") then return true end
    if s:find("comparative degree of$") or s:find("superlative degree of$") then return true end
    if s:find("verbal noun of$") or s:find("pejorative of$") then return true end
    if s:find("perfective form of$") or s:find("imperfective form of$") then return true end
    if s:find("active participle$") or s:find("passive participle$") then return true end
    if s:find("^short masculine") or s:find("^short feminine")
        or s:find("^short neuter") or s:find("^short plural") then return true end
    if s:find("^[%w%-]+%-person ") then return true end  -- "first-person ...", "second-person ..."
    -- Wiktionary "the X of" / "the X of Y" stub glosses (state, name, act,
    -- quality, process, action) — these were sometimes lifted as a value
    -- with no following entity. The intent here is the bare-stub form;
    -- we accept "the act of stealing" but reject "the act of$".
    if s:find("^the name of$") or s:find("^the name of ") then return true end
    if s:find("^the act of$") or s:find("^the state of$")
        or s:find("^the quality of$") or s:find("^the process of$")
        or s:find("^the action of$") then return true end
    -- Spelling / form variants stripped to bare metadata
    if s:find("^archaic form of$") or s:find("^archaic spelling of$") then return true end
    if s:find("^nonstandard spelling of$") or s:find("^pronunciation spelling of$") then return true end
    if s:find("^obsolete spelling of$") or s:find("^obsolete form of$") then return true end
    if s:find("^abbreviation of$") or s:find("^syllabic abbreviation of$") then return true end
    -- Person-stub glosses ("a person who", "someone who", "one who") with
    -- nothing following, or following with no actual content.
    if s:find("^a person who$") or s:find("^someone who$") or s:find("^one who$") then return true end
    if s:find("^a person who ") and #s < 18 then return true end  -- "a person who is" etc, very short
    return false
end

local function WordLookup(tok)
    local hit = ns.WORDS[tok]
    if hit then return hit end
    if db and db.liteMode then return nil end
    -- ns.WORDS_EXTRA_TABLES is a list of per-chunk sub-tables. We don't
    -- merge them into one giant lookup because WoW 2.4.3's Lua caps a
    -- single table around 2^18 = 262144 entries before insertions silently
    -- start dropping. Keeping chunks separate means N hash lookups per
    -- token but each is O(1), so net cost is still trivial.
    local tables = ns.WORDS_EXTRA_TABLES
    if tables then
        for i = 1, #tables do
            local h = tables[i][tok]
            if h and not isZombieGloss(h) then return h end
        end
    end
    return nil
end

local function Lemmatize(tok)
    -- Skip tokens shorter than 4 bytes (< 2 Cyrillic letters)
    if #tok < 4 then return nil end
    for i = 1, #LEMMA_RULES do
        local suf, addback = LEMMA_RULES[i][1], LEMMA_RULES[i][2]
        local sl = #suf
        if sl == 0 or tok:sub(-sl) == suf then
            local cand = (sl == 0) and (tok .. addback)
                                    or (tok:sub(1, -sl - 1) .. addback)
            if #cand >= 4 then
                local hit = WordLookup(cand)
                if hit then return hit end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Perfectivizing-prefix stripper
-- ---------------------------------------------------------------------------
-- Russian has ~16 prefixes that make an imperfective verb perfective:
--   писать → написать, подписать, переписать, записать, списать, …
-- Each prefixed form is a distinct verb but shares the base meaning.
-- Storing every prefix×base combination is wasteful; instead, strip the
-- prefix and look up the imperfective root.
--
-- Ordered longest-first to avoid premature shorter-match (e.g. "перепис..."
-- must match "пере-" not "пе-").
--
-- Safety: only strip if the remainder is a dictionary verb (translation
-- starts with "to " or "I " or similar verb pattern). Otherwise return nil
-- — prevents misfire on non-verbs like погода (weather, not a verb).
local PERFECTIVIZING_PREFIXES = {
    "перед", "разо", "подо", "надо", "обо", "ото", "изо", "вос",
    "пере", "разу", "пред", "вне", "под", "над", "при", "про",
    "раз", "рас", "воз", "вос", "низ", "нис", "ото",
    "вы", "за", "на", "по", "от", "об", "до", "из", "ис", "со",
    "у", "о", "в", "с",
}

local function IsVerbGloss(s)
    -- Cheap heuristic: does this English string look like a verb definition?
    if not s or s == "" then return false end
    -- Infinitive "to ..."
    if s:sub(1, 3) == "to " then return true end
    -- 1st-person "I ..."
    if s:sub(1, 2) == "I " then return true end
    -- English past-tense / gerund endings
    if s:match("ing$") or s:match("ed$") or s:match("s$") then return true end
    return false
end

local function TryPerfectivePrefix(tok)
    -- Skip tokens that are too short to hold a prefix + 4-char stem.
    if #tok < 8 then return nil end
    for i = 1, #PERFECTIVIZING_PREFIXES do
        local pfx = PERFECTIVIZING_PREFIXES[i]
        local pl = #pfx
        if tok:sub(1, pl) == pfx then
            local remainder = tok:sub(pl + 1)
            if #remainder >= 6 then  -- min 3 Cyrillic letters in base
                -- Direct hit on base
                local hit = WordLookup(remainder)
                if hit and IsVerbGloss(hit) then
                    return hit
                end
                -- Inflected base → lemmatize it
                local lem = Lemmatize(remainder)
                if lem and IsVerbGloss(lem) then
                    return lem
                end
            end
        end
    end
    return nil
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

    local hit = WordLookup(token)
    if hit then return hit, true end

    -- Lemmatization fallback: strip case endings and try again.
    local lemma_hit = Lemmatize(token)
    if lemma_hit then return lemma_hit, true end

    -- Perfectivizing-prefix fallback: strip prefix, look up base verb.
    local prefix_hit = TryPerfectivePrefix(token)
    if prefix_hit then return prefix_hit, true end

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

    -- Pull item/spell links out before any case folding or substitution.
    local linkSubs
    normalized, linkSubs = ExtractLinks(normalized)

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

    local withPh, subs = ApplyPhrases(lowered)
    -- Count phrase hits — each substituted phrase is a real-Russian
    -- signal regardless of token-level outcome.
    local phraseHits = 0
    for _ in pairs(subs) do phraseHits = phraseHits + 1 end
    -- Track whether we've already seen a Cyrillic token — only the first
    -- one is eligible for the "is this a player name being addressed?"
    -- check. (Mid-message occurrences default to normal translation.)
    local seenFirstCyr = false
    local translatedHits = 0
    local out = withPh:gsub("[%w\128-\255\1]+", function(tok)
        local isFirst = false
        local isCyr = HasUtf8Cyrillic(tok) and not tok:find("^\1")
        if (not seenFirstCyr) and isCyr then
            isFirst = true
            seenFirstCyr = true
        end
        local result, hit = TranslateToken(tok, normalized, isFirst)
        if isCyr and hit then translatedHits = translatedHits + 1 end
        return result
    end)

    -- Mojibake guard. The Moonwell server (and others) sometimes substitute
    -- Polish/Czech diacritics with similar-looking Cyrillic letters at the
    -- character level. We tag [Russian] only when at least one of:
    --   (a) the normalized message has a Cyrillic run of 3+ consecutive
    --       characters (UTF-8: 6 bytes of paired 0xD0/0xD1 + 0x80-0xBF),
    --       which preserves real Russian even when all words happen to
    --       be missing from our dictionary, OR
    --   (b) any phrase or any Cyrillic token resolved through the
    --       dict / lemmatizer / prefix-stripper, which preserves short
    --       Russian like "да ок" that wouldn't clear the byte threshold.
    local hasCyrRun3 = normalized:find(
        "[\208\209][\128-\191][\208\209][\128-\191][\208\209][\128-\191]")
    if (not hasCyrRun3) and (translatedHits + phraseHits) == 0 then
        return nil
    end

    out = RestorePhrases(out, subs)
    out = RestoreLinks(out, linkSubs)

    session.messagesTranslated = session.messagesTranslated + 1
    return out, normalized, enc
end

-- ---------------------------------------------------------------------------
-- Vulgar-output censor
-- ---------------------------------------------------------------------------
-- Dictionary values for vulgar Russian are stored as their real English
-- equivalents ("fuck", "bitch", "shit", etc.) -- accurate to the chat
-- register on Russian PvP servers. To keep public-channel output workplace-
-- safe by default, we post-process every English translation through this
-- censor before showing it. db.vulgar = true bypasses the censor entirely.
--
-- Longest-first ordering matters: "fucking" must be censored before "fuck"
-- so the latter's pattern doesn't re-match the inner "fuck" substring of
-- the censored result. Each entry is gsub'd with a word-boundary check
-- (frontier pattern %f[%w] / %f[%W]) to avoid mangling words that happen
-- to contain the bad substring (e.g. "asshole" containing "ass").
local CENSOR_ORDER = {
    -- f-bomb family (longest first)
    { "motherfucker", "m-fer" },
    { "motherfucking", "m-fing" },
    { "fucking",  "f***ing"  },
    { "fucker",   "f***er"   },
    { "fucked",   "f***ed"   },
    { "fuck",     "f***"     },
    -- shit family
    { "shitstuff", "trash"  },
    { "shitty",    "lousy"  },
    { "shitter",   "sh**ter"},
    { "shitting",  "sh**ing"},
    { "shitted",   "sh**ted"},
    { "shit",      "sh**"   },
    { "bullshitter", "BS-talker" },
    { "bullshitting","BS-ing" },
    { "bullshit",  "BS"     },
    -- other
    { "asshole",   "a**hole"},
    { "dickhead",  "d***head"},
    { "bitches",   "b****es"},
    { "bitch",     "b****"  },
    { "cunt",      "c***"   },
    { "pussy",     "p****"  },
    { "dick",      "d***"   },
    { "faggot",    "f-slur" },
    { "fag",       "f-slur" },
    { "whore",     "w****"  },
    { "slut",      "s***"   },
}

local function CensorOutput(s)
    if type(s) ~= "string" or s == "" then return s end
    for _, e in ipairs(CENSOR_ORDER) do
        s = s:gsub("(%f[%w])" .. e[1] .. "(%f[%W])", "%1" .. e[2] .. "%2")
    end
    return s
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
    -- Also: require min 3 Cyrillic letters and reject if the bare name is
    -- itself a dictionary word (paranoia against malformed sender fields).
    local sender = (select(1, ...))
    if type(sender) == "string" and sender ~= "" then
        local bare = sender:match("^([^%-]+)") or sender
        local low = bare:lower()
        if ns.DetectCyrillicEncoding(low) ~= "ascii" then
            low = ns.NormalizeCyrillic(low)
            local _, cyrChars = low:gsub("[\208\209][\128-\191]", "")
            if cyrChars >= 3 and not ns.WORDS[low] then
                session.knownNames[low] = (session.knownNames[low] or 0) + 1
            end
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

    -- Censor vulgar English unless user explicitly opted in. Applied
    -- only to the English translation -- the Cyrillic (original) in
    -- the trailing parens stays as-is regardless.
    if not (db and db.vulgar) then
        translated = CensorOutput(translated)
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
-- Server-spam suppression
-- ---------------------------------------------------------------------------
-- The Moonwell server (and others) periodically broadcast notifications
-- (e.g. "1v1 arena match just ended.") that aren't useful to read every
-- two minutes. The text can come through any of several events depending
-- on how the server core wraps it — sometimes CHAT_MSG_SYSTEM, sometimes
-- a custom event, sometimes added directly to the chat frame bypassing
-- events entirely. We can't predict the route, so we filter at the
-- absolute last layer: hook every chat frame's :AddMessage and drop the
-- call if the text matches.
--
-- Matching is content-based, normalized (lowercase, trimmed trailing
-- whitespace+punctuation) — adding a new spam string takes one line
-- below.
local SUPPRESS_EXACT = {
    ["1v1 arena match just ended"] = true,
}

local function NormalizeForSuppress(msg)
    if type(msg) ~= "string" or msg == "" then return nil end
    -- Strip color codes |cXXXXXXXX...|r in case the server wraps text.
    local s = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Trim leading/trailing whitespace.
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    -- Strip a single trailing period (so "X." == "X").
    s = s:gsub("%.$", "")
    return s:lower()
end

local function ShouldSuppress(msg)
    local norm = NormalizeForSuppress(msg)
    if not norm then return false end
    return SUPPRESS_EXACT[norm] == true
end

local function SuppressionFilter(msg, ...)
    local ok, hit = pcall(ShouldSuppress, msg)
    if ok and hit then return true end
    return false
end

-- AddMessage hook installer. This runs once at PLAYER_LOGIN (after chat
-- frames exist) and wraps each frame's :AddMessage with a content check.
-- We don't use hooksecurefunc here because we need to *prevent* the
-- original call, not just observe it.
local addMessageHooked = false
local function HookChatFrameAddMessage()
    if addMessageHooked then return end
    addMessageHooked = true
    local n = NUM_CHAT_WINDOWS or 7
    local hooked = 0
    for i = 1, n do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage and not frame.__rt_addmsg_orig then
            local orig = frame.AddMessage
            frame.__rt_addmsg_orig = orig
            frame.AddMessage = function(self, text, r, g, b, id)
                if ShouldSuppress(text) then
                    return  -- drop entirely
                end
                return orig(self, text, r, g, b, id)
            end
            hooked = hooked + 1
        end
    end
    Log("addmsg-hooked", { frames = hooked })
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
    -- Seed known-names with Cyrillic nicks harvested from historical chat
    -- logs. These are treated as nicknames only at message-start position
    -- (TranslateToken's isFirstCyrillic check) — they still translate
    -- normally mid-sentence if they happen to be regular Russian words.
    if ns.BUILTIN_NICKS then
        for nick, _ in pairs(ns.BUILTIN_NICKS) do
            session.knownNames[nick] = 0  -- seed with count=0 so real
                                           -- chat-event sightings still
                                           -- increment normally
        end
    end
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
    if db.liteMode     == nil then db.liteMode     = false end  -- full vocab by default
    if db.vulgar       == nil then db.vulgar       = false end  -- censor by default
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

    local cbLite = makeCheckbox("Lite vocabulary (~75k, faster load)",
        "Skip the extended Kaikki Wiktionary pack (~350k entries). "
        .. "Core vocabulary (WoW slang + TBC item/NPC DB + top frequencies) "
        .. "stays active. Requires /reload to apply.",
        cbDebug, -4,
        function() return db and db.liteMode end,
        function(v)
            db.liteMode = v
            Msg("liteMode = "..tostring(v)
                .." — |cffffcc00/reload|r required to apply")
        end)

    local cbVulgar = makeCheckbox("Vulgar",
        "Uncensored vulgar output (NSFW). When off (default), words like "
        .. "'fuck' / 'shit' / 'bitch' in translations are softened to "
        .. "'f***' / 'sh**' / 'b****'. The original Cyrillic in parens is "
        .. "never censored.",
        cbLite, -4,
        function() return db and db.vulgar end,
        function(v) db.vulgar = v
            Msg("vulgar output = "..(v and "ON (uncensored)" or "OFF (censored)"))
        end)

    -- Footnote
    local footer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    footer:SetPoint("TOPLEFT", cbVulgar, "BOTTOMLEFT", 0, -16)
    footer:SetText("Tip: /rt help in chat lists all commands. /rt lite toggles vocabulary; /rt vulgar toggles censorship.")

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
    -- Suppression filter — content-based exact-match against SUPPRESS_EXACT.
    -- We hook every event that can carry server-spam text:
    --   CHAT_MSG_SYSTEM      — yellow announcer line (the "1v1 arena
    --                          match just ended" case)
    --   CHAT_MSG_CHANNEL     — already covered above for translation, the
    --                          suppression filter runs additionally and a
    --                          "true" return value short-circuits.
    -- Adding more events here is cheap; suppression is tested before
    -- translation in registration order so it always wins.
    for _, ev in ipairs({
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        "CHAT_MSG_BG_SYSTEM_ALLIANCE",
        "CHAT_MSG_BG_SYSTEM_HORDE",
    }) do
        ChatFrame_AddMessageEventFilter(ev, SuppressionFilter)
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
    Msg("  /rt lite             - toggle lite vocab (~75k, faster) vs full (~425k). /reload to apply")
    Msg("  /rt vulgar           - toggle uncensored vulgar output (default: censored)")
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
    elseif cmd == "lite" then
        db.liteMode = not db.liteMode
        Msg("liteMode = " .. tostring(db.liteMode)
            .. " — |cffffcc00/reload|r required to apply")
    elseif cmd == "vulgar" then
        db.vulgar = not db.vulgar
        Msg("vulgar output = " .. (db.vulgar and "ON (uncensored)" or "OFF (censored)"))
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
        Msg(("enabled=%s  showOrig=%s  debug=%s  autoChatLog=%s  vulgar=%s  chatlog-now=%s  sessions=%d  nicks=%d"):format(
            tostring(db.enabled), tostring(db.showOrig),
            tostring(db.debug), tostring(db.autoChatLog),
            tostring(db.vulgar),
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
        pcall(HookChatFrameAddMessage)
        local chatlog = "off"
        if db.autoChatLog then
            if EnsureChatLog() then chatlog = "on" end
        end
        Msg("|cffffcc00made by Grzegorz Korycki (Poczwarka)|r")
        -- BUILD STAMP — if this doesn't change across /reload, the addon
        -- isn't being reloaded. Update on every edit so we can tell.
        -- Keep word chunks as SEPARATE sub-tables — never merge into one
        -- giant lookup. WoW 2.4.3's Lua silently drops inserts past ~2^18
        -- (262144) entries per table. WordLookup walks the list of tables.
        ns.WORDS_EXTRA_TABLES = {}
        -- Forms chunks first — derived from curated core lemmas via pymorphy3,
        -- so they're higher confidence than Wiktionary glosses. WordLookup
        -- walks tables in order, first hit wins.
        local fchunks, fcount = 0, 0
        for i = 1, 20 do
            local k = "RT_WORDS_FORMS_" .. (i < 10 and "0"..i or tostring(i))
            local t = _G[k]
            if t then
                table.insert(ns.WORDS_EXTRA_TABLES, t)
                fchunks = fchunks + 1
                pcall(function()
                    for _ in pairs(t) do fcount = fcount + 1 end
                end)
                _G[k] = nil
            end
        end
        -- Then Kaikki Wiktionary chunks — covers rare lexemes that aren't
        -- in core (so no Forms expansion exists for them).
        local wchunks, wcount = 0, 0
        for i = 1, 20 do
            local k = "RT_WORDS_EXTRA_" .. (i < 10 and "0"..i or tostring(i))
            local t = _G[k]
            if t then
                table.insert(ns.WORDS_EXTRA_TABLES, t)
                wchunks = wchunks + 1
                pcall(function()
                    for _ in pairs(t) do wcount = wcount + 1 end
                end)
                _G[k] = nil
            end
        end
        -- Phrases (~51k total) fit in a single table — under the 262k cap.
        ns.PHRASES_EXTRA = ns.PHRASES_EXTRA or {}
        local pchunks = 0
        for i = 1, 5 do
            local k = "RT_PHRASES_EXTRA_0" .. i
            local t = _G[k]
            if t then
                local ok = pcall(function()
                    for kk, vv in pairs(t) do ns.PHRASES_EXTRA[kk] = vv end
                end)
                if ok then pchunks = pchunks + 1 end
                _G[k] = nil
            end
        end
        pcall(function()
            if next(ns.PHRASES_EXTRA) then
                ns.PHRASE_ORDER_EXTRA = {}
                for k in pairs(ns.PHRASES_EXTRA) do
                    table.insert(ns.PHRASE_ORDER_EXTRA, k)
                end
                table.sort(ns.PHRASE_ORDER_EXTRA, function(a, b) return #a > #b end)
            end
        end)
        local coreWords = 0
        pcall(function()
            for _ in pairs(ns.WORDS or {}) do coreWords = coreWords + 1 end
        end)
        local totalWords = coreWords + fcount + wcount
        local coreOK = ns.WORDS and ns.PHRASES
        Msg("|cff55ddffRussian Translator v1.8.7|r")
        Msg(" core:   " .. (coreOK and "|cff00ff00YES|r" or "|cffff0000NO|r")
            .. " (" .. coreWords .. " words)")
        Msg(" forms:  " .. ((fchunks == 20)
            and ("|cff00ff00YES|r ("..fchunks.."/20, " .. fcount .. " forms)")
            or ("|cffff0000PARTIAL|r ("..fchunks.."/20)")))
        Msg(" chunks: " .. ((wchunks == 20 and pchunks == 5)
            and ("|cff00ff00YES|r ("..wchunks.."/20 word, "..pchunks.."/5 phrase)")
            or ("|cffff0000PARTIAL|r ("..wchunks.."/20 word, "..pchunks.."/5 phrase)")))
        Msg(" total:  " .. totalWords .. " words")
        pcall(function()
            Msg("loaded session=" .. tostring(session.started)
                .. " filters=" .. tostring(ok) .. " chatlog=" .. tostring(chatlog))
        end)
    elseif event == "PLAYER_LOGOUT" then
        if session then
            session.ended = date("%Y-%m-%d_%H-%M-%S")
            Log("session-end", {})
        end
    end
end)
