-- Shared namespace between Dictionary.lua and Core.lua.
-- We can't use the Lua 5.1 `...` varargs trick at the top of an addon file
-- because that pattern only works on WotLK 3.0.2+ clients. On 2.4.3 the addon
-- top-level varargs are empty, so `local addonName, ns = ...` silently yields
-- two nils and every subsequent `ns.foo = ...` explodes with
-- "attempt to index nil value 'ns'".
RussianTranslatorNS = RussianTranslatorNS or {}
local ns = RussianTranslatorNS

-- ---------------------------------------------------------------------------
-- Cyrillic UTF-8 helpers
-- ---------------------------------------------------------------------------
-- Every Cyrillic letter in UTF-8 is 2 bytes: lead 0xD0 or 0xD1, trail 0x80-0xBF.
-- Lua 5.1 strings are byte sequences, so we can pattern-match on byte ranges
-- and gsub on 2-byte literals safely.

-- Uppercase -> lowercase map for the 33 Cyrillic letters + Ё.
-- Covers user input that starts a sentence with a capital, or yells in caps.
ns.CYR_LOWER = {
    ["А"]="а",["Б"]="б",["В"]="в",["Г"]="г",["Д"]="д",["Е"]="е",["Ё"]="ё",
    ["Ж"]="ж",["З"]="з",["И"]="и",["Й"]="й",["К"]="к",["Л"]="л",["М"]="м",
    ["Н"]="н",["О"]="о",["П"]="п",["Р"]="р",["С"]="с",["Т"]="т",["У"]="у",
    ["Ф"]="ф",["Х"]="х",["Ц"]="ц",["Ч"]="ч",["Ш"]="ш",["Щ"]="щ",["Ъ"]="ъ",
    ["Ы"]="ы",["Ь"]="ь",["Э"]="э",["Ю"]="ю",["Я"]="я",
}

-- Transliteration table (GOST-ish, readable by English speakers).
-- Retained as fallback — Core.lua does not currently use it; untranslated
-- tokens are shown in colored Cyrillic instead so the user can still read them.
ns.TRANSLIT = {
    ["а"]="a",  ["б"]="b", ["в"]="v", ["г"]="g", ["д"]="d",  ["е"]="e",
    ["ё"]="yo", ["ж"]="zh",["з"]="z", ["и"]="i", ["й"]="y",  ["к"]="k",
    ["л"]="l",  ["м"]="m", ["н"]="n", ["о"]="o", ["п"]="p",  ["р"]="r",
    ["с"]="s",  ["т"]="t", ["у"]="u", ["ф"]="f", ["х"]="kh", ["ц"]="ts",
    ["ч"]="ch", ["ш"]="sh",["щ"]="sch",["ъ"]="", ["ы"]="y",  ["ь"]="",
    ["э"]="e",  ["ю"]="yu",["я"]="ya",
}

-- ---------------------------------------------------------------------------
-- CP1251 detection & conversion
-- ---------------------------------------------------------------------------
-- Many Russian private servers on TBC 2.4.3 still ship text in CP1251
-- (Windows-1251) rather than UTF-8. A ruRU client (or one with CyrillicFix)
-- renders CP1251 bytes as Cyrillic directly, which is why the user SEES
-- normal Russian while a UTF-8-only pipeline treats the message as "no
-- Cyrillic found" and passes it through.

function ns.CP1251ToUtf8(s)
    return (s:gsub("[\168\184\192-\255]", function(ch)
        local b = ch:byte()
        if b == 0xA8 then return "\208\129" end     -- Ё
        if b == 0xB8 then return "\209\145" end     -- ё
        if b >= 0xC0 and b <= 0xEF then
            return "\208" .. string.char(b - 0xC0 + 0x90)
        end
        if b >= 0xF0 and b <= 0xFF then
            return "\209" .. string.char(b - 0xF0 + 0x80)
        end
        return ch
    end))
end

function ns.DetectCyrillicEncoding(s)
    if s:find("[\208\209][\128-\191]") then return "utf8" end
    if s:find("[\168\184\192-\255]")   then return "cp1251" end
    return "ascii"
end

function ns.NormalizeCyrillic(s)
    local enc = ns.DetectCyrillicEncoding(s)
    if enc == "cp1251" then return ns.CP1251ToUtf8(s), "cp1251" end
    return s, enc
end

-- ---------------------------------------------------------------------------
-- Phrase dictionary (multi-word)
-- Scanned longest-first at runtime (ns.PHRASE_ORDER built below).
-- Keys are already lowercase UTF-8. Keep values in English.
-- ---------------------------------------------------------------------------
ns.PHRASES = {
    -- ---- Guild recruitment ads (extremely common on Russian TBC chat) ----
    ["пве гильдия"]                 = "PvE guild",
    ["пвп гильдия"]                 = "PvP guild",
    ["ведет набор активных игроков"]= "recruiting active players",
    ["ведет набор игроков"]         = "recruiting players",
    ["ведет набор"]                 = "recruiting",
    ["набор активных игроков"]      = "recruiting active players",
    ["в мейн статик"]               = "for the main raid roster",
    ["мейн статик"]                 = "main raid roster",

    -- ---- LFG / LFM patterns ----
    ["есть кто на"]                 = "anyone for",
    ["есть кто в"]                  = "anyone in",
    ["есть кто"]                    = "anyone here for",
    ["кто на"]                      = "anyone for",
    ["кто в"]                       = "anyone in",
    ["ищу группу"]                  = "LFG",
    ["ищу пати"]                    = "LFG",
    ["ищу ренд"]                    = "LFG pug",
    ["ищу рандом"]                  = "LFG pug",
    ["ищу героик"]                  = "LF heroic",
    ["есть героики"]                = "any heroics",
    ["есть героик"]                 = "any heroic",
    ["ищу чантера"]                 = "LF enchanter",
    ["ищу чара"]                    = "LF enchanter",
    ["собираю пати"]                = "forming party",
    ["собираю ренд"]                = "forming pug",
    ["собираю рампы"]               = "forming Ramparts",
    ["нид все"]                     = "need everyone",
    ["нид танк"]                    = "need tank",
    ["нид хил"]                     = "need healer",
    ["нид хилл"]                    = "need healer",
    ["нид дд"]                      = "need dps",
    ["нид 1дд"]                     = "need 1 dps",
    ["нид 2дд"]                     = "need 2 dps",
    ["нид 3дд"]                     = "need 3 dps",
    ["нид хил дд"]                  = "need healer dps",
    ["нид танк хил"]                = "need tank healer",
    ["нужен хил"]                   = "need healer",
    ["нужен танк"]                  = "need tank",
    ["нужен дд"]                    = "need dps",
    ["нужна пара дд"]               = "need 2 dps",
    ["пара дд"]                     = "2 dps",
    ["хил дд"]                      = "healer + dps",
    ["хил пара дд"]                 = "healer + 2 dps",
    ["хил и дд"]                    = "healer and dps",
    ["танк и хил"]                  = "tank and healer",
    ["танк хил дд"]                 = "tank healer dps",

    -- ---- Arena / PvP ----
    ["рег аренку"]                  = "reg arena",
    ["рег 2х2"]                     = "reg 2v2",
    ["рег 3х3"]                     = "reg 3v3",
    ["рег 5х5"]                     = "reg 5v5",
    ["стартую аренку"]              = "starting arena",
    ["стартуем аренку"]             = "starting arena",

    -- ---- Instances — full Russian names mapped to English ----
    ["громовой утес"]               = "Thunder Bluff",
    ["громовый утес"]               = "Thunder Bluff",
    ["огненная пропасть"]           = "Ragefire Chasm",
    ["огненую пропасть"]            = "Ragefire Chasm",
    ["огненой пропасти"]            = "Ragefire Chasm",
    ["пекло крови"]                 = "Blood Furnace",
    ["рампы об"]                    = "Ramparts (normal)",
    ["бф об"]                       = "Blood Furnace (normal)",
    ["бф хс"]                       = "Blood Furnace (heroic)",
    ["шх хс"]                       = "Shattered Halls (heroic)",
    ["шх об"]                       = "Shattered Halls (normal)",
    ["шм хс"]                       = "Shadow Labs (heroic)",
    ["шм об"]                       = "Shadow Labs (normal)",
    ["гробница маны"]               = "Mana-Tombs",
    ["палаты стазиса"]              = "Stasis Chambers",
    ["склепы аукенай"]              = "Auchenai Crypts",
    ["сетеки нормал"]               = "Sethekk Halls (normal)",
    ["сетеки хс"]                   = "Sethekk Halls (heroic)",
    ["сетеки хк"]                   = "Sethekk Halls (heroic)",
    ["паровое подземелье"]          = "Steamvault",
    ["загон для рабов"]             = "Slave Pens",
    ["логово змея"]                 = "Serpentshrine Cavern",
    ["око бури"]                    = "Tempest Keep",
    ["чёрный храм"]                 = "Black Temple",
    ["черный храм"]                 = "Black Temple",
    ["терраса магистров"]           = "Magisters' Terrace",
    ["логово груула"]               = "Gruul's Lair",
    ["гора хиджал"]                 = "Mount Hyjal",
    ["хиджал саммит"]               = "Hyjal Summit",
    ["в сердце разрушителя душ"]    = "Heart of the Soul-Destroyer (quest)",
    ["разрушителя душ"]             = "Soul-Destroyer",
    ["книга имен скверны"]          = "Book of Fel Names (quest)",
    ["имен скверны"]                = "Fel Names",
    ["погибли при исполнении"]      = "Died in the Line of Duty (quest)",
    ["ослабить оборону валов"]      = "Weaken the Ramparts (quest)",

    -- ---- Item / buy / sell ----
    ["куплю много"]                 = "WTB many",
    ["продам дешево"]               = "WTS cheap",
    ["куплю прицел"]                = "WTB scope",
    ["в пм"]                        = "in PM",
    ["пиши в пм"]                   = "whisper me",
    ["пиши личкой"]                 = "whisper me",

    -- ---- Greetings / closers / thanks ----
    ["всем привет"]                 = "hi all",
    ["всем пока"]                   = "bye all",
    ["всем удачи"]                  = "gl all",
    ["спасибо всем"]                = "thanks all",
    ["спс всем"]                    = "thx all",
    ["доброго дня"]                 = "good day",
    ["добрый день"]                 = "good day",
    ["добрый вечер"]                = "good evening",
    ["доброе утро"]                 = "good morning",
    ["спокойной ночи"]              = "good night",

    -- ---- Common requests ----
    ["дай инв"]                     = "gimme inv",
    ["кинь инв"]                    = "gimme inv",
    ["дай тп"]                      = "give me a port",
    ["тп дать"]                     = "give a port",
    ["призвать по камню"]           = "summon me via stone",
    ["призват по камню"]            = "summon me via stone",
    ["по камню призвать"]           = "summon via stone",
    ["держи в курсе"]               = "keep me updated",
    ["я так понимаю"]               = "as I understand",
    ["на этом сервере"]             = "on this server",
    ["на форуме"]                   = "on the forum",
    ["тикет бан"]                   = "ticket ban",
    ["скрин тикет"]                 = "screenshot + ticket",
    ["на сайте"]                    = "on the site",
    ["в дискорде"]                  = "on discord",
    ["прощальные посты"]            = "farewell posts",
    ["реалму конец"]                = "the realm is done",
    ["реалм умер"]                  = "realm is dead",
    ["хороший реалм"]               = "good realm",
    ["онлайн"]                      = "online",
    ["ни бг ни героиков"]           = "neither BG nor heroics",
    ["ни бг"]                       = "no BGs",
    ["нет конешно"]                 = "of course not",
    ["нет конечно"]                 = "of course not",
    ["конечно нет"]                 = "of course not",
    ["конешно нет"]                 = "of course not",
    ["ну тут"]                      = "well here",
    ["1 человек"]                   = "one person",
    ["один человек"]                = "one person",
    ["на русском"]                  = "in Russian",
    ["было бы понятнее"]            = "would be clearer",
    ["последние слова"]             = "last words",
    ["жаль конечно"]                = "shame of course",
    ["по кв"]                       = "for quest",
    ["на кв"]                       = "for quest",
    ["кто нибудь"]                  = "anyone",
    ["кто-нибудь"]                  = "anyone",
    ["на плащ"]                     = "on cloak",
    ["на оружие"]                   = "on weapon",
    ["на перчи"]                    = "on gloves",
    ["на грудь"]                    = "on chest",
    ["на кольцо"]                   = "on ring",
    ["на палку"]                    = "on staff",
    ["на 2 руки"]                   = "on 2-handed",
    ["к пиву"]                      = "to beer",
    ["ходу"]                        = "go/come on",
    ["чем быстрей тем лучше"]       = "the faster the better",
    ["в курсе"]                     = "in the loop",

    -- ---- Raid progress shorthand ("ХС 5/5 БТ 7/9" etc) ----
    ["хс 5/5"]                      = "Hyjal 5/5",
    ["бт 7/9"]                      = "BT 7/9",
    ["бт 9/9"]                      = "BT 9/9 (cleared)",
    ["ссц 6/6"]                     = "SSC 6/6",
    ["тк 4/4"]                      = "TK 4/4",
    ["хс 4/5"]                      = "Hyjal 4/5",

    -- ---- Go-something (let's go) ----
    ["го кара"]                     = "let's go Karazhan",
    ["го бт"]                       = "let's go Black Temple",
    ["го за"]                       = "let's go Zul'Aman",
    ["го зуль"]                     = "let's go Zul'Aman",
    ["го груул"]                    = "let's go Gruul",
    ["го маг"]                      = "let's go Magtheridon",
    ["го ссц"]                      = "let's go Serpentshrine",
    ["го тк"]                       = "let's go Tempest Keep",
    ["го мгт"]                      = "let's go Magisters' Terrace",
    ["го хиджал"]                   = "let's go Hyjal",
    ["го шм"]                       = "let's go Shadow Labs",
    ["го шх"]                       = "let's go Shattered Halls",
    ["го бф"]                       = "let's go Blood Furnace",
    ["го рфс"]                      = "let's go Ragefire",
    ["го сфк"]                      = "let's go Shadowfang Keep",
    ["го рампы"]                    = "let's go Ramparts",
    ["го арену"]                    = "let's go arena",
    ["го аренку"]                   = "let's go arena",
    ["го бг"]                       = "let's go BG",
    ["го дейлики"]                  = "let's go dailies",
    ["го дейли"]                    = "let's go daily",

    -- ---- Multi-word patterns that collapse nicely ----
    ["кто на кару"]                 = "anyone for Karazhan",
    ["кто на бт"]                   = "anyone for Black Temple",
    ["кто на за"]                   = "anyone for Zul'Aman",
    ["кто на ссц"]                  = "anyone for Serpentshrine",
    ["кто на тк"]                   = "anyone for Tempest Keep",
    ["кто на мгт"]                  = "anyone for Magisters' Terrace",
    ["кто на бг"]                   = "anyone for BG",
    ["кто на арену"]                = "anyone for arena",
    ["кто на аренку"]               = "anyone for arena",
    ["кто на хс"]                   = "anyone for heroic",
    ["кто на рампы"]                = "anyone for Ramparts",
    ["кто в кару"]                  = "anyone in Karazhan",
    ["кто в бт"]                    = "anyone in Black Temple",

    -- ---- Complaints / chat patterns ----
    ["ппц скучно"]                  = "damn boring",
    ["очень нужно"]                 = "really need",
    ["держи курсе"]                 = "keep updated",
    ["это 1 человек"]               = "it's one person",

    -- ---- Premium / paid / shop ----
    ["премиум аккаунт"]             = "premium account",
    ["прем акк"]                    = "premium account",
    ["прем аккаунт"]                = "premium account",
}

-- ---------------------------------------------------------------------------
-- Word dictionary (single token)
-- Keys lowercase UTF-8. Value = English. Pure token substitution.
-- ---------------------------------------------------------------------------
ns.WORDS = {
    -- ====================================================================
    -- Instances / raids / zones (abbreviations + Russian names)
    -- ====================================================================
    -- 5-mans (dungeons)
    ["рфс"]="Ragefire Chasm", ["рфц"]="Ragefire Chasm", ["рфк"]="Ragefire Chasm",
    ["сфк"]="Shadowfang Keep",
    ["рампы"]="Ramparts", ["рампа"]="Ramparts", ["рампу"]="Ramparts", ["рамп"]="Ramparts",
    ["бф"]="Blood Furnace", ["фурнэс"]="Blood Furnace",
    ["шх"]="Shattered Halls", ["шатр"]="Shattered Halls", ["шатров"]="Shattered Halls",
    ["шм"]="Shadow Labs", ["шадоу"]="Shadow Labs", ["шадлаба"]="Shadow Labs",
    ["мт"]="Mana-Tombs", ["мантумбы"]="Mana-Tombs", ["мана-тумбы"]="Mana-Tombs",
    ["ботаника"]="Botanica",
    ["арка"]="Arcatraz", ["аркатраз"]="Arcatraz",
    ["механар"]="Mechanar",
    ["морох"]="Black Morass", ["морасс"]="Black Morass",
    ["ул"]="Old Hillsbrad", ["дурнхолд"]="Durnholde",
    ["склепы"]="Auchenai Crypts",
    ["сет"]="Sethekk Halls", ["сетек"]="Sethekk Halls", ["сетеки"]="Sethekk Halls", ["сетк"]="Sethekk Halls",
    ["пп"]="Steamvault", ["паровое"]="Steamvault",
    ["загон"]="Slave Pens", ["рабов"]="Slave Pens",
    ["нижетопь"]="Underbog",
    ["озеро"]="Slave Pens/Coilfang",
    ["сх"]="Shattered Halls", ["sh"]="Shattered Halls", ["shh"]="Shattered Halls",
    ["sfk"]="Shadowfang Keep",
    ["rfc"]="Ragefire Chasm", ["rfd"]="Ragefire Chasm",
    ["mgt"]="Magisters' Terrace",
    ["za"]="Zul'Aman",

    -- Raids
    ["кара"]="Karazhan", ["каражан"]="Karazhan", ["каре"]="Karazhan", ["кары"]="Karazhan",
    ["бт"]="Black Temple", ["бтшка"]="Black Temple",
    ["груул"]="Gruul", ["груула"]="Gruul", ["гр"]="Gruul",
    ["магтеридон"]="Magtheridon", ["магтер"]="Magtheridon",
    ["ссц"]="Serpentshrine", ["серпент"]="Serpentshrine",
    ["тк"]="Tempest Keep", ["око"]="The Eye",
    ["хиджал"]="Hyjal",
    ["хс"]="Hyjal Summit",
    ["мгт"]="Magisters' Terrace",
    ["за"]="Zul'Aman",
    ["зуль"]="Zul'Aman", ["зулик"]="Zul'Aman", ["зульаман"]="Zul'Aman",

    -- Bosses / NPCs (in Russian names found in logs)
    ["теракнарнтул"]="Terokk", ["тероккарнтул"]="Terokk", ["терокк"]="Terokk",
    ["суккубу"]="succubus", ["суккуб"]="succubus",

    -- Cities / zones
    ["штормград"]="Stormwind", ["шторм"]="Stormwind",
    ["оргриммар"]="Orgrimmar", ["орг"]="Orgrimmar",
    ["даларан"]="Dalaran",
    ["шаттрат"]="Shattrath", ["шатт"]="Shattrath",

    -- ====================================================================
    -- Classes / roles
    -- ====================================================================
    ["хил"]="healer", ["хилл"]="healer", ["хилер"]="healer",
    ["хила"]="healer", ["хилов"]="healers", ["хилы"]="healers",
    ["танк"]="tank", ["танки"]="tanks", ["танка"]="tank", ["танков"]="tanks",
    ["дд"]="dps", ["ддшка"]="dps", ["дпс"]="dps", ["дды"]="dps",
    ["маг"]="mage", ["маги"]="mages", ["мага"]="mage", ["магов"]="mages",
    ["хант"]="hunter", ["ханта"]="hunter", ["хантер"]="hunter", ["хантеры"]="hunters",
    ["паль"]="paladin", ["пал"]="paladin", ["падик"]="paladin",
    ["палы"]="paladins", ["палов"]="paladins", ["паладин"]="paladin",
    ["паладина"]="paladin", ["паладинов"]="paladins", ["паладины"]="paladins",
    ["лок"]="warlock", ["локи"]="warlocks", ["локов"]="warlocks",
    ["варлок"]="warlock", ["варлока"]="warlock",
    ["шам"]="shaman", ["шама"]="shaman", ["шаманы"]="shamans", ["шаман"]="shaman",
    ["прист"]="priest", ["приста"]="priest", ["присты"]="priests",
    ["шп"]="shadow priest",
    ["ро"]="rogue", ["рога"]="rogue", ["рог"]="rogue", ["рогу"]="rogue",
    ["разбойник"]="rogue", ["разбойника"]="rogue",
    ["варик"]="warrior", ["варики"]="warriors", ["воин"]="warrior", ["воины"]="warriors",
    ["друид"]="druid", ["друида"]="druid", ["друиды"]="druids", ["дру"]="druid",
    ["ферал"]="feral",
    ["баланс"]="balance",
    ["ресто"]="resto",
    ["ретри"]="retribution", ["рет"]="ret",
    ["холик"]="holy", ["холи"]="holy",
    ["протка"]="prot", ["прот"]="prot",
    ["фрост"]="frost",
    ["аркан"]="arcane",
    ["фаер"]="fire",
    ["фул"]="full",

    -- ====================================================================
    -- LFG / LFM / invite / go
    -- ====================================================================
    ["лфм"]="LFM", ["лфг"]="LFG", ["лф"]="LF",
    ["инв"]="inv", ["инвай"]="invite", ["инвайт"]="invite",
    ["го"]="go", ["поехали"]="let's go", ["погнали"]="let's go",
    ["ищу"]="LF", ["ищем"]="we need",
    ["нужен"]="need", ["нужна"]="need", ["нужно"]="need", ["нужны"]="need",
    ["надо"]="need",
    ["нид"]="need", ["ниде"]="need",
    ["берем"]="taking", ["возьму"]="will take", ["возьмем"]="will take",

    -- ====================================================================
    -- Trade
    -- ====================================================================
    ["продам"]="WTS", ["куплю"]="WTB", ["меняю"]="WTT",
    ["цена"]="price", ["цены"]="prices", ["торг"]="haggling",
    ["дешево"]="cheap", ["дорого"]="expensive",
    ["стак"]="stack", ["стака"]="stack",
    ["голд"]="gold", ["г"]="g", ["сильв"]="silver", ["медь"]="copper",
    ["бабки"]="money", ["бабок"]="money",
    ["аук"]="AH", ["аукцион"]="auction",
    ["чарки"]="enchants", ["чар"]="enchant", ["чара"]="enchant", ["чанта"]="enchant",
    ["чантера"]="enchanter", ["чантер"]="enchanter",
    ["зачаровывание"]="enchanting",
    ["прицел"]="scope",
    ["крит"]="crit", ["крита"]="crit", ["крита"]="crit", ["крит"]="crit",
    ["ловкость"]="agility", ["ловкости"]="agility", ["лвк"]="agi",
    ["сила"]="strength", ["стр"]="str",
    ["интеллект"]="intellect", ["инт"]="int", ["инты"]="int",
    ["стамина"]="stamina", ["стам"]="stam",
    ["дух"]="spirit", ["спирит"]="spirit",

    -- ====================================================================
    -- Group / activity types
    -- ====================================================================
    ["рейд"]="raid", ["рейда"]="raid", ["рейды"]="raids",
    ["пати"]="party",
    ["пвп"]="PvP", ["пве"]="PvE",
    ["бг"]="BG", ["бгшка"]="BG",
    ["арена"]="arena", ["арену"]="arena", ["аренку"]="arena", ["арены"]="arenas",
    ["рейтинг"]="rating", ["рейт"]="rating",
    ["рандом"]="pug", ["ренд"]="pug",
    ["гильдия"]="guild", ["гилда"]="guild", ["гильд"]="guild", ["гильдии"]="guild", ["гильдию"]="guild",
    ["гильдию"]="guild",
    ["хс"]="Hyjal Summit",      -- raid context; overrides nothing here (no dup)
    ["хк"]="heroic",
    ["героик"]="heroic", ["героика"]="heroic", ["героики"]="heroics", ["героиков"]="heroics",
    ["нормал"]="normal", ["об"]="(normal)", ["обычный"]="normal",
    ["дейли"]="daily", ["дейлики"]="dailies",
    ["квест"]="quest", ["квеста"]="quest", ["квесты"]="quests",
    ["кв"]="quest", ["квес"]="quest",
    ["статик"]="static group", ["статика"]="static", ["мейн"]="main",
    ["рег"]="reg",
    ["набор"]="recruiting",
    ["игроков"]="players", ["игрок"]="player", ["игроки"]="players", ["игров"]="players",
    ["активных"]="active", ["активный"]="active", ["активные"]="active",
    ["реалм"]="realm", ["реалма"]="realm", ["реалму"]="realm", ["реалмы"]="realms",
    ["сервер"]="server", ["серв"]="server", ["сервера"]="server", ["серверу"]="server",

    -- ====================================================================
    -- Chat idioms / greetings
    -- ====================================================================
    ["привет"]="hi", ["прив"]="hi", ["здарова"]="hey", ["хай"]="hi",
    ["пока"]="bye", ["покеда"]="bye", ["чао"]="ciao",
    ["спс"]="thx", ["спасибо"]="thanks", ["сенкс"]="thanks",
    ["пж"]="pls", ["пжл"]="pls", ["плз"]="pls", ["пожалуйста"]="please",
    ["лол"]="lol", ["кек"]="kek", ["кекв"]="kek",
    ["ахахах"]="hahaha", ["ахахаха"]="hahaha", ["ахах"]="haha", ["хахах"]="hahaha",
    ["норм"]="ok", ["нормально"]="fine",
    ["ок"]="ok", ["океюшки"]="ok",
    ["понял"]="got it", ["понятно"]="got it", ["ясно"]="clear",
    ["согласен"]="agree", ["точно"]="for sure", ["точно!"]="exactly",
    ["вроде"]="seems like",
    ["итд"]="etc",
    ["омг"]="omg",

    -- ====================================================================
    -- Common short words
    -- ====================================================================
    ["кто"]="who", ["кт"]="who",
    ["где"]="where", ["куда"]="where to", ["откуда"]="from where",
    ["когда"]="when", ["сегодня"]="today", ["завтра"]="tomorrow", ["вчера"]="yesterday",
    ["как"]="how", ["почему"]="why", ["зачем"]="why",
    ["что"]="what", ["чё"]="what", ["чо"]="what", ["что-то"]="something",
    ["есть"]="is/any",
    ["нет"]="no", ["нету"]="none",
    ["да"]="yes",
    ["не"]="not",
    ["ни"]="neither",
    ["и"]="and",
    ["или"]="or",
    ["но"]="but",
    ["а"]="but",
    ["же"]="though",
    ["уже"]="already",
    ["если"]="if",
    ["то"]="then",
    ["так"]="so", ["такой"]="such", ["такие"]="such",
    ["тут"]="here", ["здесь"]="here", ["сюда"]="here",
    ["там"]="there", ["туда"]="there",
    ["везде"]="everywhere",
    ["только"]="only", ["тоже"]="also", ["также"]="also",
    ["много"]="many", ["мало"]="few", ["все"]="all", ["всё"]="everything",
    ["всегда"]="always", ["никогда"]="never",
    ["ну"]="well",
    ["еще"]="still", ["ещё"]="still", ["пока"]="bye",
    ["почти"]="almost",
    ["около"]="about",
    ["реально"]="really", ["правда"]="really",
    ["возможно"]="maybe", ["может"]="maybe", ["мб"]="maybe",
    ["наверное"]="probably",
    ["конечно"]="of course", ["конешно"]="of course",
    ["жаль"]="shame", ["жаль"]="pity",
    ["хорошо"]="good", ["хороший"]="good", ["хорошее"]="good", ["хорошая"]="good",
    ["плохо"]="bad", ["плохой"]="bad",
    ["нормально"]="ok",
    ["некий"]="some", ["какой-то"]="some", ["какая-то"]="some",
    ["какие"]="what", ["какой"]="what", ["какая"]="what",
    ["другой"]="another", ["другое"]="other", ["другие"]="others",
    ["первый"]="first", ["последний"]="last", ["последние"]="last",
    ["новый"]="new", ["старый"]="old",
    ["большой"]="big", ["маленький"]="small",
    ["лучше"]="better", ["хуже"]="worse",
    ["быстрее"]="faster", ["быстрей"]="faster",
    ["медленней"]="slower",
    ["больше"]="more", ["меньше"]="less",
    ["ни"]="neither", ["ничего"]="nothing", ["никто"]="nobody",

    -- ====================================================================
    -- Pronouns
    -- ====================================================================
    ["я"]="I",
    ["ты"]="you",
    ["он"]="he", ["она"]="she", ["оно"]="it",
    ["мы"]="we", ["вы"]="you", ["они"]="they",
    ["мне"]="me", ["тебе"]="you", ["ему"]="him", ["ей"]="her", ["нам"]="us", ["вам"]="you", ["им"]="them",
    ["меня"]="me", ["тебя"]="you", ["его"]="him", ["её"]="her", ["нас"]="us", ["их"]="them",
    ["мой"]="my", ["моя"]="my", ["моё"]="my", ["мои"]="my",
    ["твой"]="your", ["твоя"]="your", ["твоё"]="your", ["твои"]="your",
    ["наш"]="our", ["ваш"]="your", ["ихний"]="their",
    ["этот"]="this", ["эта"]="this", ["это"]="this", ["эти"]="these",
    ["тот"]="that", ["та"]="that", ["те"]="those",
    ["себя"]="self", ["сам"]="self",

    -- ====================================================================
    -- Prepositions
    -- ====================================================================
    ["в"]="in", ["во"]="in",
    ["на"]="on/for",
    ["с"]="with", ["со"]="with",
    ["у"]="at",
    ["без"]="without",
    ["для"]="for",
    ["из"]="from",
    ["к"]="to",
    ["по"]="along/via",
    ["от"]="from",
    ["до"]="until",
    ["через"]="through/in",
    ["после"]="after", ["перед"]="before", ["при"]="at",
    ["над"]="over", ["под"]="under",
    ["про"]="about", ["о"]="about", ["об"]="(normal)",  -- "об" in LFG = обычный / normal mode
    ["за"]="Zul'Aman",  -- overloaded with preposition "за" — Zul'Aman wins in TBC LFG chat
    ["около"]="near",
    ["между"]="between",

    -- ====================================================================
    -- Numbers & time
    -- ====================================================================
    ["один"]="one", ["два"]="two", ["три"]="three", ["четыре"]="four", ["пять"]="five",
    ["шесть"]="six", ["семь"]="seven", ["восемь"]="eight", ["девять"]="nine", ["десять"]="ten",
    ["двадцать"]="20", ["тридцать"]="30", ["сорок"]="40", ["пятьдесят"]="50",
    ["сто"]="100", ["тысяча"]="1000", ["тыща"]="1k",
    ["щас"]="now", ["сейчас"]="now",
    ["теперь"]="now",
    ["скоро"]="soon", ["потом"]="later", ["уже"]="already", ["недавно"]="recently",
    ["сек"]="sec", ["секунду"]="one sec", ["секунд"]="sec",
    ["минут"]="min", ["минута"]="minute", ["минуту"]="a minute", ["минуты"]="minutes",
    ["час"]="hour", ["часа"]="hours", ["часов"]="hours",
    ["день"]="day", ["дня"]="day", ["дней"]="days",
    ["неделя"]="week", ["месяц"]="month", ["год"]="year",
    ["утро"]="morning", ["утром"]="in the morning",
    ["день"]="day", ["днём"]="during the day",
    ["вечер"]="evening", ["вечером"]="in the evening", ["вечерами"]="in the evenings",
    ["ночь"]="night", ["ночью"]="at night",
    ["лвл"]="lvl", ["левел"]="lvl", ["уровень"]="level", ["уровня"]="lvl",
    ["мск"]="MSK", ["по мск"]="by MSK",
    ["рт"]="RT",

    -- ====================================================================
    -- Loot / gear / stats
    -- ====================================================================
    ["шмот"]="gear", ["шмота"]="gear", ["шмотки"]="gear",
    ["лут"]="loot", ["лута"]="loot",
    ["дроп"]="drop", ["дропа"]="drop", ["дропнуть"]="drop",
    ["плащ"]="cloak", ["плаща"]="cloak",
    ["перчи"]="gloves", ["наплечи"]="shoulders",
    ["оружие"]="weapon", ["оружия"]="weapons",
    ["кольцо"]="ring", ["кольца"]="rings",
    ["палка"]="staff", ["палку"]="staff",
    ["щит"]="shield",
    ["броня"]="armor", ["брони"]="armor",
    ["ачивка"]="achievement", ["ачивки"]="achievements", ["ача"]="achievement",
    ["репа"]="rep", ["репутация"]="reputation",
    ["сет"]="set",
    ["эпик"]="epic", ["эпика"]="epic", ["эпики"]="epics",
    ["синька"]="blue", ["зеленка"]="green", ["грин"]="green", ["блю"]="blue",
    ["книга"]="book", ["книге"]="book", ["книги"]="books",
    ["макросы"]="macros", ["макрос"]="macro",

    -- ====================================================================
    -- PvP / combat
    -- ====================================================================
    ["ганк"]="gank", ["ганка"]="gank", ["ганкать"]="gank",
    ["убить"]="kill", ["убей"]="kill",
    ["кил"]="kill", ["килл"]="kill",
    ["стан"]="stun", ["стана"]="stun",
    ["мут"]="mute",
    ["бан"]="ban", ["банан"]="ban",
    ["тикет"]="ticket",
    ["скрин"]="screenshot",
    ["сейв"]="save", ["сейва"]="save",
    ["вайп"]="wipe",
    ["пулл"]="pull",
    ["агро"]="aggro",
    ["дот"]="DoT", ["дотка"]="DoT", ["хот"]="HoT",
    ["бафф"]="buff", ["баф"]="buff", ["дебаф"]="debuff",
    ["хонор"]="honor", ["чести"]="honor",
    ["орды"]="horde", ["ордынский"]="horde", ["ордынские"]="horde",
    ["альянс"]="alliance", ["альянса"]="alliance", ["альянсовский"]="alliance",
    ["альянсовскую"]="alliance", ["альянсовские"]="alliance",
    ["пал"]="paladin", -- dup ok

    -- ====================================================================
    -- Slang / expressions
    -- ====================================================================
    ["бугров"]="big shots", ["бугры"]="big shots",
    ["удержать"]="retain", ["удерживать"]="to retain",
    ["качаются"]="leveling", ["качаться"]="to level", ["качает"]="levels",
    ["качнуть"]="to level", ["качнулся"]="leveled",
    ["подучас"]="will learn", ["подучат"]="will learn",
    ["выучишь"]="you'll learn", ["выучить"]="to learn", ["учить"]="to learn",
    ["скорей"]="sooner",
    ["исход"]="outcome",
    ["избежен"]="unavoidable",
    ["фантазии"]="fantasies",
    ["меньшенстве"]="minority", ["меньшинстве"]="minority",
    ["воспринимай"]="perceive",
    ["реальность"]="reality",
    ["иллюзий"]="illusions",
    ["популярен"]="popular",
    ["получается"]="apparently",
    ["плакса"]="crybaby",
    ["нытик"]="whiner",
    ["шиза"]="paranoia",
    ["мусорнулся"]="got trashed",
    ["скучно"]="boring",
    ["ппц"]="damn",
    ["бля"]="damn",
    ["блин"]="damn",
    ["чёт"]="kinda", ["чет"]="kinda",
    ["типо"]="like", ["типа"]="like",
    ["свалили"]="bailed", ["свалил"]="bailed",
    ["насрать"]="don't care", ["пофиг"]="whatever",
    ["ласты"]="flippers", ["склею"]="stick",
    ["хороший"]="good", ["хорошая"]="good",
    ["друзья"]="friends", ["ребята"]="guys", ["ребят"]="guys",
    ["народ"]="folks",
    ["боты"]="bots", ["бот"]="bot",
    ["боя"]="of fight", ["бой"]="fight",
    ["видеть"]="see", ["вижу"]="I see",
    ["пишу"]="I write", ["пишет"]="writes", ["пишут"]="write",
    ["думаю"]="I think", ["думал"]="thought", ["подумал"]="thought",
    ["знаю"]="know", ["не знаю"]="dunno",
    ["помогу"]="will help", ["помоги"]="help", ["поможет"]="will help",
    ["собираю"]="gathering", ["собирал"]="was gathering",
    ["молча"]="silently",
    ["увидел"]="saw",
    ["написали"]="wrote",
    ["прощальные"]="farewell",
    ["посты"]="posts",
    ["конец"]="end",
    ["лутбокс"]="lootbox",
    ["голосование"]="voting",
    ["самоудаляется"]="self-deletes",
    ["почта"]="mail", ["почте"]="mail",
    ["лежит"]="lies",
    ["разве"]="really?",
    ["жилаюшие"]="willing", ["желающие"]="willing",
    ["кросфакс"]="crossfaction", ["кроссфакс"]="crossfaction",
    ["фаза"]="phase", ["фазе"]="phase", ["фазы"]="phases",
    ["сторм"]="Storm (server)",
    ["мунка"]="Moonwell (server)",
    ["мунвелл"]="Moonwell",
    ["незервинг"]="Netherwing (server)",
    ["незера"]="Netherwing",
    ["печать"]="seal", ["печати"]="seal",
    ["заплатки"]="armor patches",
    ["ставятся"]="are placed", ["ставится"]="is placed",
    ["ступень"]="level",
    ["классики"]="classic",
    ["долго"]="long",
    ["онлайн"]="online",
    ["оффлайн"]="offline",
    ["чел"]="dude", ["человек"]="person", ["люди"]="people",
    ["админ"]="admin", ["админа"]="admin", ["администрация"]="admin",
    ["гм"]="GM",
    ["пм"]="PM",
    ["тп"]="teleport",
    ["призвать"]="summon", ["призви"]="summon", ["призов"]="summons",
    ["камню"]="stone (summoning)",
    ["камень"]="stone",
    ["нихуя"]="nothing (vulgar)",
    ["заебало"]="fed up (vulgar)",
    ["пиздак"]="(vulgar)",
    ["пиздабол"]="bullshitter (vulgar)",
    ["пиздешь"]="bullshit (vulgar)",
    ["кортавый"]="lisping (insult)",
    ["свинорылый"]="swine-faced (insult)",
    ["удачи"]="good luck",
    ["окон"]="windows", ["окно"]="window",
    ["увидеть"]="to see", ["увидишь"]="you'll see",
    ["сводить"]="to lead/take",
    ["некроситет"]="Necropolis/crypts",

    -- ====================================================================
    -- Verb forms & misc
    -- ====================================================================
    ["делай"]="do",
    ["сделать"]="to do", ["сделали"]="did",
    ["сделал"]="did", ["сделала"]="did",
    ["убрали"]="removed",
    ["поднятся"]="will rise", ["подняться"]="to rise",
    ["покупать"]="to buy", ["купить"]="to buy",
    ["продавать"]="to sell", ["продать"]="to sell",
    ["помогать"]="to help", ["поможет"]="will help",
    ["дать"]="to give", ["давать"]="to give", ["даёт"]="gives", ["дают"]="give",
    ["стянуть"]="to pull off", ["стяни"]="pull off",
    ["тянуть"]="to pull", ["тяну"]="I pull",
    ["идти"]="to go", ["иду"]="I'm going", ["идут"]="are going",
    ["сходить"]="to go", ["ходить"]="to walk",
    ["работать"]="to work", ["работает"]="works",
    ["пить"]="to drink", ["пиву"]="to beer",
    ["собака"]="dog",

    -- ====================================================================
    -- Location words
    -- ====================================================================
    ["город"]="city", ["города"]="cities",
    ["локация"]="zone", ["локи"]="warlocks",  -- beware: локи also = locations locally
    ["данж"]="dungeon", ["данжа"]="dungeon", ["данжи"]="dungeons",
    ["подземелье"]="dungeon", ["подземелья"]="dungeons",
    ["башня"]="tower",
    ["замок"]="castle",
    ["храм"]="temple",
    ["сердце"]="heart", ["сердца"]="heart",
    ["душ"]="souls", ["души"]="souls", ["душа"]="soul",
    ["имен"]="names",
    ["скверны"]="Fel",
    ["имя"]="name",
}

-- Prebuilt list of phrase keys sorted by length descending (byte length).
-- Core.lua uses this so the longest phrase wins (greedy match).
ns.PHRASE_ORDER = {}
for k in pairs(ns.PHRASES) do
    table.insert(ns.PHRASE_ORDER, k)
end
table.sort(ns.PHRASE_ORDER, function(a, b) return #a > #b end)
