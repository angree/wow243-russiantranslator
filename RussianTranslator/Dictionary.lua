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

ns.CYR_LOWER = {
    ["А"]="а",["Б"]="б",["В"]="в",["Г"]="г",["Д"]="д",["Е"]="е",["Ё"]="ё",
    ["Ж"]="ж",["З"]="з",["И"]="и",["Й"]="й",["К"]="к",["Л"]="л",["М"]="м",
    ["Н"]="н",["О"]="о",["П"]="п",["Р"]="р",["С"]="с",["Т"]="т",["У"]="у",
    ["Ф"]="ф",["Х"]="х",["Ц"]="ц",["Ч"]="ч",["Ш"]="ш",["Щ"]="щ",["Ъ"]="ъ",
    ["Ы"]="ы",["Ь"]="ь",["Э"]="э",["Ю"]="ю",["Я"]="я",
}

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
-- Scanned longest-first at runtime via ns.PHRASE_ORDER.
-- Keys lowercase UTF-8. Values English.
-- ---------------------------------------------------------------------------
ns.PHRASES = {
    -- Guild recruitment idioms
    ["пве гильдия"]="PvE guild", ["пвп гильдия"]="PvP guild",
    ["ведет набор активных игроков"]="recruiting active players",
    ["ведет набор игроков"]="recruiting players",
    ["ведет набор"]="recruiting",
    ["набор активных игроков"]="recruiting active players",
    ["в мейн статик"]="for the main raid roster",
    ["мейн статик"]="main raid roster",
    ["основной состав"]="main roster",
    ["глава гильдии"]="guild leader",
    ["лист ожидания"]="wait list",

    -- LFG / LFM
    ["есть кто на"]="anyone for", ["есть кто в"]="anyone in", ["есть кто"]="anyone here for",
    ["кто на"]="anyone for", ["кто в"]="anyone in",
    ["ищу группу"]="LFG", ["ищу пати"]="LFG",
    ["ищу ренд"]="LFG pug", ["ищу рандом"]="LFG pug",
    ["ищу героик"]="LF heroic", ["ищу хил"]="LF healer", ["ищу хила"]="LF healer",
    ["ищу чантера"]="LF enchanter", ["ищу чара"]="LF enchanter",
    ["ищем хила"]="LF healer", ["ищем танка"]="LF tank", ["ищем дд"]="LF dps",
    ["есть героики"]="any heroics", ["есть героик"]="any heroic",
    ["собираю пати"]="forming party", ["собираю ренд"]="forming pug",
    ["собираю рампы"]="forming Ramparts",
    ["нид все"]="need everyone", ["нид танк"]="need tank", ["нид хил"]="need healer",
    ["нид хилл"]="need healer", ["нид дд"]="need dps",
    ["нид 1дд"]="need 1 dps", ["нид 2дд"]="need 2 dps", ["нид 3дд"]="need 3 dps",
    ["нид хил дд"]="need healer dps", ["нид танк хил"]="need tank healer",
    ["нужен хил"]="need healer", ["нужен танк"]="need tank", ["нужен дд"]="need dps",
    ["нужна пара дд"]="need 2 dps",
    ["пара дд"]="2 dps", ["хил дд"]="healer + dps", ["хил пара дд"]="healer + 2 dps",
    ["хил и дд"]="healer and dps", ["танк и хил"]="tank and healer",
    ["танк хил дд"]="tank healer dps",
    ["осталось 1"]="need 1 more", ["осталось 2"]="need 2 more",
    ["последнее место"]="last spot", ["есть место"]="spot open", ["нет места"]="no spot",
    ["добор"]="need 1 more to fill",

    -- Arena / PvP
    ["рег аренку"]="reg arena", ["рег 2х2"]="reg 2v2", ["рег 3х3"]="reg 3v3", ["рег 5х5"]="reg 5v5",
    ["рег 2на2"]="reg 2v2", ["рег 3на3"]="reg 3v3",
    ["стартую аренку"]="starting arena", ["стартуем аренку"]="starting arena",
    ["очки арены"]="arena points", ["знаки чести"]="honor marks",
    ["очки чести"]="honor points", ["личный рейт"]="personal rating",
    ["командный рейт"]="team rating",

    -- Instances, full Russian → English
    ["громовой утес"]="Thunder Bluff", ["громовый утес"]="Thunder Bluff", ["громовой утёс"]="Thunder Bluff",
    ["огненная пропасть"]="Ragefire Chasm", ["огненую пропасть"]="Ragefire Chasm",
    ["огненой пропасти"]="Ragefire Chasm",
    ["пекло крови"]="Blood Furnace",
    ["кровавая топь"]="Blood Furnace",
    ["рампы об"]="Ramparts (normal)", ["рампы хс"]="Ramparts (heroic)",
    ["бф об"]="Blood Furnace (normal)", ["бф хс"]="Blood Furnace (heroic)",
    ["шх хс"]="Shattered Halls (heroic)", ["шх об"]="Shattered Halls (normal)",
    ["шм хс"]="Shadow Labs (heroic)", ["шм об"]="Shadow Labs (normal)",
    ["гробница маны"]="Mana-Tombs",
    ["палаты стазиса"]="Stasis Chambers",
    ["склепы аукенай"]="Auchenai Crypts",
    ["сетеки нормал"]="Sethekk Halls (normal)",
    ["сетеки хс"]="Sethekk Halls (heroic)", ["сетеки хк"]="Sethekk Halls (heroic)",
    ["паровое подземелье"]="Steamvault",
    ["загон для рабов"]="Slave Pens",
    ["логово змея"]="Serpentshrine Cavern",
    ["око бури"]="Tempest Keep", ["крепость бурь"]="Tempest Keep", ["штормовая крепость"]="Tempest Keep",
    ["чёрный храм"]="Black Temple", ["черный храм"]="Black Temple",
    ["терраса магистров"]="Magisters' Terrace",
    ["логово груула"]="Gruul's Lair",
    ["гора хиджал"]="Mount Hyjal", ["хиджал саммит"]="Hyjal Summit",
    ["пещеры времени"]="Caverns of Time",
    ["восточные королевства"]="Eastern Kingdoms",
    ["тёмные земли"]="Shadowmoon Valley",
    ["лес тероккар"]="Terokkar Forest",
    ["полуостров адского пламени"]="Hellfire Peninsula",

    -- Quest names in log
    ["в сердце разрушителя душ"]="Heart of the Soul-Destroyer (quest)",
    ["разрушителя душ"]="Soul-Destroyer",
    ["книга имен скверны"]="Book of Fel Names (quest)", ["имен скверны"]="Fel Names",
    ["погибли при исполнении"]="Died in the Line of Duty (quest)",
    ["ослабить оборону валов"]="Weaken the Ramparts (quest)",

    -- Trade
    ["куплю много"]="WTB many", ["продам дешево"]="WTS cheap", ["продам дёшево"]="WTS cheap",
    ["куплю прицел"]="WTB scope",
    ["в пм"]="in PM", ["пиши в пм"]="whisper me", ["пиши личкой"]="whisper me",
    ["в личку"]="in PM", ["в лс"]="in PM",
    ["торг уместен"]="negotiable", ["торга нет"]="non-negotiable",
    ["цена договорная"]="price negotiable",
    ["со скидкой"]="discounted", ["без торга"]="no haggling",
    ["кинь голд"]="send gold", ["кинь деньги"]="send money",
    ["махнёмся"]="swap",

    -- Greetings / closers / thanks
    ["всем привет"]="hi all", ["всем пока"]="bye all", ["всем удачи"]="gl all",
    ["всем спс"]="thx all", ["спасибо всем"]="thanks all", ["спс всем"]="thx all",
    ["доброго дня"]="good day", ["добрый день"]="good day",
    ["добрый вечер"]="good evening", ["доброе утро"]="good morning",
    ["спокойной ночи"]="good night", ["как дела"]="how are you",
    ["как жизнь"]="how's life", ["как оно"]="how's it", ["как сам"]="how you",
    ["что такое"]="what is", ["что это"]="what's this",
    ["что делать"]="what to do", ["что делаешь"]="what you doing",
    ["где ты"]="where are you", ["куда ты"]="where to", ["откуда ты"]="where from",

    -- Common requests
    ["дай инв"]="gimme inv", ["кинь инв"]="gimme inv", ["инв пж"]="inv pls",
    ["дай тп"]="give me a port", ["тп дать"]="give a port", ["портни в город"]="port to city",
    ["открой портал"]="open portal", ["портал в"]="portal to",
    ["призвать по камню"]="summon me via stone", ["призват по камню"]="summon me via stone",
    ["по камню призвать"]="summon via stone",
    ["камень призыва"]="summoning stone", ["замок призыва"]="summoning stone",
    ["закинь в инст"]="summon to instance",
    ["держи в курсе"]="keep me updated", ["не в курсе"]="not in the loop",
    ["в курсе"]="in the loop",
    ["я так понимаю"]="as I understand",
    ["на этом сервере"]="on this server", ["на форуме"]="on the forum",
    ["в дискорде"]="on discord",
    ["тикет бан"]="ticket ban", ["скрин тикет"]="screenshot + ticket",
    ["на сайте"]="on the site",
    ["прощальные посты"]="farewell posts",
    ["реалму конец"]="realm is done", ["реалм умер"]="realm is dead",
    ["хороший реалм"]="good realm",
    ["ни бг ни героиков"]="neither BG nor heroics", ["ни бг"]="no BGs",
    ["нет конешно"]="of course not", ["нет конечно"]="of course not",
    ["конечно нет"]="of course not", ["конешно нет"]="of course not",
    ["1 человек"]="one person", ["один человек"]="one person",
    ["на русском"]="in Russian", ["было бы понятнее"]="would be clearer",
    ["последние слова"]="last words",
    ["жаль конечно"]="shame of course",
    ["по кв"]="for quest", ["на кв"]="for quest",
    ["кто нибудь"]="anyone", ["кто-нибудь"]="anyone",
    ["что-нибудь"]="something",
    ["на плащ"]="on cloak", ["на оружие"]="on weapon", ["на перчи"]="on gloves",
    ["на грудь"]="on chest", ["на кольцо"]="on ring", ["на палку"]="on staff",
    ["на 2 руки"]="on 2-handed", ["к пиву"]="to beer",
    ["чем быстрей тем лучше"]="faster the better",

    -- Raid progress shorthand
    ["хс 5/5"]="Hyjal 5/5", ["хс 4/5"]="Hyjal 4/5", ["хс 3/5"]="Hyjal 3/5",
    ["бт 9/9"]="BT 9/9 (cleared)", ["бт 8/9"]="BT 8/9", ["бт 7/9"]="BT 7/9",
    ["бт 6/9"]="BT 6/9", ["бт 5/9"]="BT 5/9",
    ["ссц 6/6"]="SSC 6/6", ["ссц 5/6"]="SSC 5/6",
    ["тк 4/4"]="TK 4/4", ["тк 3/4"]="TK 3/4",
    ["кара 11/11"]="Karazhan 11/11",

    -- "Go <place>"
    ["го кара"]="let's go Karazhan", ["го бт"]="let's go Black Temple",
    ["го за"]="let's go Zul'Aman", ["го зуль"]="let's go Zul'Aman",
    ["го груул"]="let's go Gruul", ["го маг"]="let's go Magtheridon",
    ["го ссц"]="let's go Serpentshrine", ["го тк"]="let's go Tempest Keep",
    ["го мгт"]="let's go Magisters' Terrace", ["го хиджал"]="let's go Hyjal",
    ["го шм"]="let's go Shadow Labs", ["го шх"]="let's go Shattered Halls",
    ["го бф"]="let's go Blood Furnace", ["го рфс"]="let's go Ragefire",
    ["го сфк"]="let's go Shadowfang Keep", ["го рампы"]="let's go Ramparts",
    ["го арену"]="let's go arena", ["го аренку"]="let's go arena",
    ["го бг"]="let's go BG", ["го дейлики"]="let's go dailies", ["го дейли"]="let's go daily",

    -- "Anyone for X"
    ["кто на кару"]="anyone for Karazhan", ["кто на бт"]="anyone for Black Temple",
    ["кто на за"]="anyone for Zul'Aman", ["кто на ссц"]="anyone for Serpentshrine",
    ["кто на тк"]="anyone for Tempest Keep", ["кто на мгт"]="anyone for Magisters' Terrace",
    ["кто на бг"]="anyone for BG", ["кто на арену"]="anyone for arena",
    ["кто на аренку"]="anyone for arena", ["кто на хс"]="anyone for heroic",
    ["кто на рампы"]="anyone for Ramparts",
    ["кто в кару"]="anyone in Karazhan", ["кто в бт"]="anyone in Black Temple",

    -- Premium / paid / shop
    ["премиум аккаунт"]="premium account", ["прем акк"]="premium account",
    ["прем аккаунт"]="premium account",

    -- Common chat phrases & emotions
    ["ппц скучно"]="damn boring", ["очень нужно"]="really need",
    ["в натуре"]="for real", ["по-любому"]="definitely", ["по любасу"]="for sure",
    ["без базара"]="no doubt", ["без вопросов"]="no questions",
    ["без проблем"]="no problem",
    ["всё ок"]="all good", ["всё норм"]="all good", ["всё пучком"]="all good",
    ["не парься"]="chill", ["не парьтесь"]="chill", ["не гони"]="slow down",
    ["чё как"]="what's up", ["чё там"]="what's there", ["чё за"]="what's this",
    ["да ладно"]="no way", ["ну и ладно"]="whatever", ["ну ладно"]="okay then",
    ["ну да"]="yeah right", ["ну нет"]="nope", ["ну всё"]="that's it",
    ["ну что"]="so what", ["ну и что"]="so what", ["и что"]="so what",
    ["ни в коем случае"]="no way", ["ни за что"]="no way",
    ["на самом деле"]="actually", ["по ходу"]="seems like", ["походу"]="seems like",
    ["в принципе"]="basically", ["в общем"]="in general", ["если что"]="if anything",
    ["на всякий"]="just in case", ["в случае чего"]="just in case",
    ["по правде"]="truthfully", ["честно говоря"]="honestly",
    ["не шутя"]="seriously", ["без шуток"]="no joke",
    ["вот так"]="like this", ["вот так-то"]="there you go",
    ["да уж"]="well well", ["ну вот"]="well",
    ["нифига себе"]="wow", ["ни фига себе"]="wow", ["вот это да"]="wow",
    ["ничего себе"]="wow", ["надо же"]="wow", ["подумать только"]="imagine that",

    -- Time phrases
    ["через пять минут"]="in 5 minutes", ["через пару минут"]="in a few minutes",
    ["через полчаса"]="in half an hour", ["через час"]="in an hour",
    ["через минуту"]="in a minute", ["через секунду"]="in a second",
    ["сейчас буду"]="coming now", ["скоро буду"]="coming soon",
    ["уже иду"]="on my way", ["буду позже"]="be later", ["не сейчас"]="not now",
    ["как освобожусь"]="when free", ["скоро освобожусь"]="free soon",
    ["после работы"]="after work", ["после пары"]="after class",
    ["сегодня вечером"]="tonight", ["в субботу"]="on Saturday",
    ["в воскресенье"]="on Sunday", ["в пятницу"]="on Friday",
    ["на выходных"]="on weekend",

    -- Raid call-outs
    ["не стой в огне"]="move out of fire", ["не стойте"]="don't stand",
    ["сменить цель"]="switch target", ["фокус огонь"]="focus fire",
    ["расставь тотемы"]="drop totems", ["поставь метку"]="place mark",
    ["готовность чек"]="ready check", ["ставь чек"]="ready check",
    ["подожди пулл"]="wait for pull", ["не пулль"]="don't pull",
    ["молния цепью"]="chain lightning", ["цепная молния"]="chain lightning",
    ["огненный шар"]="fireball", ["взрыв льда"]="frostbolt",
    ["ледяная стрела"]="ice lance", ["ледяная глыба"]="ice block",
    ["мановый щит"]="mana shield", ["волшебный интеллект"]="arcane intellect",
    ["омоложение"]="rejuv", ["быстрое исцеление"]="flash heal",
    ["мощное исцеление"]="greater heal", ["молитва исцеления"]="prayer of healing",
    ["длань защиты"]="hand of protection", ["длань свободы"]="hand of freedom",
    ["длань жертвы"]="hand of sacrifice",
    ["благо силы"]="blessing of might", ["благо мудрости"]="blessing of wisdom",
    ["благо королей"]="blessing of kings", ["благо спасения"]="blessing of salvation",
    ["печать крови"]="seal of blood", ["стрела тьмы"]="shadow bolt",
    ["дождь огня"]="rain of fire", ["хаотическая стрела"]="chaos bolt",
    ["боевой клич"]="battle shout", ["командный крик"]="commanding shout",
    ["клинок бури"]="bladestorm", ["смертельный удар"]="mortal strike",
    ["героический удар"]="heroic strike", ["ледяная ловушка"]="freezing trap",
    ["замораживающая ловушка"]="freezing trap", ["прицельный выстрел"]="aimed shot",
    ["разящий выстрел"]="aimed shot", ["меткий выстрел"]="steady shot",
    ["удар духа"]="lifebloom", ["цветение жизни"]="lifebloom",
    ["звёздный огонь"]="starfire", ["исцеляющее прикосновение"]="healing touch",
    ["волна исцеления"]="healing wave", ["меньшая волна"]="lesser healing wave",
    ["цепное исцеление"]="chain heal", ["удар в спину"]="backstab",
    ["подлый удар"]="sinister strike",
    ["массовый страх"]="howl of terror", ["вой ужаса"]="howl of terror",
    ["проклятие слабости"]="curse of weakness", ["проклятие элементов"]="curse of elements",
    ["проклятие языков"]="curse of tongues",

    -- Phases
    ["первая фаза"]="phase 1", ["вторая фаза"]="phase 2", ["третья фаза"]="phase 3",
    ["фаза один"]="phase 1", ["фаза два"]="phase 2", ["фаза три"]="phase 3",

    -- Ready / rez / positions
    ["ресни меня"]="rez me", ["рескни меня"]="rez me", ["воскреси меня"]="rez me",
    ["беги к трупу"]="run to corpse", ["беги духом"]="run as ghost",
    ["готов к пуллу"]="ready to pull", ["на пулле"]="on pull", ["в бою"]="in combat",

    -- Gearscore/rating
    ["какой гс"]="what GS", ["с гс"]="with GS",

    -- Travel / flight
    ["мастер полётов"]="flight master", ["камень возвращения"]="hearthstone",

    -- RL misc
    ["реальная жизнь"]="real life", ["ушёл афк"]="went afk", ["пошёл спать"]="going to bed",
    ["настроения нет"]="no mood",

    -- =================================================================
    -- Log-005 additions — contextual phrases that fix bad word-by-word
    -- translations (e.g. "может" alone -> "maybe", but "кто может" -> "who can")
    -- =================================================================

    -- "может" disambiguation — verb "can" vs particle "maybe"
    ["кто может зачарить"]="who can enchant",
    ["кто может помочь"]="who can help",
    ["кто может сделать"]="who can make",
    ["кто может сводить"]="who can take me",
    ["кто может"]="who can",
    ["может помочь"]="can help",
    ["может сделать"]="can do",
    ["может зачарить"]="can enchant",
    ["может сводить"]="can lead",
    ["может быть"]="maybe",

    -- "с какого" / levels / druid bird
    ["с какого левела"]="from what level",
    ["с какого лвл"]="from what lvl",
    ["с какого уровня"]="from what level",
    ["какого левела"]="what level",
    ["какого лвл"]="what lvl",
    ["с какого"]="from what",
    ["у друида"]="for druid",
    ["у мага"]="for mage",
    ["у варика"]="for warrior",
    ["у шама"]="for shaman",
    ["у паля"]="for paladin",
    ["у прист"]="for priest",
    ["у ханта"]="for hunter",
    ["у лока"]="for warlock",
    ["птица у друида"]="druid flight form",
    ["птицу у друида"]="druid flight form",

    -- Guild "Дальний Восток" and recruitment phrases
    ["дальний восток"]="Far East",
    ["гильдия дальний восток"]="Far East guild",
    ["примет новых игроков"]="accepts new players",
    ["примет игроков"]="accepts players",
    ["новых игроков"]="new players",
    ["принимает новых"]="accepts new",

    -- Timezone / scheduling
    ["для тех у кого"]="for those with",
    ["у кого"]="who has",
    ["московского времени"]="Moscow time",
    ["от московского времени"]="from Moscow time",
    ["до московского времени"]="until Moscow time",
    ["по московскому"]="by Moscow time",
    ["мск время"]="MSK time",
    ["по мск"]="by MSK",

    -- Professional services wanted
    ["ищу напа"]="LF partner",
    ["ищу напарника"]="LF partner",
    ["ищу инженера"]="LF engineer",
    ["ищу ювелира"]="LF jeweler",
    ["ищу кожевника"]="LF leatherworker",
    ["ищу портного"]="LF tailor",
    ["ищу алхимика"]="LF alchemist",
    ["ищу кузнеца"]="LF blacksmith",
    ["ищу повара"]="LF cook",
    ["ищу начертателя"]="LF scribe",
    ["нужен инженер"]="need engineer",
    ["нужен ювелир"]="need jeweler",
    ["нужен алхимик"]="need alchemist",

    -- Scope / crit (numbers before крита/криты)
    ["прицел 28 крита"]="28-crit scope",
    ["прицел 28 криты"]="28-crit scope",
    ["28 крита"]="28 crit",
    ["28 криты"]="28 crit",

    -- Instance suffix variants
    ["паровое нормал"]="Steamvault (normal)",
    ["паровое норм"]="Steamvault (normal)",
    ["паровое хс"]="Steamvault (heroic)",
    ["паровое хк"]="Steamvault (heroic)",
    ["танк хил в паровое"]="tank healer in Steamvault",

    -- "сосать" complaints (vulgar losing slang)
    ["лол сосать"]="lol suck",
    ["сосать на"]="suck for",

    -- Crafting mat slang
    ["мой реги"]="my regs",
    ["мои реги"]="my regs",
    ["мой мат"]="my mats",
    ["мои маты"]="my mats",

    -- wtb with slash
    ["wtb/куплю"]="WTB",
    ["куплю/wtb"]="WTB",
    ["wts/продам"]="WTS",
    ["продам/wts"]="WTS",

    -- Boot enchant shorthand
    ["стамина+бег"]="stamina + run speed",
    ["стам+бег"]="stam + run speed",
    ["стамина и бег"]="stamina and run speed",
    ["ловкость+бег"]="agility + run speed",

    -- boty: disambiguate the "bots" sense so "boots" default stays
    ["боты пишут"]="bots write",
    ["все боты"]="all bots",
    ["все боты пишут"]="all bots write",
    ["нет все боты"]="no all bots",
    ["боты онлайн"]="bots online",
    ["боты везде"]="bots everywhere",

    -- Gaming / arena count
    ["10 игр"]="10 games",
    ["на 10 игр"]="for 10 games",
    ["на 5 игр"]="for 5 games",
    ["на 20 игр"]="for 20 games",
    ["100 игр"]="100 games",

    -- "Polze тут" style pings
    ["тут ?"]="here?",
    ["тут?"]="here?",

    -- A few more polite common patterns
    ["пиши в личку"]="whisper me",
    ["кто может пж"]="who can please",

    -- =================================================================
    -- Log-008 (live WoWChatLog.txt, 335 unique Russian lines)
    -- =================================================================

    -- Shadow Labs Russian shorthand: "Тем Лаб" = "Тёмный Лабиринт"
    ["тем лаб"]="Shadow Labs",
    ["тем лабиринт"]="Shadow Labs",
    ["тёмный лабиринт"]="Shadow Labs",
    ["темный лабиринт"]="Shadow Labs",
    ["тем лаб гер"]="Shadow Labs (heroic)",
    ["тем лаб нм"]="Shadow Labs (normal)",
    ["в тем лаб"]="to Shadow Labs",
    ["в тем лабе"]="in Shadow Labs",
    -- Shadow Labs bosses
    ["бормотун"]="Murmur (boss)",
    ["посланник тьмы"]="Blackheart the Inciter",
    -- Quest bosses / item names seen in log
    ["зулухед измученный"]="Zul'jin the Exhausted (quest)",
    ["зулухед"]="Zul'jin",
    ["измученный"]="Exhausted (quest adj)",
    ["гибель предателя"]="Death of the Betrayer (quest)",
    ["посох божественного вливания"]="Staff of Infusion",
    ["антикварный сундук"]="Antique Chest",
    ["стабилизированный этерниевый прицел"]="Stabilized Eternium Scope",
    ["этерниевый прицел"]="Eternium scope",
    ["рубашка нежити"]="Undead Shirt",
    -- Admin / warning boilerplate from GMs
    ["добрый вечер уважаемые игроки"]="Good evening, dear players",
    ["уважаемые игроки"]="dear players",
    ["за использование ненормативной лексики"]="for using profanity",
    ["ненормативной лексики"]="profanity",
    ["в глобальном чате"]="in global chat",
    ["будут выдаваться муты"]="mutes will be issued",
    ["как только вы научитесь"]="as soon as you learn",
    ["научитесь общаться"]="learn to communicate",
    ["общаться уважительно"]="communicate respectfully",
    ["я начну отвечать"]="I will start answering",
    ["отвечать на ваши вопросы"]="answer your questions",
    ["на ваши вопросы"]="your questions",
    ["уважаемая администрация"]="dear administration",
    ["гражданин начальник"]="citizen chief",
    ["поставленный вопрос"]="the question posed",
    ["ответьте на поставленный вопрос"]="answer the posed question",
    -- Honor / PvP chatter
    ["недельный кап"]="weekly cap",
    ["кап хонора"]="honor cap",
    ["кап чести"]="honor cap",
    ["какого хуя"]="what the fuck (vulgar)",
    ["какого хрена"]="what the hell",
    ["дальше не капает"]="stops capping",
    ["перестал начисляться"]="stopped accruing",
    ["так же как и"]="same as",
    -- Enchanting services
    ["чарю шмот"]="I enchant gear",
    ["за ваши реги"]="for your regs",
    ["чарю бесплатно"]="I enchant for free",
    ["наложение чар"]="enchant application",
    ["наложение чар free"]="enchant free",
    ["за пм"]="for whisper",
    -- Arena team shorthand seen in this log
    ["к вару в 2с"]="to warrior for 2v2",
    ["в 2с"]="in 2v2",
    ["в 3с"]="in 3v3",
    ["на 10 игр"]="for 10 games",
    ["ршам/хпал/рдру"]="Resto Sham/Holy Pal/Resto Druid",
    ["ршам хпал рдру"]="Resto Sham + Holy Pal + Resto Druid",
    -- Dungeon LFG patterns from Shadow Labs
    ["сумон к 3 босу"]="summon to boss 3",
    ["сумон к 3 бос"]="summon to boss 3",
    ["сумон сразу"]="summon right away",
    ["сумон к ласту"]="summon to last boss",
    ["к ласт слот"]="to the last slot",
    ["1 дд в"]="need 1 dps in",
    ["2 дд в"]="need 2 dps in",
    ["3 дд в"]="need 3 dps in",
    -- Other pragmatic sayings
    ["волшебное слово"]="magic word",
    ["волшебное слово забыл"]="forgot the magic word",
    ["регайте арену"]="reg arena",
    ["регайте арену пацаны"]="reg arena guys",
    ["еще 6 игр"]="6 more games",
    ["еще игр"]="more games",
    ["почисти кэш"]="clear cache",
    ["все чисто"]="all clean",
    ["на других сервах"]="on other servers",
    ["короли войны"]="Kings of War",  -- known guild name on Russian TBC
    ["победили босса"]="killed the boss",
    ["реально гильдия"]="really a guild",
    ["с таким названием"]="with such a name",
    ["вопрос не в этом"]="that's not the question",
    ["вопрос в том"]="the question is",
    ["я сам с собой"]="I'm talking to myself",
    ["сам с собой базарю"]="talking to myself",
    ["пойду водить"]="going to run",
    ["водить трала"]="run Thrall",  -- Orgrimmar NPC
    ["хил в кару"]="healer for Kara",
    ["хил в кару быстра"]="healer for Kara, fast",
    ["в кару 1 дпс"]="1 dps for Kara",
    ["ищем лока в тк"]="LF warlock for TK",
    ["с келя"]="with Kael'thas",
    ["лока в тк с келя"]="warlock for TK with Kael",
    -- Smoking comments from log
    ["какой нахуй"]="what the fuck",
    ["какой нахуй недельный"]="what fucking weekly",
    ["хонор стопарнулся"]="honor stuck",
    ["стопарнулся на"]="stuck at",
    -- Formal/technical chatter
    ["врятле пиздуй на форум"]="hardly — go post on the forum",
    ["пиздуй на форум"]="post on the forum (vulgar)",
    -- Guild recruit (new style seen)
    ["набор с 70 лвл"]="recruiting from lvl 70",
    ["с 70 лвл"]="from lvl 70",
    ["набор закрыт"]="recruitment closed",
    ["остальных набор закрыт"]="others recruitment closed",

    -- Phrase pattern: "Бота (норм) 1 ДД в пм"
    ["бота норм"]="Botanica (normal)",
    ["бота гер"]="Botanica (heroic)",

    -- Greetings / reactions in log
    ["добрый вечер"]="good evening",
    ["добрый день"]="good day",

    -- =================================================================
    -- Log-006 additions: difficulty slang, instance-specific idioms,
    -- attunements, quest names, item names, schedule lingo.
    -- =================================================================

    -- Heroic / normal / reserve slot phrases (extremely frequent on TBC)
    ["нужен танк хил дпс"]="need tank healer dps",
    ["нужен танк, хил"]="need tank, healer",
    ["нужен танк, хил, дпс"]="need tank, healer, dps",
    ["нужен танк хил"]="need tank healer",
    ["ласт слот"]="last slot",
    ["ласту слот"]="last slot",
    ["штаны рез"]="pants reserved",
    ["штаны резерв"]="pants reserved",
    ["штаны в рез"]="pants reserved",
    ["рез штаны"]="pants reserved",
    ["перчи рез"]="gloves reserved",
    ["плащ рез"]="cloak reserved",
    ["оружие рез"]="weapon reserved",
    ["сум к ласту"]="summon to last boss",
    ["к ласту"]="to last boss",
    ["сум в конец"]="summon to end",
    ["на ласта"]="for the last boss",
    ["рампы гер"]="Ramparts (heroic)",
    ["рампы дейлик"]="Ramparts daily",
    ["рампы дейли"]="Ramparts daily",
    ["рампы нм"]="Ramparts (normal)",
    ["рампы норм"]="Ramparts (normal)",
    ["бф гер"]="Blood Furnace (heroic)",
    ["бф нм"]="Blood Furnace (normal)",
    ["шх гер"]="Shattered Halls (heroic)",
    ["шх нм"]="Shattered Halls (normal)",
    ["шм гер"]="Shadow Labs (heroic)",
    ["шм нм"]="Shadow Labs (normal)",
    ["паровое нм"]="Steamvault (normal)",
    ["паровое гер"]="Steamvault (heroic)",
    ["ссц гер"]="Serpentshrine",
    ["узилище гер"]="Arcatraz (heroic)",
    ["узилище нм"]="Arcatraz (normal)",
    ["узилищер"]="Arcatraz (heroic)",
    ["на гер"]="for heroic",
    ["на нм"]="for normal",
    ["за репой"]="for rep",
    ["за репу"]="for rep",
    ["за реп"]="for rep",
    ["за 2 баджа"]="for 2 badges",
    ["за баджи"]="for badges",
    ["2 баджа в месяц"]="2 badges a month",
    ["баджа месяца"]="badges a month",
    ["скип ран"]="skip run",
    ["ран скип"]="skip run",
    ["нормалы и геры"]="normals and heroics",
    ["не сдались нормалы"]="nobody wants normals",
    ["не сдались геры"]="nobody wants heroics",

    -- Guild chat / recruitment
    ["в ги"]="in guild (guild-chat)",
    ["в гилде"]="in guild",
    ["в гильдию"]="to guild",
    ["помогаем одеваем"]="we help, gear you up",
    ["помогаем одеваем подсказываем"]="we help, gear, advise",
    ["связь обязательная"]="communication required",
    ["связь дискорд"]="discord required",
    ["для походов в рейды"]="for raid attendance",
    ["по доп"]="for extras",
    ["по доп вопросам"]="for additional questions",
    ["вопросам в пм"]="questions in PM",
    ["рейды с"]="raids from",
    ["сбор в"]="gather at",
    ["сбор в 19:00"]="gather at 19:00",
    ["статик шамы локи присты палы маги"]="static shamans warlocks priests paladins mages",
    ["ищет опытных игроков"]="looking for experienced players",
    ["для усиления гильдии"]="to strengthen the guild",
    ["для уcиления гильдии"]="to strengthen the guild", -- typo variant (latin 'c')
    ["эффективного прохождения"]="effective clears",
    ["прохождения санвела"]="Sunwell progression",
    ["с атюном на бт"]="with BT attunement",
    ["с аттюном на бт"]="with BT attunement",
    ["с барабанами"]="with drums",
    ["атюн на бт"]="BT attunement",
    ["аттюн на бт"]="BT attunement",
    ["аттюн нужен"]="need attunement",
    ["ци рейт"]="CY rating",

    -- Weekly schedule
    ["с пн по пт"]="Mon through Fri",
    ["сб и вс"]="Sat and Sun",
    ["пн по чт"]="Mon through Thu",
    ["с пн по чт"]="Mon through Thu",
    ["пн-чт"]="Mon-Thu",
    ["пн чт"]="Mon-Thu",
    ["сб-вс"]="Sat-Sun",
    ["по иркутскому времени"]="Irkutsk time",
    ["по иркутскому"]="Irkutsk time",
    ["иркутскому времени"]="Irkutsk time",
    ["по московскому времени"]="Moscow time",

    -- Quests / attunements seen in log
    ["прикосновение занзила"]="Touch of Zanzil (quest)",
    ["как выполнить"]="how to complete",
    ["не могу сдать"]="can't turn in",
    ["сдать не могу"]="can't turn in",
    ["квест не сдаётся"]="quest won't turn in",
    ["в журнале пишет"]="journal says",
    ["в журнале"]="in the log",
    ["всё что нужно купил"]="bought everything needed",
    ["за дейлик"]="for the daily",
    ["ключ за дейлик"]="daily key",
    ["пропал из сумки"]="disappeared from bag",
    ["было у кого такое"]="anyone had this",
    ["за кв"]="for quest",
    ["на разбойника"]="for rogue",

    -- Item names (Russian ruRU localisations -> English item names)
    ["туз из колоды зверей"]="Ace of Beasts",
    ["колода зверей"]="Darkmoon Deck: Beasts",
    ["фолиант сотворения воды"]="Tome of Conjure Water",
    ["изначальная мощь"]="Primal Might",
    ["ткань пустоты"]="Netherweave Cloth",
    ["руническая ткань"]="Runecloth",
    ["ездовой хлыст назана"]="Nazan's Riding Crop",
    ["ездовой хлыст"]="riding crop",

    -- Zones (ruRU -> enUS)
    ["сёрные топи"]="Swamp of Sorrows",
    ["серные топи"]="Swamp of Sorrows",
    ["в сёрные топи"]="to Swamp of Sorrows",
    ["алый монастырь"]="Scarlet Monastery",
    ["монастырь алого"]="Scarlet Monastery",
    ["алого ордена"]="of the Scarlet Order",
    ["на кладбище"]="at Graveyard (SM)",
    ["лабиринты иглошкуры"]="Razorfen Kraul",
    ["иглошкуры"]="Razorfen Kraul",
    ["барренс"]="Barrens", ["в барренсе"]="in Barrens",

    -- Arena / team search
    ["ищу напа в свою тиму"]="LF partner for my team",
    ["в свою тиму"]="for my team",
    ["свою тиму"]="my team",

    -- Complaints / rants
    ["задолбали спамить"]="tired of spam",
    ["задолбали своим"]="tired of your",
    ["гавно спамом"]="shit spam",
    ["спамить ги"]="spam guild",
    ["чат для 1300 онлайна"]="chat for 1300 online",
    ["не готов к такому"]="not ready for such",
    ["наплыву беженцев"]="influx of refugees",

    -- LFG shortcuts
    ["нужно 2 дд"]="need 2 dps",
    ["нужно 3 дд"]="need 3 dps",
    ["нужно 1 дд"]="need 1 dps",
    ["надо 2 дд"]="need 2 dps",
    ["надо 3 дд"]="need 3 dps",
    ["надо 1 дд"]="need 1 dps",
    ["дд ищу"]="LF dps",
    ["на бг"]="for BG",

    -- Attunement / travel / summon
    ["в инвизе пробежать"]="run in stealth",
    ["в инвизе"]="in stealth",
    ["в стелс"]="in stealth",
    ["пробежать до"]="run to",
    ["открой портал в"]="open portal to",
    ["портал в аутленд"]="portal to Outland",
    ["портал в каменор"]="portal to Stonard",
    ["порт в каменор"]="port to Stonard",
    ["порт в аутленд"]="port to Outland",

    -- Enchanting questions
    ["кто чарит"]="who can enchant",
    ["кто чарнет"]="who can enchant",
    ["кто чарит на"]="who enchants for",
    ["12 агилы"]="12 agility",
    ["9 выносливости"]="9 stamina",
    ["процент к бегу"]="% run speed",
    ["к бегу"]="to run speed",
    ["небольшой процент"]="small percent",
    ["15 меткости"]="15 hit",
    ["15 меткости заклинания"]="15 spell hit",
    ["меткости заклинания"]="spell hit",
    ["на перчи"]="on gloves",

    -- Recruitment ad templates
    ["розыск:"]="WANTED:",
    ["разыскивается"]="wanted",
    ["разыскиваетсяч"]="wanted",

    -- Asking/meta
    ["гм тут"]="GM here?",
    ["гм есть"]="any GM",
    ["гм если тут"]="GM if here",
    ["свяжись пожалуйста"]="please contact",
    ["ищу данжи"]="looking for dungeons",
    ["как тут данжи искать"]="how to find dungeons",
    ["данжи искать"]="find dungeons",
    ["данжи искаться"]="dungeon finder",
    ["данжи искались"]="dungeons were found",
    ["сервер мертвый"]="server is dead",
    ["сервер лагает"]="server is lagging",
    ["сервак лагает"]="server is lagging",

    -- "Ордена Алого" etc
    ["монастырь алого ордеан"]="Scarlet Monastery",

    -- Idioms often seen
    ["все реально"]="it's all doable",
    ["было бы желание"]="if you want it",
    ["остальное в рейдах"]="the rest from raids",
    ["чаще всего"]="most often",
    ["есть вариант"]="there's an option",
    ["для ленивых"]="for the lazy",
    ["попроси портал"]="ask for a portal",
    ["пробеги по всем"]="run to all",
    ["делать быстро"]="to do quickly",

    -- Hint/teach phrases
    ["чаще всего в ги"]="usually in guild",
    ["чаще всего в гильдии"]="usually in guild",
    ["в лфг можно"]="via LFG you can",
    ["долго будешь искать"]="you'll search long",
    ["бывает долго"]="sometimes takes long",

    -- Arena rating phrases
    ["рег 2с"]="reg 2v2",
    ["рег 3с"]="reg 3v3",
    ["рег 5с"]="reg 5v5",
    ["high reit"]="high rating",

    -- =================================================================
    -- Log-latest additions (WoWChatLog.txt 2026-04-19 → 2026-04-21)
    -- Bring coverage from 84% to 95%+ on new topics: transfer drama,
    -- Adamantite/Khorium trade chatter, Shattered Halls/Sethekk/Steamvault
    -- LFG, "quick start" paid service debate, render-distance tech QA.
    -- =================================================================

    -- Zones & quest names
    ["разрушенные залы"]="Shattered Halls",
    ["разрушенных залах"]="Shattered Halls (prep)",
    ["черные топи"]="Black Morass",
    ["чёрные топи"]="Black Morass",
    ["гробницы маны"]="Mana-Tombs",
    ["нижний город"]="Lower City",
    ["долина призрачной луны"]="Shadowmoon Valley",
    ["долины призрачной луны"]="Shadowmoon Valley",
    ["долине призрачной луны"]="Shadowmoon Valley (prep)",
    ["призрачной луны"]="Shadowmoon",
    ["призрачные земли"]="Ghostlands",
    ["путь завоевания"]="Path of Conquest (quest)",
    ["битва у кровавого дозора"]="Battle for Blood Watch (quest)",
    ["у кровавого дозора"]="at Blood Watch",
    ["кровавого дозора"]="Blood Watch",
    ["принеси мне яйцо"]="Bring Me an Egg! (quest)",

    -- Trade items (ruRU -> enUS)
    ["великая планарная субстанция"]="Greater Planar Essence",
    ["планарная субстанция"]="Planar Essence",
    ["адамантитовая руда"]="Adamantite Ore",
    ["кориевая руда"]="Khorium Ore",
    ["слиток оскверненного железа"]="Fel Iron Bar",
    ["оскверненного железа"]="Fel Iron",
    ["изначальная жизнь"]="Primal Life",
    ["изначальная луноткань"]="Primal Mooncloth",
    ["большой радужный осколок"]="Large Prismatic Shard",
    ["радужный осколок"]="Prismatic Shard",
    ["демонический кристалл"]="Demonic Rune",
    ["рог полярного волка"]="Frost Wolf Horn",
    ["безжалостные планы"]="Ruthless plans (recipe)",
    ["целительная сила природы"]="Healing Power of Nature (gem)",
    ["животворный рубин"]="Life-Giving Ruby (gem)",
    ["наручи сообразительности"]="Bracers of Quickness",
    ["наручи зеленой крепости"]="Bracers of the Green Fortress",
    ["повязки быстрого исцеления"]="Bands of Quick Healing",

    -- Quick Start (paid service heavily discussed in this log)
    ["быстрый старт"]="Quick Start (paid svc)",
    ["быстрого старта"]="Quick Start (paid svc)",
    ["быстрый а2"]="Quick Start to A2",
    ["фул а2"]="full Arena Season 2",

    -- Tech / UI
    ["дальность прорисовки"]="draw distance",
    ["дальность отображения"]="display distance",
    ["отдаление камеры"]="camera zoom-out",
    ["настройки камеры"]="camera settings",
    ["макрос найди"]="find the macro",

    -- LFG/LFM combos
    ["ищю группу"]="looking for group",
    ["ищу группу"]="looking for group",
    ["танк и хил на"]="tank and healer for",
    ["нужны 2 дд"]="need 2 dps",
    ["дд танк хил"]="dps tank heal",
    ["танк хил дд"]="tank heal dps",
    ["фарм репы"]="farm rep",
    ["нужен танк хил дпс"]="need tank heal dps",
    ["шл норма"]="SL normal",
    ["шл гер"]="SL heroic",
    ["шл героик"]="SL heroic",
    ["сеттеки гер"]="Sethekk heroic",
    ["паро под"]="Steamvault",
    ["паровые подземелья"]="Steamvaults",

    -- Recruitment
    ["вступить в ги"]="join the guild",
    ["вступлю в ги"]="I'll join the guild",
    ["принимаем всех"]="accepting everyone",

    -- Gold shorthand meta
    ["1к1"]="1:1 ratio",

    -- "народец вон" kind of filler
    ["кароч я"]="in short, I",
    ["в пм плз"]="in PM please",
    ["отпишитесь в пм"]="reply in PM",
    ["кто нить"]="anyone",
    ["каком нить"]="any kind of",
    ["какой нить"]="any kind of",

    -- Drama/slang
    ["кинул на шмот"]="scammed on gear",
    ["кинула на шмот"]="scammed on gear",
    ["кидала и мошенник"]="scammer and fraud",
    ["куколды и терпилы"]="cucks and pushovers",
    ["анрол топ"]="offspec top tier (sarcastic)",
    ["жирных дилдо"]="fat dildos",
    ["дешевка лицемерная"]="cheap hypocrite",
    ["лицемерная и лживая"]="hypocritical and lying",

    -- Helheim guild ad
    ["приоритет в новых людях"]="priority for new players",
    ["на сервере"]="on the server",
    ["шмот не важен"]="gear doesn't matter",
    ["для малых лвл"]="for low levels",
    ["мы ценим"]="we value",
    ["ценим новых игроков"]="we value new players",
}

-- ---------------------------------------------------------------------------
-- Word dictionary (single token)
-- ---------------------------------------------------------------------------
ns.WORDS = {
    -- ================================================================
    -- Zones & cities (including grammatical cases found in chat)
    -- ================================================================
    ["штормград"]="Stormwind", ["штормграда"]="Stormwind", ["штормграде"]="Stormwind",
    ["оргриммар"]="Orgrimmar", ["оргриммара"]="Orgrimmar", ["оргриммаре"]="Orgrimmar", ["орг"]="Orgrimmar",
    ["даларан"]="Dalaran", ["даларана"]="Dalaran", ["даларане"]="Dalaran",
    ["шаттрат"]="Shattrath", ["шаттрате"]="Shattrath", ["шатт"]="Shattrath",
    ["экзодар"]="Exodar", ["экзодара"]="Exodar",
    ["луносвет"]="Silvermoon", ["луносвета"]="Silvermoon",
    ["подгород"]="Undercity",
    ["азерот"]="Azeroth", ["азерота"]="Azeroth", ["азероте"]="Azeroth",
    ["запределье"]="Outland", ["запределья"]="Outland",
    ["нордскол"]="Northrend", ["калимдор"]="Kalimdor",
    ["пустоверть"]="Netherstorm", ["острогорье"]="Blade's Edge",
    ["награнд"]="Nagrand", ["зангартопь"]="Zangarmarsh",
    ["ашенваль"]="Ashenvale",

    -- ================================================================
    -- 5-man dungeons (TBC)
    -- ================================================================
    ["рфс"]="Ragefire Chasm", ["рфц"]="Ragefire Chasm", ["рфк"]="Ragefire Chasm",
    ["сфк"]="Shadowfang Keep",
    ["рампы"]="Ramparts", ["рампа"]="Ramparts", ["рампу"]="Ramparts", ["рамп"]="Ramparts",
    ["бф"]="Blood Furnace", ["фурнэс"]="Blood Furnace",
    ["шх"]="Shattered Halls", ["шатр"]="Shattered Halls", ["шатров"]="Shattered Halls",
    ["шатхол"]="Shattered Halls",
    ["шм"]="Shadow Labs", ["шадоу"]="Shadow Labs", ["шадлаб"]="Shadow Labs",
    ["мт"]="Mana-Tombs", ["мантумбы"]="Mana-Tombs", ["мана-тумбы"]="Mana-Tombs", ["маналей"]="Mana-Tombs",
    ["ботаника"]="Botanica", ["ботан"]="Botanica",
    ["арка"]="Arcatraz", ["аркатраз"]="Arcatraz", ["аркатрац"]="Arcatraz",
    ["механар"]="Mechanar", ["меха"]="Mechanar", ["мехонавт"]="Mechanar",
    ["морох"]="Black Morass", ["морасс"]="Black Morass",
    ["ул"]="Old Hillsbrad", ["дурнхолд"]="Durnholde",
    ["склепы"]="Auchenai Crypts",
    ["сет"]="Sethekk Halls", ["сетек"]="Sethekk Halls", ["сетеки"]="Sethekk Halls", ["сетк"]="Sethekk Halls",
    ["пп"]="Steamvault", ["паровое"]="Steamvault",
    ["загон"]="Slave Pens", ["рабов"]="Slave Pens", ["слэйв"]="Slave Pens", ["слейв"]="Slave Pens",
    ["нижетопь"]="Underbog", ["муни"]="Underbog",
    ["сх"]="Shattered Halls", ["sh"]="Shattered Halls", ["shh"]="Shattered Halls",
    ["sfk"]="Shadowfang Keep", ["rfc"]="Ragefire Chasm", ["mgt"]="Magisters' Terrace",

    -- ================================================================
    -- Raids
    -- ================================================================
    ["кара"]="Karazhan", ["каражан"]="Karazhan", ["каражана"]="Karazhan",
    ["каражане"]="Karazhan", ["каре"]="Karazhan", ["кары"]="Karazhan",
    ["бт"]="Black Temple", ["бтшка"]="Black Temple",
    ["груул"]="Gruul", ["груула"]="Gruul", ["грула"]="Gruul", ["грул"]="Gruul", ["гр"]="Gruul",
    ["магтеридон"]="Magtheridon", ["магтер"]="Magtheridon", ["магу"]="Magtheridon",
    ["ссц"]="Serpentshrine", ["серпент"]="Serpentshrine", ["сск"]="Serpentshrine",
    ["серпентрия"]="Serpentshrine",
    ["тк"]="Tempest Keep", ["тэка"]="Tempest Keep", ["око"]="The Eye",
    ["глаз"]="The Eye", ["глазик"]="The Eye",
    ["хиджал"]="Hyjal", ["хиджала"]="Hyjal",
    ["хс"]="Hyjal Summit",
    ["мгт"]="Magisters' Terrace",
    ["за"]="for",  -- preposition; Zul'Aman sense is covered by phrases "го за", "кто на за"
    ["зуль"]="Zul'Aman", ["зулик"]="Zul'Aman", ["зульаман"]="Zul'Aman", ["заул"]="Zul'Aman",

    -- Vanilla raids (sometimes referenced)
    ["накса"]="Naxxramas", ["наксик"]="Naxxramas",
    ["мс"]="Molten Core", ["молтен"]="Molten Core",
    ["блв"]="Blackwing Lair", ["оня"]="Onyxia", ["онь"]="Onyxia",
    ["зг"]="Zul'Gurub",
    ["ак40"]="AQ40", ["ак20"]="AQ20",
    ["уц"]="Stratholme", ["страта"]="Stratholme",
    ["скола"]="Scholomance", ["скольцо"]="Scholomance",
    ["дм"]="Dire Maul",
    ["бсг"]="Blackrock Spire", ["лбрс"]="Lower Blackrock", ["убрс"]="Upper Blackrock",

    -- ================================================================
    -- Bosses / NPCs
    -- ================================================================
    ["теракнарнтул"]="Terokk", ["тероккарнтул"]="Terokk", ["терокк"]="Terokk",
    ["иллидан"]="Illidan", ["иллидана"]="Illidan", ["иллидану"]="Illidan", ["иллидане"]="Illidan",
    ["кельтас"]="Kael'thas",
    ["суккубу"]="succubus", ["суккуб"]="succubus",

    -- ================================================================
    -- Classes + specs (all forms)
    -- ================================================================
    -- Roles
    ["хил"]="healer", ["хилл"]="healer", ["хилер"]="healer",
    ["хила"]="healer", ["хилов"]="healers", ["хилы"]="healers", ["хилить"]="heal",
    ["танк"]="tank", ["танки"]="tanks", ["танка"]="tank", ["танков"]="tanks", ["танчить"]="tank",
    ["оттанковать"]="off-tank", ["офтанк"]="off tank", ["мт"]="main tank", ["от"]="off tank",
    ["рл"]="raid leader", ["рейдлид"]="raid leader",
    ["мастер"]="master looter",
    ["ассист"]="assist", ["суппорт"]="support", ["саппорт"]="support",
    ["дд"]="dps", ["ддшка"]="dps", ["дпс"]="dps", ["дды"]="dps", ["дпсить"]="dps", ["дамагер"]="dps",
    ["мили"]="melee", ["рендж"]="ranged", ["кастер"]="caster",
    -- Mage
    ["маг"]="mage", ["маги"]="mages", ["мага"]="mage", ["магов"]="mages",
    ["фростик"]="frost mage", ["арканик"]="arcane mage", ["файр"]="fire",
    -- Hunter
    ["хант"]="hunter", ["ханта"]="hunter", ["хантер"]="hunter", ["хантеры"]="hunters",
    ["бм"]="BM hunter", ["марк"]="marksman", ["сурв"]="survival", ["сурвач"]="survival",
    -- Paladin
    ["паль"]="paladin", ["пал"]="paladin", ["падик"]="paladin",
    ["палы"]="paladins", ["палов"]="paladins", ["паладин"]="paladin",
    ["паладина"]="paladin", ["паладинов"]="paladins", ["паладины"]="paladins",
    ["ретри"]="retribution pal", ["ретрик"]="retribution pal",
    ["холик"]="holy pal", ["протик"]="prot pal",
    -- Warlock
    ["лок"]="warlock", ["локи"]="warlocks", ["локов"]="warlocks",
    ["варлок"]="warlock", ["варлока"]="warlock",
    ["афлик"]="affliction lock", ["деструктор"]="destro lock", ["деструкт"]="destro lock",
    -- Shaman
    ["шам"]="shaman", ["шама"]="shaman", ["шаманы"]="shamans", ["шаман"]="shaman",
    ["элька"]="ele shaman", ["энх"]="enh shaman", ["энха"]="enh shaman",
    ["рестик"]="resto",
    -- Priest
    ["прист"]="priest", ["приста"]="priest", ["присты"]="priests",
    ["шп"]="shadow priest", ["шадик"]="shadow priest",
    ["дисц"]="disc priest", ["дисциплина"]="discipline",
    -- Rogue
    ["ро"]="rogue", ["рога"]="rogue", ["рог"]="rogue", ["рогу"]="rogue", ["рожка"]="rogue",
    ["разбойник"]="rogue", ["разбойника"]="rogue",
    ["комбат"]="combat rogue", ["ассасс"]="sin rogue", ["сабтл"]="sub rogue", ["суб"]="sub rogue",
    -- Warrior
    ["варик"]="warrior", ["варики"]="warriors", ["варр"]="warrior",
    ["воин"]="warrior", ["воины"]="warriors",
    ["армс"]="arms warrior", ["фури"]="fury warrior",
    -- Druid
    ["друид"]="druid", ["друида"]="druid", ["друиды"]="druids", ["дру"]="druid", ["друль"]="druid",
    ["ферал"]="feral", ["ферик"]="feral",
    ["баланс"]="balance", ["мункин"]="moonkin", ["совунья"]="moonkin",
    -- Specs / generic
    ["ресто"]="resto", ["рет"]="ret", ["прот"]="prot", ["протка"]="prot",
    ["холи"]="holy", ["фрост"]="frost", ["аркан"]="arcane", ["фаер"]="fire",
    ["элем"]="elemental", ["стихии"]="elemental",
    ["спек"]="spec", ["специализация"]="spec", ["респек"]="respec",

    -- ================================================================
    -- LFG / LFM / actions
    -- ================================================================
    ["лфм"]="LFM", ["лфг"]="LFG", ["лф"]="LF",
    ["инв"]="inv", ["инвай"]="invite", ["инвайт"]="invite", ["инвнуть"]="to invite",
    ["позови"]="invite", ["позвал"]="invited", ["приглашаю"]="inviting",
    ["го"]="go", ["поехали"]="let's go", ["погнали"]="let's go", ["пошли"]="let's go",
    ["выдвигаемся"]="moving out", ["стартуем"]="starting", ["начинаем"]="starting",
    ["собираемся"]="gathering", ["собрались"]="gathered",
    ["заходи"]="join", ["заходите"]="join us",
    ["ищу"]="LF", ["ищем"]="looking for",
    ["нужен"]="need", ["нужна"]="need", ["нужно"]="need", ["нужны"]="need",
    ["надо"]="need", ["нид"]="need", ["ниде"]="need",
    ["берем"]="taking", ["возьму"]="will take", ["возьмем"]="will take",
    ["набираем"]="recruiting", ["рекрут"]="recruit", ["рекрутим"]="recruiting",
    ["добить"]="fill spot",

    -- ================================================================
    -- Trade / money
    -- ================================================================
    ["продам"]="WTS", ["продаю"]="selling", ["продаёт"]="sells", ["продают"]="selling",
    ["продал"]="sold", ["продала"]="sold", ["продали"]="sold", ["продаст"]="will sell",
    ["куплю"]="WTB", ["купил"]="bought", ["купила"]="bought", ["купили"]="bought",
    ["купишь"]="will buy", ["купит"]="will buy", ["покупаю"]="buying", ["покупает"]="buys",
    ["меняю"]="WTT", ["обмен"]="trade", ["бартер"]="trade",
    ["отдам"]="giving", ["даром"]="free", ["забирай"]="take it",
    ["цена"]="price", ["цены"]="prices", ["стоит"]="costs", ["стоило"]="cost",
    ["торг"]="haggling", ["скидка"]="discount", ["скидос"]="discount",
    ["дешево"]="cheap", ["дёшево"]="cheap", ["дорого"]="expensive",
    ["подешевле"]="cheaper", ["подорожало"]="got pricier", ["подешевело"]="got cheaper",
    ["стак"]="stack", ["стака"]="stack",
    ["голд"]="gold", ["г"]="g", ["сильв"]="silver", ["медь"]="copper",
    ["бабки"]="money", ["бабок"]="money", ["бабло"]="money", ["денюжка"]="money",
    ["деньжата"]="cash", ["денежка"]="money", ["монетки"]="coins",
    ["копейка"]="penny", ["копеечка"]="penny", ["копейки"]="pennies",
    ["голдец"]="gold", ["золотишко"]="gold", ["лям"]="million", ["лимон"]="million",
    ["милик"]="million", ["мильон"]="million", ["миллион"]="million",
    ["тыща"]="thousand", ["тыщу"]="thousand", ["тыщи"]="thousands", ["тыщ"]="k",
    ["аук"]="AH", ["ах"]="AH", ["аукцион"]="auction", ["ашка"]="AH",
    ["ставка"]="bid", ["выкуп"]="buyout",
    ["выставь"]="post to AH", ["выставил"]="posted",
    ["скам"]="scam", ["скамить"]="scam", ["кидала"]="scammer", ["крыса"]="ninja looter",
    ["перекуп"]="reseller",
    ["чарки"]="enchants", ["чар"]="enchant", ["чара"]="enchant", ["чанта"]="enchant",
    ["чантера"]="enchanter", ["чантер"]="enchanter", ["зачаровывание"]="enchanting",
    ["энчант"]="enchant", ["энч"]="enchant", ["зачар"]="enchant", ["зачарка"]="enchant",
    ["прицел"]="scope",
    ["крит"]="crit", ["крита"]="crit", ["крыт"]="crit", ["крытануть"]="crit",
    ["ловкость"]="agility", ["ловкости"]="agility", ["лвк"]="agi", ["ловка"]="agi",
    ["сила"]="strength", ["стр"]="str",
    ["интеллект"]="intellect", ["инт"]="int", ["инты"]="int",
    ["стамина"]="stamina", ["стам"]="stam", ["стамка"]="stam",
    ["дух"]="spirit", ["спирит"]="spirit", ["духа"]="spirit",

    -- ================================================================
    -- Gear / loot
    -- ================================================================
    ["шмот"]="gear", ["шмота"]="gear", ["шмотки"]="gear", ["шмотка"]="gear piece",
    ["гир"]="gear", ["гирка"]="gear",
    ["лут"]="loot", ["лута"]="loot", ["лутец"]="loot", ["лутать"]="loot",
    ["дроп"]="drop", ["дропа"]="drop", ["дропнуть"]="drop", ["дропнуло"]="dropped",
    ["упало"]="dropped", ["выпало"]="dropped", ["падает"]="drops",
    ["нид"]="need", ["грид"]="greed", ["пас"]="pass",
    ["ролл"]="roll", ["ролить"]="roll", ["перекат"]="reroll",
    ["плащ"]="cloak", ["плаща"]="cloak", ["спина"]="back", ["клоак"]="cloak", ["мантия"]="cloak",
    ["перчатки"]="gloves", ["перчи"]="gloves",
    ["наплечи"]="shoulders", ["плечи"]="shoulders",
    ["оружие"]="weapon", ["оружия"]="weapon", ["пухи"]="weapons", ["пуха"]="weapon",
    ["двуруч"]="2h", ["двуручка"]="2h", ["двуручник"]="2h user",
    ["одноруч"]="1h", ["одноручка"]="1h",
    ["кольцо"]="ring", ["кольца"]="rings", ["кольцуха"]="ring",
    ["амулет"]="neck", ["неклейс"]="neck",
    ["палка"]="staff", ["палку"]="staff", ["посох"]="staff", ["стафф"]="staff",
    ["щит"]="shield", ["щитник"]="shield user",
    ["броня"]="armor", ["брони"]="armor", ["броник"]="chest armor",
    ["грудь"]="chest", ["голова"]="head", ["башка"]="helmet", ["шлем"]="helm",
    ["ноги"]="legs", ["поножи"]="legs", ["наголенники"]="legs",
    ["руки"]="hands", ["запястья"]="wrists", ["наручи"]="bracers", ["напульс"]="bracers",
    ["сапоги"]="boots", ["боты"]="boots", ["пояс"]="belt",
    ["кинжал"]="dagger", ["даги"]="daggers", ["дагер"]="dagger",
    ["меч"]="sword", ["булава"]="mace", ["топор"]="axe",
    ["лук"]="bow", ["арбалет"]="crossbow", ["арба"]="crossbow", ["ружьё"]="gun",
    ["жезл"]="wand", ["ванд"]="wand", ["палочка"]="wand",
    ["фокус"]="off-hand", ["оффхенд"]="off-hand",
    ["тринька"]="trinket", ["тринкет"]="trinket",
    ["гем"]="gem", ["гемы"]="gems", ["гемм"]="gem", ["самоцвет"]="gem", ["гемать"]="to gem",
    ["сокет"]="socket", ["слот"]="socket", ["гнездо"]="socket", ["мета"]="meta gem",
    ["эпик"]="epic", ["эпика"]="epic", ["эпики"]="epics", ["эпуха"]="epic", ["пурпур"]="epic",
    ["фиолет"]="epic", ["фиолетка"]="epic", ["фиолетовый"]="epic",
    ["синька"]="blue", ["синий"]="blue", ["блю"]="blue",
    ["зелёнка"]="green", ["зеленка"]="green", ["грин"]="green", ["зелень"]="green",
    ["белка"]="white", ["серка"]="grey", ["легендарка"]="legendary", ["легенда"]="legendary",
    ["арт"]="artifact", ["артифакт"]="artifact", ["артефакт"]="artifact",
    ["сетовка"]="set piece", ["тир"]="tier", ["тирка"]="tier",
    ["т4"]="T4", ["т5"]="T5", ["т6"]="T6",
    ["бис"]="BIS",
    ["крафт"]="craft", ["крафтовый"]="crafted", ["скрафтить"]="craft",
    ["гс"]="gearscore", ["жс"]="gearscore",

    -- ================================================================
    -- Stats / combat
    -- ================================================================
    ["хаст"]="haste", ["хит"]="hit", ["кап"]="cap", ["закапить"]="to cap", ["капнут"]="capped",
    ["спелл"]="spell power", ["спд"]="spell damage", ["спелл-дамаг"]="spell damage",
    ["рап"]="ranged AP", ["ап"]="AP", ["апха"]="AP",
    ["арморпен"]="armor pen", ["бронепроб"]="armor pen",
    ["рес"]="resilience", ["резист"]="resist", ["сопр"]="resist", ["сопротивление"]="resistance",
    ["экспертиза"]="expertise", ["еспер"]="expertise",
    ["мп5"]="MP5", ["реген"]="regen",
    ["экспа"]="XP", ["хп"]="hp", ["мана"]="mana", ["маны"]="mana",
    ["ярость"]="rage", ["энергия"]="energy", ["концентрация"]="focus",

    -- Combat actions
    ["пуск"]="pull", ["пулл"]="pull", ["пулить"]="pull", ["пуллить"]="pull",
    ["пуллю"]="pulling", ["пуллим"]="pulling", ["сагрил"]="pulled",
    ["агр"]="aggro", ["агро"]="aggro", ["аггр"]="aggro", ["агрит"]="aggroing", ["сагрить"]="grab aggro",
    ["моб"]="mob", ["мобы"]="mobs", ["пак"]="pack", ["пачка"]="pack",
    ["треш"]="trash", ["трешь"]="trash", ["босс"]="boss", ["адды"]="adds",
    ["фаза"]="phase", ["фазе"]="phase", ["фазы"]="phase",
    ["энрейдж"]="enrage", ["энраж"]="enrage", ["берсерк"]="berserk",
    ["вайп"]="wipe", ["вайпнулись"]="wiped", ["вайпить"]="wipe", ["завайпить"]="wipe raid",
    ["трай"]="try", ["трайаем"]="trying", ["пробуем"]="trying",
    ["килл"]="kill", ["клир"]="clear", ["зачистили"]="cleared", ["зачистка"]="clear",
    ["аое"]="aoe", ["аоэ"]="aoe", ["дот"]="DoT", ["дотка"]="DoT", ["хот"]="HoT",
    ["бафф"]="buff", ["баф"]="buff", ["бафы"]="buffs", ["дебаф"]="debuff", ["дебафы"]="debuffs",
    ["бафнули"]="buffed", ["бафнуть"]="buff", ["бафните"]="buff me",
    ["дисп"]="dispel", ["диспелите"]="dispel", ["рассеять"]="dispel", ["очищение"]="cleanse",
    ["фир"]="fear", ["фирнуть"]="fear", ["сап"]="sap", ["сапнуть"]="sap",
    ["морф"]="polymorph", ["морфнуть"]="polymorph", ["полимаг"]="polymorph", ["поли"]="polymorph", ["полик"]="polymorph",
    ["сил"]="silence", ["силенс"]="silence",
    ["стан"]="stun", ["станить"]="stun", ["станлок"]="stunlock",
    ["рут"]="root", ["рутнуть"]="root",
    ["шит"]="shield", ["бабл"]="bubble", ["пузырь"]="bubble",
    ["тотем"]="totem", ["тотемы"]="totems",
    ["свиток"]="scroll", ["свиточек"]="scroll",
    ["фласка"]="flask", ["флак"]="flask", ["элик"]="elixir", ["эликсир"]="elixir", ["зелье"]="potion",
    ["хп пот"]="healthpot", ["ман пот"]="manapot",
    ["бл"]="bloodlust", ["блудка"]="bloodlust", ["героизм"]="heroism",
    ["инервейт"]="innervate", ["инневейт"]="innervate",
    ["призыв"]="summon", ["саммон"]="summon", ["саммонить"]="summon",
    ["призвать"]="summon", ["призви"]="summon",
    ["рес"]="rez", ["реснуть"]="rez", ["ресни"]="rez", ["воскреси"]="rez",
    ["сс"]="soulstone", ["сурек"]="soulstone", ["камень"]="stone",
    ["камню"]="stone", ["камушек"]="hearthstone",
    ["метка"]="mark", ["метки"]="marks", ["череп"]="skull", ["крест"]="cross",
    ["звезда"]="star", ["луна"]="moon", ["ромб"]="diamond", ["квадрат"]="square", ["треугольник"]="triangle",
    ["таргет"]="target", ["цель"]="target", ["таргетить"]="target",
    ["каст"]="cast", ["кастовать"]="cast", ["закастуй"]="cast it",
    ["прерывание"]="interrupt", ["интеррапт"]="interrupt", ["кикнуть каст"]="interrupt",
    ["откат"]="cooldown", ["кд"]="cooldown", ["гкд"]="GCD", ["глобалка"]="GCD",
    ["готов"]="ready", ["готова"]="ready", ["готовы"]="ready", ["рэди"]="ready", ["чек"]="check",

    -- ================================================================
    -- Group / activity
    -- ================================================================
    ["рейд"]="raid", ["рейда"]="raid", ["рейды"]="raids", ["рейдик"]="raid",
    ["пати"]="party", ["тима"]="team", ["команда"]="team", ["состав"]="roster",
    ["пвп"]="PvP", ["пве"]="PvE", ["пвпшник"]="pvp player", ["пвешник"]="pve player",
    ["бг"]="BG", ["бгшка"]="BG", ["поле"]="battleground",
    ["арена"]="arena", ["арену"]="arena", ["аренку"]="arena", ["арены"]="arenas",
    ["ав"]="AV", ["аб"]="AB", ["всг"]="WSG", ["эос"]="EotS", ["эй"]="EotS",
    ["рейтинг"]="rating", ["рейт"]="rating", ["ммр"]="MMR",
    ["рандом"]="pug", ["ренд"]="pug",
    ["гильдия"]="guild", ["гилда"]="guild", ["гильд"]="guild", ["гильдии"]="guild",
    ["гильдию"]="guild", ["гилдак"]="guild leader", ["гилдчат"]="guild chat", ["гч"]="gchat",
    ["гач"]="guild chat", ["гб"]="guild bank", ["казна"]="treasury",
    ["офицер"]="officer", ["оф"]="officer", ["офик"]="officer", ["офф"]="officer",
    ["хк"]="heroic", ["героик"]="heroic", ["геройка"]="heroic", ["геройская"]="heroic",
    ["героика"]="heroic", ["героики"]="heroics", ["героиков"]="heroics",
    ["нормал"]="normal", ["нормалка"]="normal", ["об"]="(normal)", ["обычный"]="normal",
    ["дейли"]="daily", ["дейлик"]="daily", ["дейлики"]="dailies", ["ежедневка"]="daily",
    ["квест"]="quest", ["квеста"]="quest", ["квесты"]="quests",
    ["кв"]="quest", ["квес"]="quest",
    ["инст"]="instance", ["инсты"]="instances", ["подземелье"]="dungeon", ["данж"]="dungeon",
    ["данжа"]="dungeon", ["данжи"]="dungeons",
    ["ключ"]="key", ["ключа"]="key",
    ["статик"]="static group", ["статика"]="static", ["мейн"]="main",
    ["твинк"]="alt", ["твинкать"]="play alts",
    ["рег"]="reg", ["набор"]="recruiting", ["сбор"]="forming",
    ["игроков"]="players", ["игрок"]="player", ["игроки"]="players", ["игров"]="players",
    ["активных"]="active", ["активный"]="active", ["активные"]="active",
    ["реалм"]="realm", ["реалма"]="realm", ["реалму"]="realm", ["реалмы"]="realms",
    ["сервер"]="server", ["серв"]="server", ["сервера"]="server", ["серверок"]="server",
    ["оффлайн"]="offline", ["онлайн"]="online",

    -- ================================================================
    -- Lockout / sessions
    -- ================================================================
    ["сейв"]="saved", ["сохр"]="saved", ["сохранение"]="lockout",
    ["лочка"]="lockout", ["перелочиться"]="reset lockout",

    -- ================================================================
    -- Professions
    -- ================================================================
    ["алхимик"]="alchemist", ["алхимия"]="alchemy",
    ["кузнец"]="blacksmith", ["кузнечество"]="blacksmithing", ["кузня"]="smithing",
    ["инженер"]="engineer", ["инженерия"]="engineering", ["инженерка"]="engineering",
    ["ювелир"]="jeweler", ["ювелирка"]="jc", ["ювелирное"]="jc",
    ["пошив"]="tailoring", ["портной"]="tailor",
    ["кожевник"]="leatherworker", ["кожевничество"]="leatherworking",
    ["первая помощь"]="first aid", ["бинт"]="bandage", ["бинтуй"]="bandage",
    ["снятие шкур"]="skinning", ["шкуродёр"]="skinner",
    ["горное дело"]="mining", ["шахтёр"]="miner", ["руда"]="ore",
    ["травничество"]="herbalism", ["травник"]="herbalist", ["трава"]="herb",
    ["рыбалка"]="fishing", ["рыбак"]="fisher",
    ["кулинария"]="cooking", ["повар"]="cook", ["варка"]="cooking",
    ["ученик"]="apprentice", ["подмастерье"]="journeyman",
    ["умелец"]="artisan", ["знаток"]="expert",

    -- ================================================================
    -- PvP specific
    -- ================================================================
    ["хонор"]="honor", ["чести"]="honor", ["честь"]="honor",
    ["знак"]="mark", ["знаки"]="marks", ["глад"]="gladiator", ["гладиатор"]="gladiator",
    ["кайт"]="kite", ["кайтить"]="kite", ["бурст"]="burst", ["бурстануть"]="burst",
    ["контроль"]="CC", ["кц"]="CC", ["цц"]="CC",
    ["ганк"]="gank", ["ганкать"]="gank", ["ганкнуть"]="gank",

    -- ================================================================
    -- Factions
    -- ================================================================
    ["орды"]="horde", ["ордынский"]="horde", ["ордынские"]="horde",
    ["альянс"]="alliance", ["альянса"]="alliance", ["альянсовский"]="alliance",
    ["альянсовскую"]="alliance", ["альянсовские"]="alliance",
    ["репа"]="rep", ["репутация"]="reputation", ["фракция"]="faction",
    ["превозношение"]="exalted", ["почтение"]="revered",

    -- ================================================================
    -- Server / tech / money (meta)
    -- ================================================================
    ["донат"]="donation", ["донатить"]="donate", ["донатер"]="donator", ["донатор"]="donator",
    ["буст"]="boost", ["бусты"]="boosts", ["бустинг"]="boosting", ["бустер"]="booster",
    ["примка"]="buff item",
    ["прем"]="premium", ["реалманы"]="real money", ["реалы"]="real money", ["реал"]="irl money",
    ["рубли"]="rubles", ["бакс"]="buck", ["пинкод"]="pin code",
    -- боты is ambiguous: usually "boots" (gear slang) in LFG/trade chat,
    -- occasionally "bots" (pejorative for bot-farmers) in complaint chat.
    -- Default to "boots" here; the "bots" sense is picked up by phrases
    -- ("боты пишут", "все боты" — see PHRASES above).
    ["бот"]="bot", ["ботовод"]="botter",
    ["читер"]="cheater", ["чит"]="cheat", ["читы"]="cheats", ["читерить"]="cheat", ["античит"]="anticheat",
    ["мультачить"]="multibox", ["мультак"]="multiboxer",
    ["админ"]="admin", ["админа"]="admin", ["администрация"]="admin",
    ["гм"]="GM", ["пм"]="PM", ["лс"]="PM", ["личка"]="PM",
    ["модер"]="mod",
    ["бан"]="ban", ["забанить"]="ban", ["банхаммер"]="banhammer", ["разбан"]="unban",
    ["мьют"]="mute", ["мьютнуть"]="mute", ["варн"]="warn",
    ["кик"]="kick", ["кикнуть"]="kick", ["кикать"]="kick",
    ["репорт"]="report", ["репортнул"]="reported", ["репортнуть"]="report", ["жалоба"]="report",
    ["тикет"]="ticket", ["апил"]="appeal", ["апелляция"]="appeal",
    ["скрин"]="screenshot",
    ["тп"]="teleport", ["телепорт"]="teleport", ["порт"]="portal", ["портал"]="portal",

    -- Tech issues
    ["лаг"]="lag", ["лаги"]="lag", ["лагает"]="lagging", ["тормозит"]="lagging", ["тупит"]="lagging",
    ["пинг"]="ping", ["фриз"]="freeze", ["фризит"]="freezing",
    ["дисконнект"]="disconnect", ["дизконнект"]="disconnect", ["дискон"]="dc", ["диск"]="dc", ["дк"]="dc",
    ["ддос"]="ddos",
    ["вылет"]="crash", ["вылетел"]="crashed", ["вылетела"]="crashed", ["вылетело"]="crashed", ["завис"]="froze",
    ["зависла"]="froze", ["зависло"]="froze",
    ["глюк"]="glitch", ["глючит"]="glitches", ["баг"]="bug", ["багает"]="buggy",
    ["бажит"]="buggy", ["багнутый"]="bugged", ["багнулся"]="bugged", ["эксплойт"]="exploit",
    ["абуз"]="abuse", ["абузить"]="abuse", ["абузер"]="abuser",
    ["рестарт"]="restart", ["ребут"]="reboot",
    ["обнова"]="patch", ["патч"]="patch", ["апдейт"]="update",
    ["хотфикс"]="hotfix", ["хф"]="hotfix",
    ["скачиваю"]="downloading", ["качаю"]="downloading", ["загрузка"]="loading",

    -- ================================================================
    -- Chat slang / reactions / short words
    -- ================================================================
    ["привет"]="hi", ["прив"]="hi", ["здарова"]="hey", ["дарова"]="hey",
    ["хай"]="hi", ["хелоу"]="hello", ["йо"]="yo", ["здрасте"]="hi",
    ["пока"]="bye", ["покеда"]="bye", ["чао"]="ciao",
    ["спс"]="thx", ["спасибо"]="thanks", ["пасиб"]="thanks", ["пасибо"]="thanks",
    ["спасиб"]="thanks", ["благодарю"]="thanks", ["сенкс"]="thanks",
    ["пж"]="pls", ["пжл"]="pls", ["плз"]="pls", ["плиз"]="pls", ["пжлст"]="pls", ["пжж"]="pls",
    ["пожалуйста"]="please", ["пажалста"]="please", ["пжт"]="pls",
    ["сорян"]="sorry", ["сорри"]="sorry", ["сор"]="sry",
    ["лол"]="lol", ["кек"]="kek", ["кекв"]="kek", ["рофл"]="rofl", ["рофлить"]="rofl",
    ["ору"]="lmao", ["ржу"]="lmao", ["ржака"]="lol", ["угар"]="hilarious", ["угарно"]="hilarious",
    ["ахахах"]="hahaha", ["ахахаха"]="hahaha", ["ахах"]="haha", ["хахах"]="hahaha", ["хаха"]="haha", ["хехе"]="hehe",
    ["норм"]="fine", ["нормально"]="fine", ["норма"]="fine", ["нормас"]="fine",
    ["ок"]="ok", ["окей"]="ok", ["окейно"]="ok", ["окейчик"]="ok",
    ["понял"]="got it", ["поняла"]="got it", ["поняли"]="got it", ["понятно"]="clear", ["ясно"]="clear",
    ["согласен"]="agree", ["согласна"]="agree", ["согласны"]="agree",
    ["вроде"]="kinda", ["вроде бы"]="seems", ["типа"]="like", ["типо"]="like",
    ["омг"]="omg", ["вау"]="wow", ["офигеть"]="wow", ["охренеть"]="damn",
    ["опа"]="oops", ["опачки"]="oops", ["упс"]="oops", ["ойой"]="uh oh",
    ["ага"]="yep", ["угу"]="uh-huh", ["неа"]="nope",
    ["блин"]="damn", ["блядь"]="damn", ["бля"]="damn", ["ёлки"]="darn", ["ёпта"]="damn",
    ["жесть"]="damn", ["ужас"]="horror", ["кайф"]="bliss", ["кайфово"]="awesome",
    ["круто"]="cool", ["крутяк"]="cool", ["класс"]="great", ["классно"]="cool", ["супер"]="super",
    ["збс"]="awesome", ["заебись"]="awesome", ["ахуенно"]="awesome", ["пушка"]="awesome",
    ["имба"]="OP", ["имбовый"]="OP", ["нерф"]="nerf", ["нерфили"]="nerfed",
    ["ништяк"]="cool", ["зачёт"]="nice", ["четко"]="solid", ["чётко"]="solid",
    ["годно"]="decent", ["годнота"]="good stuff", ["огонь"]="fire", ["топ"]="top", ["топчик"]="top tier",
    ["кринж"]="cringe", ["кринжово"]="cringe", ["душно"]="annoying", ["душнила"]="annoying guy",
    ["пздц"]="wtf", ["жиза"]="truth", ["база"]="facts",
    ["ппц"]="damn", ["офигенно"]="awesome",
    ["прикольно"]="cool", ["прикол"]="joke",
    ["хз"]="dunno", ["имхо"]="imo", ["кмк"]="imo",
    ["лан"]="ok", ["лана"]="ok",
    ["щас"]="now", ["сейчас"]="now", ["ща"]="now", ["щя"]="now", ["ща-ща"]="one sec", ["щаз"]="now",
    ["ток"]="just", ["токо"]="only", ["тока"]="only",
    ["юзать"]="use", ["юзаю"]="use", ["юзает"]="uses",
    ["инфа"]="info", ["пруф"]="proof", ["пруфы"]="proofs", ["тролль"]="troll", ["троллить"]="troll",
    ["жалко"]="pity", ["жаль"]="pity", ["печально"]="sad", ["обидно"]="hurtful",
    ["бомбит"]="mad", ["пригорает"]="mad",
    ["нзч"]="np", ["ништяк"]="cool",

    -- ================================================================
    -- Verbs (conjugated common forms)
    -- ================================================================
    ["иду"]="I go", ["идёт"]="goes", ["идут"]="going", ["идём"]="let's go", ["идёмте"]="let's go",
    ["пойду"]="I'll go", ["пойдёт"]="will go", ["пойдём"]="let's go",
    ["пошёл"]="went", ["пошла"]="went",
    ["пришёл"]="came", ["пришла"]="came", ["пришли"]="came",
    ["приду"]="I'll come", ["придёт"]="will come", ["придут"]="will come", ["придёшь"]="you coming",
    ["ушёл"]="left", ["ушла"]="left", ["ушли"]="left", ["уйду"]="I'll leave",
    ["уходи"]="go away", ["уходим"]="leaving",
    ["зашёл"]="came in", ["зашла"]="came in", ["зашли"]="came in", ["зайду"]="coming in",
    ["вышел"]="left", ["вышла"]="left", ["вышли"]="left", ["выйду"]="I'll leave",
    ["беги"]="run", ["бегите"]="run", ["бегу"]="running", ["бежит"]="running", ["бежим"]="running",
    ["лечу"]="flying", ["летит"]="flying",
    ["сижу"]="sitting", ["стою"]="standing", ["лежу"]="lying",
    ["сплю"]="sleeping", ["спит"]="sleeping", ["проснулся"]="woke up", ["проснулась"]="woke up",
    ["устал"]="tired", ["устала"]="tired", ["устали"]="tired",
    ["дай"]="give", ["дайте"]="give", ["дам"]="I'll give", ["даст"]="will give",
    ["дадут"]="will give", ["дал"]="gave", ["дала"]="gave", ["дали"]="gave",
    ["ждать"]="wait", ["жди"]="wait", ["ждите"]="wait", ["жду"]="waiting", ["ждёт"]="waits", ["ждут"]="waiting",
    ["подожди"]="wait", ["подождите"]="wait", ["погоди"]="wait",
    ["сделал"]="did", ["сделала"]="did", ["сделали"]="did", ["сделаю"]="I'll do", ["сделает"]="will do",
    ["сделаем"]="let's do", ["сделают"]="will do",
    ["делаю"]="doing", ["делает"]="doing", ["делаем"]="doing", ["делают"]="doing", ["делай"]="do",
    ["пишу"]="writing", ["пишет"]="writes", ["пишут"]="writing", ["пиши"]="write", ["напиши"]="write",
    ["написал"]="wrote", ["написала"]="wrote", ["написали"]="wrote", ["напишу"]="I'll write",
    ["сказал"]="said", ["сказала"]="said", ["сказали"]="said", ["скажу"]="I'll say", ["скажи"]="tell me",
    ["говорю"]="saying", ["говорит"]="says", ["говорят"]="they say",
    ["знаю"]="I know", ["знаешь"]="you know", ["знает"]="knows", ["знают"]="they know", ["знали"]="knew",
    ["хочу"]="I want", ["хочешь"]="you want", ["хочет"]="wants", ["хотят"]="they want",
    ["хотел"]="wanted", ["хотела"]="wanted", ["хотели"]="wanted",
    ["могу"]="I can", ["можешь"]="you can", ["можем"]="we can", ["могут"]="they can",
    ["мог"]="could", ["могла"]="could", ["могли"]="could",
    ["будет"]="will be", ["будут"]="will be", ["буду"]="I will", ["будешь"]="you will", ["будем"]="we will",
    ["был"]="was", ["была"]="was", ["были"]="were",
    ["помоги"]="help", ["помогите"]="help", ["помог"]="helped", ["помогу"]="I'll help",
    ["поможет"]="will help", ["поможем"]="we'll help", ["помогает"]="helps",
    ["смотри"]="look", ["смотрите"]="look", ["посмотри"]="look", ["посмотрим"]="we'll see",
    ["видел"]="saw", ["видела"]="saw", ["видели"]="saw", ["увидел"]="saw",
    ["слышал"]="heard", ["слышала"]="heard",
    ["понял"]="understood", ["понимаю"]="understand",
    ["думаю"]="I think", ["думаешь"]="you think", ["думает"]="thinks",
    ["начал"]="started", ["начали"]="started", ["начнём"]="let's start",
    ["закончил"]="finished", ["закончили"]="finished",
    ["забыл"]="forgot", ["забыли"]="forgot", ["помню"]="remember",
    ["нашёл"]="found", ["нашла"]="found", ["нашли"]="found",
    ["потерял"]="lost", ["потеряла"]="lost", ["остался"]="stayed", ["остались"]="stayed",
    ["убил"]="killed", ["убила"]="killed", ["убили"]="killed", ["убью"]="I'll kill",
    ["взял"]="took", ["взяла"]="took", ["взяли"]="took",
    ["кинь"]="send/throw", ["кинул"]="threw", ["кину"]="I'll send", ["кидай"]="send",
    ["качаю"]="leveling", ["качает"]="leveling", ["прокачал"]="leveled", ["качнуть"]="level",
    ["фармлю"]="farming", ["фармит"]="farms", ["фармим"]="farming", ["фармять"]="farming",
    ["нафармил"]="farmed",
    ["играю"]="playing", ["играет"]="plays", ["играем"]="playing", ["играют"]="playing",
    ["выиграл"]="won", ["выиграли"]="won", ["проиграл"]="lost", ["проиграли"]="lost",

    -- ================================================================
    -- Adjectives / adverbs
    -- ================================================================
    ["хороший"]="good", ["хорошая"]="good", ["хорошее"]="good", ["хорошие"]="good", ["хорошо"]="good",
    ["плохой"]="bad", ["плохая"]="bad", ["плохо"]="bad",
    ["неплохо"]="not bad", ["неплохой"]="decent",
    ["крутой"]="cool", ["крутая"]="cool", ["крутые"]="cool",
    ["классный"]="great", ["классная"]="great", ["классные"]="great",
    ["тупой"]="dumb", ["тупая"]="dumb", ["тупые"]="dumb", ["тупо"]="stupidly",
    ["быстрый"]="fast", ["быстрая"]="fast", ["быстро"]="quickly", ["быстрее"]="faster", ["быстрей"]="faster",
    ["медленный"]="slow", ["медленная"]="slow", ["медленно"]="slowly",
    ["лёгкий"]="easy", ["лёгкая"]="easy", ["легко"]="easy",
    ["сложный"]="hard", ["сложная"]="hard", ["сложно"]="hard", ["трудно"]="hard",
    ["лучший"]="best", ["лучшая"]="best", ["лучше"]="better",
    ["худший"]="worst", ["хуже"]="worse",
    ["большой"]="big", ["большая"]="big", ["большие"]="big",
    ["маленький"]="small", ["маленькая"]="small", ["маленькие"]="small",
    ["новый"]="new", ["новая"]="new", ["новые"]="new",
    ["старый"]="old", ["старая"]="old", ["старые"]="old",
    ["сильный"]="strong", ["сильная"]="strong", ["сильно"]="strongly",
    ["слабый"]="weak", ["слабая"]="weak", ["слабо"]="weakly",
    ["умный"]="smart", ["умная"]="smart", ["глупый"]="stupid", ["глупая"]="stupid",
    ["злой"]="angry", ["злая"]="angry", ["добрый"]="kind", ["добрая"]="kind",
    ["весёлый"]="fun", ["скучный"]="boring", ["скучно"]="boring",
    ["интересно"]="interesting", ["интересный"]="interesting",
    ["страшный"]="scary", ["страшно"]="scary", ["смешно"]="funny", ["смешной"]="funny",
    ["красивый"]="pretty", ["красивая"]="pretty",
    ["нормальный"]="normal", ["нормальная"]="normal",
    ["обычный"]="usual", ["обычно"]="usually",
    ["редкий"]="rare", ["редко"]="rarely", ["частый"]="frequent", ["часто"]="often",
    ["полный"]="full", ["пустой"]="empty",
    ["жив"]="alive", ["жива"]="alive", ["живы"]="alive",
    ["мёртв"]="dead", ["мёртвый"]="dead",
    ["серьёзно"]="seriously", ["прямо"]="right", ["именно"]="exactly",
    ["точно"]="exactly", ["реально"]="really", ["правда"]="really", ["честно"]="honestly",
    ["очень"]="very", ["сильно"]="strongly", ["крайне"]="extremely",
    ["совсем"]="completely", ["полностью"]="fully", ["совершенно"]="totally",
    ["довольно"]="quite", ["весьма"]="quite",
    ["немного"]="a bit", ["чуток"]="a bit", ["чутка"]="a bit",
    ["достаточно"]="enough", ["хватит"]="enough", ["слишком"]="too much",
    ["почти"]="almost", ["примерно"]="about", ["около"]="around", ["ровно"]="exactly",
    ["позже"]="later", ["раньше"]="earlier",
    ["тоже"]="also", ["также"]="also", ["только"]="only",
    ["иногда"]="sometimes", ["навсегда"]="forever",

    -- ================================================================
    -- Emotional / insult
    -- ================================================================
    ["идиот"]="idiot", ["дурак"]="fool", ["тупица"]="moron", ["козёл"]="jerk",
    ["урод"]="freak", ["мудак"]="asshole", ["долбоёб"]="moron", ["конченый"]="loser",
    ["лох"]="loser", ["лошара"]="loser", ["дебил"]="retard", ["быдло"]="scum",
    ["нуб"]="noob", ["нубас"]="noob", ["нубло"]="noob", ["нубяра"]="scrub",
    ["новичок"]="newbie", ["новенький"]="newbie", ["ракан"]="bad player",
    ["задрот"]="hardcore player", ["задротить"]="to grind hard", ["задротство"]="grinding",
    ["криворук"]="bad player", ["криворукий"]="uncoordinated", ["рукожоп"]="unskilled",
    ["профи"]="pro", ["про"]="pro", ["топовый"]="top tier",
    ["нагиб"]="domination", ["нагибать"]="dominate", ["нагнул"]="owned",
    ["тащит"]="carries", ["тащу"]="carrying", ["затащил"]="clutched",
    ["фейл"]="fail", ["зафейлил"]="failed", ["слив"]="throw", ["слился"]="gave up",
    ["вайн"]="whining", ["вайнить"]="whine", ["ныть"]="whine", ["нытик"]="whiner",
    ["плакса"]="crybaby", ["бомж"]="beggar", ["попрошайка"]="beggar",
    ["жадина"]="greedy", ["жлоб"]="greedy", ["ниндзя"]="ninja looter",
    ["токсик"]="toxic", ["токсичный"]="toxic", ["токсичная"]="toxic", ["неадекват"]="crazy",
    ["достали"]="fed up", ["достал"]="fed up", ["достала"]="fed up",
    ["бесит"]="pisses off", ["бесят"]="piss off", ["раздражает"]="irritates",
    ["заколебал"]="annoyed", ["заколебала"]="annoyed", ["заколебали"]="annoyed",
    ["задолбал"]="annoyed", ["задолбали"]="annoyed",
    ["хохлушка"]="(slur)", ["пидорасят"]="(vulgar)",
    ["нихуя"]="nothing (vulgar)", ["заебало"]="fed up (vulgar)",
    ["пиздак"]="(vulgar)", ["пиздабол"]="bullshitter (vulgar)", ["пиздешь"]="bullshit (vulgar)",
    ["кортавый"]="lisping (insult)", ["свинорылый"]="swine-faced (insult)",
    ["забей"]="forget it", ["забейте"]="forget it", ["пофиг"]="whatever",
    ["похрен"]="whatever", ["пофигу"]="whatever", ["фиолетово"]="don't care",
    ["плевать"]="don't care", ["всё равно"]="doesn't matter",
    ["отвали"]="get lost", ["отстань"]="leave me alone",
    ["заткнись"]="shut up", ["замолчи"]="shut up", ["молчи"]="be quiet",

    -- ================================================================
    -- Questions / closed class / small words
    -- ================================================================
    ["кто"]="who", ["кт"]="who",
    ["где"]="where", ["куда"]="where to", ["откуда"]="from where",
    ["когда"]="when", ["сегодня"]="today", ["завтра"]="tomorrow", ["вчера"]="yesterday",
    ["послезавтра"]="day after", ["позавчера"]="two days ago",
    ["как"]="how", ["почему"]="why", ["зачем"]="why",
    ["что"]="what", ["чё"]="what", ["чо"]="what", ["что-то"]="something", ["чёто"]="kinda",
    ["есть"]="have/any",
    ["нет"]="no", ["нету"]="none", ["да"]="yes",
    ["не"]="not", ["ни"]="neither", ["ничего"]="nothing", ["ничё"]="nothing",
    ["никто"]="nobody", ["никогда"]="never", ["нигде"]="nowhere",
    ["и"]="and", ["или"]="or", ["но"]="but", ["а"]="but", ["же"]="though",
    ["уже"]="already", ["ещё"]="still", ["ещё раз"]="once more", ["снова"]="again", ["опять"]="again",
    ["если"]="if", ["то"]="then", ["так"]="so",
    ["такой"]="such", ["такая"]="such", ["такие"]="such",
    ["какой"]="which", ["какая"]="which", ["какие"]="which",
    ["тут"]="here", ["здесь"]="here", ["сюда"]="here",
    ["там"]="there", ["туда"]="there",
    ["везде"]="everywhere",
    ["много"]="many", ["мало"]="few", ["все"]="all", ["всё"]="everything", ["всем"]="all",
    ["всегда"]="always",
    ["ну"]="well", ["ну и"]="and so",
    ["так что"]="so", ["поэтому"]="therefore", ["потому что"]="because",
    ["потому"]="because", ["из-за"]="because of", ["благодаря"]="thanks to",
    ["несмотря"]="despite", ["хотя"]="although", ["хоть"]="even though",
    ["зато"]="but", ["однако"]="however", ["тем не менее"]="nonetheless",
    ["всё же"]="still", ["всё таки"]="still", ["всётаки"]="still",
    ["короче"]="anyway", ["кстати"]="btw", ["кста"]="btw", ["кстате"]="btw",
    ["вообще"]="totally", ["в общем"]="basically", ["вообщем"]="basically", ["вобщем"]="basically",

    -- ================================================================
    -- Pronouns
    -- ================================================================
    ["я"]="I", ["ты"]="you",
    ["он"]="he", ["она"]="she", ["оно"]="it",
    ["мы"]="we", ["вы"]="you", ["они"]="they",
    ["мне"]="me", ["тебе"]="you", ["ему"]="him", ["ей"]="her", ["нам"]="us", ["вам"]="you", ["им"]="them",
    ["меня"]="me", ["тебя"]="you", ["его"]="him", ["её"]="her", ["нас"]="us", ["вас"]="you", ["их"]="them",
    ["мой"]="my", ["моя"]="my", ["моё"]="my", ["мои"]="my",
    ["твой"]="your", ["твоя"]="your", ["твоё"]="your", ["твои"]="your",
    ["наш"]="our", ["наша"]="our", ["наше"]="our", ["наши"]="our",
    ["ваш"]="your", ["ваша"]="your", ["ваше"]="your", ["ваши"]="your",
    ["свой"]="own", ["свои"]="own",
    ["этот"]="this", ["эта"]="this", ["это"]="this", ["эти"]="these",
    ["тот"]="that", ["та"]="that", ["те"]="those",
    ["себя"]="self", ["сам"]="self", ["сама"]="herself", ["сами"]="themselves",
    ["кто-то"]="someone", ["кто-нибудь"]="anyone",
    ["что-нибудь"]="anything", ["чтото"]="something", ["ктото"]="someone",

    -- ================================================================
    -- Prepositions
    -- ================================================================
    ["в"]="in", ["во"]="in", ["на"]="on/for", ["с"]="with", ["со"]="with",
    ["у"]="at", ["без"]="without", ["для"]="for", ["из"]="from",
    ["к"]="to", ["по"]="along/via", ["от"]="from", ["до"]="until",
    ["через"]="through/in", ["после"]="after", ["перед"]="before", ["при"]="at",
    ["над"]="over", ["под"]="under", ["про"]="about", ["о"]="about",
    ["об"]="(normal)",
    ["между"]="between",

    -- ================================================================
    -- Numbers
    -- ================================================================
    ["один"]="one", ["два"]="two", ["три"]="three", ["четыре"]="four", ["пять"]="five",
    ["шесть"]="six", ["семь"]="seven", ["восемь"]="eight", ["девять"]="nine", ["десять"]="ten",
    ["одиннадцать"]="11", ["двенадцать"]="12", ["тринадцать"]="13", ["пятнадцать"]="15",
    ["двадцать"]="20", ["тридцать"]="30", ["сорок"]="40", ["пятьдесят"]="50",
    ["шестьдесят"]="60", ["семьдесят"]="70", ["восемьдесят"]="80", ["девяносто"]="90",
    ["сто"]="100", ["двести"]="200", ["триста"]="300", ["четыреста"]="400",
    ["пятьсот"]="500", ["шестьсот"]="600", ["семьсот"]="700", ["восемьсот"]="800", ["девятьсот"]="900",
    ["тысяча"]="1000", ["миллион"]="million", ["миллиончик"]="million",
    ["первый"]="1st", ["второй"]="2nd", ["третий"]="3rd", ["четвёртый"]="4th", ["пятый"]="5th",
    ["последний"]="last", ["половина"]="half", ["четверть"]="quarter",
    ["полчаса"]="half hour", ["пол часа"]="half hour",

    -- ================================================================
    -- Time
    -- ================================================================
    ["теперь"]="now", ["скоро"]="soon", ["потом"]="later", ["недавно"]="recently",
    ["сек"]="sec", ["секунду"]="one sec", ["секунд"]="sec", ["секу"]="one sec", ["момент"]="moment",
    ["минут"]="min", ["минута"]="minute", ["минуту"]="a minute", ["минуты"]="minutes", ["минутку"]="one min",
    ["час"]="hour", ["часа"]="hours", ["часов"]="hours",
    ["день"]="day", ["дня"]="day", ["дней"]="days",
    ["неделя"]="week", ["месяц"]="month", ["год"]="year",
    ["утро"]="morning", ["утром"]="in the morning",
    ["днём"]="during the day",
    ["вечер"]="evening", ["вечером"]="in the evening", ["вечерами"]="in the evenings",
    ["ночь"]="night", ["ночью"]="at night",
    ["лвл"]="lvl", ["левел"]="lvl", ["уровень"]="level", ["уровня"]="lvl",
    ["мск"]="MSK", ["рт"]="RT",
    ["выходные"]="weekend", ["будни"]="weekdays",

    -- ================================================================
    -- Other nouns & misc
    -- ================================================================
    ["лутбокс"]="lootbox", ["голосование"]="voting", ["самоудаляется"]="self-deletes",
    ["почта"]="mail", ["почте"]="mail", ["посылка"]="mail", ["вложение"]="attachment",
    ["банк"]="bank", ["сумка"]="bag", ["рюкзак"]="backpack",
    ["мусор"]="junk", ["барахло"]="trash",
    ["разве"]="really?",
    ["кросфакс"]="crossfaction", ["кроссфакс"]="crossfaction",
    ["сторм"]="Storm server", ["мунка"]="Moonwell server", ["мунвелл"]="Moonwell",
    ["незервинг"]="Netherwing", ["незера"]="Netherwing",
    ["сирка"]="WoWCircle", ["вовсиркл"]="WoWCircle", ["варман"]="Warmane", ["варма"]="Warmane",
    ["печать"]="seal", ["печати"]="seal", ["печатка"]="seal",
    ["заплатки"]="armor patches", ["ставятся"]="are placed", ["ставится"]="is placed",
    ["ступень"]="level (rank)", ["классики"]="classic", ["долго"]="long",
    ["чел"]="dude", ["челик"]="dude", ["человек"]="person", ["люди"]="people",
    ["чувак"]="dude", ["чувачок"]="dude", ["бро"]="bro", ["братан"]="bro", ["братиш"]="bro",
    ["братишка"]="bro", ["пацан"]="dude", ["пацанчик"]="dude", ["пацаны"]="guys",
    ["народ"]="folks", ["ребята"]="guys", ["ребят"]="guys", ["парни"]="guys",
    ["девочки"]="girls", ["девчонки"]="girls", ["мальчики"]="boys",
    ["друг"]="friend", ["друзья"]="friends", ["товарищ"]="comrade", ["камрад"]="comrade",
    ["тиммейт"]="teammate", ["согилдиец"]="guildmate",
    ["сам"]="self", ["один"]="alone",
    ["окон"]="windows", ["окно"]="window",
    ["дела"]="stuff", ["работа"]="work", ["учёба"]="school",
    ["универ"]="uni", ["школа"]="school", ["экзамен"]="exam", ["сессия"]="exams",
    ["пара"]="class", ["урок"]="class",
    ["афк"]="afk", ["ирл"]="irl", ["ливнул"]="left", ["ливнула"]="left", ["ливаю"]="leaving",
    ["нагибает"]="dominates",
    ["точка"]="hearth", ["пых"]="hearth", ["пыхнул"]="hearthed",
    ["стража"]="guards", ["охрана"]="guards",
    ["трактирщик"]="innkeeper",
    ["петомец"]="pet", ["пет"]="pet", ["петка"]="pet", ["питомец"]="pet",
    ["минион"]="minion", ["демон"]="demon", ["имп"]="imp", ["импик"]="imp", ["бес"]="imp",
    ["войд"]="voidwalker", ["фелхант"]="felhunter",
    ["скелет"]="skeleton", ["элементаль"]="elemental",
    ["конь"]="mount", ["маунт"]="mount", ["маунты"]="mounts", ["скакун"]="mount",
    ["летак"]="flying mount", ["ездовое"]="mount",
    ["дракон"]="dragon", ["грифон"]="gryphon", ["вайверн"]="wyvern",
    ["скорость"]="speed",
    ["книга"]="book", ["книге"]="book", ["книги"]="books",
    ["макросы"]="macros", ["макрос"]="macro", ["свиток"]="scroll",
    ["лидер"]="leader", ["саб-лидер"]="assistant",
    ["ачивка"]="achievement", ["ачивки"]="achievements", ["ача"]="achievement",
    ["ачивмент"]="achievement", ["псих"]="achievement score",
    ["прокачка"]="leveling", ["апнуть"]="level up", ["апнулся"]="leveled up",
    ["прогать"]="progress", ["прогрессить"]="progress", ["прог"]="progress", ["пг"]="progress",

    -- Assorted
    ["бугров"]="big shots", ["бугры"]="big shots",
    ["удержать"]="retain", ["удерживать"]="to retain",
    ["качаются"]="leveling", ["качаться"]="to level",
    ["подучас"]="will learn", ["подучат"]="will learn",
    ["выучишь"]="you'll learn", ["выучить"]="to learn", ["учить"]="to learn",
    ["исход"]="outcome", ["избежен"]="unavoidable",
    ["фантазии"]="fantasies", ["меньшинстве"]="minority", ["меньшенстве"]="minority",
    ["реальность"]="reality", ["иллюзий"]="illusions",
    ["популярен"]="popular", ["получается"]="apparently",
    ["шиза"]="paranoia", ["мусорнулся"]="got trashed",
    ["свалили"]="bailed", ["свалил"]="bailed",
    ["насрать"]="don't care", ["ласты"]="flippers", ["склею"]="stick",
    ["написали"]="wrote", ["прощальные"]="farewell", ["посты"]="posts",
    ["конец"]="end", ["увидел"]="saw", ["увидеть"]="see", ["увидишь"]="you'll see",
    ["сводить"]="to take", ["некроситет"]="Necropolis (slang)",
    ["молча"]="silently", ["собираю"]="gathering", ["собирал"]="gathering",
    ["поднятся"]="will rise", ["подняться"]="to rise",
    ["покупать"]="to buy", ["купить"]="to buy",
    ["продавать"]="to sell", ["продать"]="to sell",
    ["сделать"]="to do",
    ["поиграем"]="let's play", ["сыграем"]="let's play",
    ["собака"]="dog",
    ["всем"]="all", ["везде"]="everywhere",
    ["вейпнулись"]="wiped", ["зарейдил"]="raided", ["зареспался"]="respawned",
    ["ресается"]="respawns", ["задонатил"]="donated",
    ["уже"]="already", ["ещё"]="still",

    -- Achievements / titles
    ["титул"]="title", ["префикс"]="title",

    -- ================================================================
    -- Russian gaming culture reactions
    -- ================================================================
    ["чсв"]="arrogant", ["чсвшник"]="arrogant",
    ["шарит"]="knows stuff", ["не шарю"]="don't get it", ["рубит"]="knows",
    ["в теме"]="in the know", ["не в теме"]="clueless",
    ["по ходу"]="seems like", ["походу"]="seems like",
    ["бомбит"]="raging", ["бомба"]="bomb",

    -- ================================================================
    -- Log-004 additions (real misses on v0.5 on WoWCircle TBC Global)
    -- ================================================================
    ["может"]="maybe", ["кому"]="to whom", ["пусть"]="let",
    ["гляди"]="look", ["язык"]="language",
    ["стяни"]="pull off (vulgar)", ["суток"]="24h",
    ["некий"]="some", ["чтоб"]="so that", ["чтобы"]="so that",
    ["администрации"]="admin team", ["администрация"]="administration",
    ["мут"]="mute",
    ["возможность"]="ability", ["возможности"]="abilities",
    ["которая"]="which", ["который"]="which", ["которое"]="which", ["которые"]="which",
    ["первой"]="first", ["второй"]="second",
    ["мб"]="maybe",
    ["убрали"]="removed", ["убрать"]="remove", ["убираю"]="removing",
    ["возможно"]="maybe",
    ["воспринимай"]="perceive",
    ["порой"]="sometimes",
    ["кажется"]="seems", ["казалось"]="seemed",
    ["чем"]="than",
    ["пиву"]="to beer", ["пиво"]="beer",
    ["помимо"]="besides",
    ["подумал"]="thought", ["подумала"]="thought", ["подумали"]="thought",
    ["видеть"]="to see", ["увидеть"]="to see",
    ["чате"]="chat", ["чат"]="chat",
    ["лежит"]="is there", ["лежат"]="are there",
    ["него"]="him", ["неё"]="her", ["них"]="them",
    ["гробнице"]="tombs", ["гробница"]="tomb",
    ["дают"]="give", ["даёт"]="gives", ["давали"]="gave", ["дают же"]="but they give",
    ["убить"]="kill", ["убивать"]="to kill",
    ["скорей"]="sooner", ["скорее"]="sooner",
    ["англ"]="English", ["англию"]="English", ["англа"]="English",
    ["топики"]="forum threads", ["топик"]="topic",
    ["бс"]="BS (premium?)",  -- server-specific shorthand, ambiguous
    ["ов"]="of (from)",      -- often truncation of "из"
    ["призват"]="summon",    -- truncated призвать
    ["ьпо"]="(typo по)",     -- common typo from the log
    ["20г"]="20g", ["10г"]="10g", ["50г"]="50g", ["100г"]="100g", ["500г"]="500g",
    ["1к"]="1K", ["2к"]="2K", ["3к"]="3K", ["4к"]="4K", ["5к"]="5K",
    ["10к"]="10K", ["20к"]="20K", ["50к"]="50K", ["100к"]="100K",

    -- Chat laughter variants of varying lengths
    ["ахахаха"]="hahaha", ["ахахахаха"]="hahaha",
    ["ахахахахаха"]="hahaha", ["ахахаххаха"]="hahaha",
    ["ахахахаххаха"]="hahaha", ["ахх"]="ha", ["ахаха"]="haha",

    -- Insults and derogatory terms seen in log (translated for completeness)
    ["хохлушку"]="(slur)", ["хохол"]="(slur)", ["хохлы"]="(slur)",
    ["пидорасят"]="(vulgar)", ["пидорас"]="(slur)",
    ["телочка"]="(slur for woman)",

    -- Extra common verbs and pronouns spotted
    ["собирал"]="gathering", ["собираем"]="gathering", ["собирать"]="to gather",
    ["убирает"]="removes", ["убирают"]="remove",
    ["зашёл"]="entered", ["заходи"]="come in", ["заходите"]="come in",
    ["его"]="his/him", ["ей"]="her",
    ["с нами"]="with us", ["без нас"]="without us",
    ["в сборе"]="gathered", ["все в сборе"]="all here",

    -- Server quality / nostalgia words
    ["мунка"]="Moonwell (slang)", ["мунку"]="Moonwell",
    ["незервинга"]="Netherwing (gen)",
    ["незервинг"]="Netherwing",

    -- Small fixes
    ["ыыы"]="hmmm", ["ыы"]="hm",
    ["ппцз"]="damn",
    ["удачи"]="good luck", ["удача"]="luck",

    -- ================================================================
    -- Log-005 single-token additions
    -- ================================================================
    -- Compass / "Far East" guild parts
    ["дальний"]="far", ["дальняя"]="far", ["дальнее"]="far", ["дальние"]="far",
    ["восток"]="east", ["востока"]="east", ["востоке"]="east",
    ["запад"]="west", ["север"]="north", ["юг"]="south",

    -- Recruitment verbs
    ["примет"]="accepts", ["принимает"]="accepts", ["принимаем"]="recruiting",
    ["принимают"]="accept", ["принимай"]="accept",

    -- Pronouns / determiners missed earlier
    ["новых"]="new", ["новый"]="new", ["нового"]="new", ["новые"]="new", ["новая"]="new",
    ["тех"]="those", ["этих"]="these",
    ["кого"]="whom", ["кому"]="to whom",
    ["какого"]="what", ["какому"]="what", ["каких"]="which",
    ["такого"]="such", ["такому"]="such", ["таких"]="such",

    -- Time nouns
    ["время"]="time", ["времени"]="time", ["временем"]="with time",
    ["часов"]="hours", ["минут"]="minutes",
    ["московского"]="Moscow", ["московское"]="Moscow",
    ["московский"]="Moscow", ["московскому"]="Moscow",

    -- Professions — inflected forms
    ["инженер"]="engineer", ["инженера"]="engineer",
    ["инженеру"]="engineer", ["инженером"]="engineer",
    ["ювелира"]="jeweler", ["ювелиру"]="jeweler", ["ювелиром"]="jeweler",
    ["алхимика"]="alchemist", ["алхимику"]="alchemist",
    ["кузнеца"]="blacksmith", ["кузнецу"]="blacksmith",
    ["кожевника"]="leatherworker", ["кожевнику"]="leatherworker",
    ["портного"]="tailor", ["портному"]="tailor",
    ["повара"]="cook", ["повару"]="cook",
    ["начертателя"]="scribe", ["начертанием"]="inscription",

    -- Enchant / materials
    ["зачарить"]="enchant", ["зачарю"]="I'll enchant",
    ["зачарит"]="will enchant", ["зачаровать"]="to enchant",
    ["реги"]="regs", ["рега"]="reg", ["регент"]="reagent", ["регенты"]="reagents",
    ["мат"]="mat", ["маты"]="mats", ["мата"]="mat", ["материалы"]="materials",
    ["компоненты"]="components",

    -- Level / class / form
    ["левел"]="level", ["левела"]="level", ["левелов"]="levels", ["левелы"]="levels",
    ["лвла"]="lvl", ["уровня"]="level",
    ["птица"]="bird", ["птицу"]="bird", ["птички"]="birds",
    ["летающая"]="flying", ["летающий"]="flying", ["летающее"]="flying",

    -- Partner / teammate slang
    ["напа"]="partner", ["напу"]="partner",
    ["напарник"]="partner", ["напарника"]="partner",
    ["напарнику"]="partner", ["напарником"]="partner", ["напарники"]="partners",

    -- Gaming nouns
    ["игр"]="games", ["игра"]="game", ["игре"]="game", ["игры"]="games", ["играм"]="games",

    -- Enchant slots / boot enchant stat
    ["бег"]="run speed", ["бега"]="run speed",
    ["к скорости"]="to speed", ["к бегу"]="to run speed",

    -- крит case variants
    ["криты"]="crit", ["критов"]="crits",

    -- Negative verbs + "suck"
    ["сосать"]="to suck", ["сосёт"]="sucks", ["сосу"]="I suck",
    ["отсос"]="suck (vulgar)", ["сосала"]="sucked",

    -- Forum / community
    ["форум"]="forum", ["форуме"]="forum", ["форума"]="forum",
    ["пост"]="post", ["поста"]="post", ["постик"]="post",
    ["тема"]="thread", ["темы"]="threads",

    -- Directional / temporal prepositions (already partial)
    ["от"]="from", ["до"]="until",

    -- Misc modal / particles
    ["обязательно"]="definitely", ["непременно"]="for sure",
    ["примерно"]="about", ["ровно"]="exactly",
    ["около"]="around",

    -- ================================================================
    -- Log-006 single-token additions
    -- ================================================================

    -- Difficulty slang (very common)
    ["гер"]="heroic", ["геры"]="heroics", ["геров"]="heroics", ["гере"]="heroic",
    ["нормалы"]="normals", ["нормалку"]="normal", ["нормалке"]="normal",
    ["нм"]="(normal)",
    ["дейлик"]="daily", ["дейлики"]="dailies",

    -- Dungeon: Узилище (prison, used colloquially for Arcatraz on ruRU servers)
    ["узилище"]="Arcatraz",  -- context-dependent; Arcatraz is the prison-themed dungeon
    ["узилищер"]="Arcatraz (heroic)",

    -- Summon / slot / reserve
    ["сум"]="summon", ["сумм"]="summon", ["саммон"]="summon",
    ["ласт"]="last", ["ласта"]="last boss", ["ласту"]="last boss",
    ["слот"]="slot", ["слоты"]="slots", ["слотов"]="slots",
    ["штаны"]="pants", ["штанов"]="pants", ["штанки"]="pants",
    ["рез"]="reserved", ["резерв"]="reserved", ["резерва"]="reserved",
    ["скип"]="skip", ["скипаем"]="skipping",
    ["ран"]="run",
    ["репа"]="rep", ["репой"]="rep", ["репы"]="rep", ["репу"]="rep", ["репе"]="rep",

    -- Days of the week (short Russian)
    ["пн"]="Mon", ["вт"]="Tue", ["ср"]="Wed", ["чт"]="Thu",
    ["пт"]="Fri", ["сб"]="Sat", ["вс"]="Sun",
    ["пнд"]="Mon", ["чтв"]="Thu",
    ["выходной"]="day off", ["выходные"]="weekend",

    -- Moscow / Irkutsk time
    ["иркутскому"]="Irkutsk", ["иркутское"]="Irkutsk", ["иркутск"]="Irkutsk",
    ["моск"]="Moscow", ["москв"]="Moscow",

    -- Guild short / communication
    ["ги"]="guild", ["гы"]="guild", ["гилде"]="guild", ["гилду"]="guild",
    ["связь"]="communication", ["обязательная"]="required", ["обязательный"]="required",
    ["дискорд"]="Discord", ["дискорда"]="Discord",
    ["доп"]="extra", ["доп."]="extra",
    ["вопросам"]="questions", ["вопроса"]="question", ["вопрос"]="question",
    ["походов"]="trips", ["поход"]="trip", ["походы"]="trips",
    ["помогаем"]="we help", ["помогают"]="they help",
    ["одеваем"]="we gear up", ["подсказываем"]="we advise",
    ["шамы"]="shamans", ["присты"]="priests",

    -- Arena-rating class shorthands
    ["ршам"]="resto shaman", ["рдру"]="resto druid",
    ["рпал"]="resto paladin", ["рприст"]="disc priest",
    ["энх"]="enhancement", ["энха"]="enhancement",
    ["фрост маг"]="frost mage",

    -- Quest / journal / accept / turn-in
    ["сдать"]="turn in", ["сдаёт"]="turns in", ["сдают"]="they turn in",
    ["сдаётся"]="gets turned in", ["сдал"]="turned in",
    ["выполнить"]="complete", ["выполнено"]="completed", ["выполнен"]="completed",
    ["выполнила"]="completed", ["выполнили"]="completed",
    ["журнале"]="journal", ["журнал"]="journal", ["журнала"]="journal",
    ["пропал"]="disappeared", ["пропала"]="disappeared", ["пропали"]="disappeared",
    ["искать"]="to search", ["искаться"]="to be found", ["искались"]="were found",
    ["найти"]="to find", ["нашли"]="found",
    ["закроют"]="will close", ["закрыли"]="closed", ["закрыт"]="closed",
    ["баджи"]="badges", ["баджа"]="badges", ["баджей"]="badges",
    ["месяца"]="month", ["месяц"]="month", ["месяцев"]="months",

    -- Instance helpers
    ["атюн"]="attunement", ["аттюн"]="attunement", ["аттюны"]="attunements", ["атюны"]="attunements",
    ["атюном"]="attunement", ["аттюном"]="attunement",
    ["барабаны"]="drums", ["барабанами"]="drums",
    ["санвела"]="Sunwell", ["санвел"]="Sunwell",
    ["каменор"]="Stonard",
    ["шатрах"]="in Shattrath", ["шатра"]="Shattrath",
    ["аутленд"]="Outland", ["аутленда"]="Outland", ["аутлэнд"]="Outland",

    -- Verbs
    ["помочь"]="to help", ["помощь"]="help",
    ["идти"]="to go", ["идёт"]="goes", ["идут"]="they go",
    ["бежать"]="to run", ["пробежать"]="run through", ["пробегать"]="run through",
    ["пробеги"]="run through", ["пробежит"]="will run",
    ["сумануться"]="get summoned", ["сумануться?"]="get summoned",
    ["поднять"]="raise/level", ["поднимать"]="to raise",
    ["думали"]="thought", ["думаем"]="we think",
    ["вступаешь"]="you join", ["вступай"]="join",
    ["ищешь"]="you search", ["ищу7"]="LF",
    ["было"]="was", ["бывает"]="happens",
    ["чаще"]="more often", ["всего"]="of all / in total",
    ["кем"]="whom (with)",

    -- Gear / chat slang
    ["ткань"]="cloth", ["ткани"]="cloth",
    ["руническая"]="runic",
    ["изначальная"]="primal", ["изначальный"]="primal",
    ["фолиант"]="tome", ["фолианта"]="tome",
    ["сотворения"]="of conjuring", ["сотворение"]="conjure",
    ["воды"]="water", ["вода"]="water",
    ["мощь"]="might", ["мощи"]="might",
    ["туз"]="ace",
    ["колода"]="deck", ["колоды"]="deck",
    ["зверей"]="beasts", ["зверь"]="beast",
    ["пустоты"]="void", ["пустоту"]="void",
    ["хлыст"]="crop/whip", ["хлыста"]="crop",
    ["ездовой"]="riding", ["ездовая"]="riding",
    ["назана"]="Nazan", ["назан"]="Nazan",

    -- Enchanting verbs
    ["чарит"]="enchants", ["чарнет"]="enchants", ["чарил"]="enchanted",
    ["инчант"]="enchant", ["инчатер"]="enchanter", ["инчантер"]="enchanter",

    -- Stats shorthand
    ["агилы"]="agility", ["агила"]="agility", ["агилу"]="agility",
    ["меткости"]="hit", ["меткость"]="hit",
    ["заклинания"]="spell", ["заклинаний"]="spells",
    ["выносливости"]="stamina", ["выносливость"]="stamina",
    ["небольшой"]="small", ["небольшая"]="small",
    ["браслетов"]="bracers", ["браслеты"]="bracers", ["браслет"]="bracer",

    -- Common chat verbs/phrases
    ["спамить"]="to spam", ["спамом"]="spam", ["спам"]="spam",
    ["задолбали"]="fed up", ["задолбал"]="fed up",
    ["гавно"]="shit", ["говно"]="shit", ["хрень"]="junk", ["херь"]="crap",
    ["игнорировать"]="ignore", ["игнор"]="ignore",
    ["дружно"]="together",
    ["толку"]="use/benefit", ["толк"]="sense",
    ["обьядиниться"]="unite", ["обьядинится"]="unite", -- typo variants
    ["объединиться"]="unite", ["объединитесь"]="unite",
    ["лидеров"]="leaders", ["лидера"]="leader", ["лидер"]="leader",
    ["эго"]="ego",
    ["своим"]="own", ["своими"]="own", ["своими своим"]="own",
    ["ядиница"]="unit (typo)", ["ядиноличник"]="loner (typo)",
    ["единица"]="unit", ["единоличник"]="loner",
    ["сёрные"]="sulfur (typo of серные)", ["серные"]="sulfur",
    ["топи"]="swamps",
    ["желающие"]="volunteers", ["желающий"]="volunteer",
    ["мертвый"]="dead", ["метвый"]="dead (typo)",
    ["онлайна"]="online",
    ["шо"]="what", -- Ukrainian variant
    ["говорить"]="to talk", ["говори"]="speak", ["говорим"]="we talk",

    -- Misc descriptors
    ["приоритет"]="priority",
    ["людях"]="people", ["людей"]="people", ["люди"]="people",
    ["сервере"]="server", ["сервак"]="server (slang)",
    ["важен"]="important", ["важно"]="important", ["важный"]="important",
    ["малых"]="small", ["маленьких"]="small",
    ["бонусы"]="bonuses", ["бонус"]="bonus",
    ["ценим"]="we value",
    ["розыск"]="wanted",

    -- Misc verbs
    ["попроси"]="ask", ["попросить"]="to ask", ["прошу"]="please/I ask",
    ["просто"]="simply", ["просто"]="just",
    ["делать"]="to do",
    ["сказать"]="to say",
    ["потаскать"]="drag around",
    ["умничаешь"]="being smart", ["умничай"]="be smart",

    -- Zones/places
    ["монастырь"]="Scarlet Monastery",
    ["монастыря"]="Scarlet Monastery",
    ["кладбище"]="Graveyard",
    ["лабиринты"]="Labyrinths",
    ["иглошкуры"]="Razorfen Kraul",
    ["баресне"]="Barrens (typo)", ["барренс"]="Barrens",

    -- Orders / scarlet
    ["алого"]="Scarlet", ["алый"]="Scarlet", ["алые"]="Scarlet",
    ["ордена"]="order", ["ордеан"]="order (typo)", ["орден"]="order",
    ["рыцари"]="knights", ["рыцарь"]="knight",

    -- Help calls
    ["элитного"]="elite", ["элитный"]="elite", ["элита"]="elite",
    ["моба"]="mob", ["мобы"]="mobs",

    -- Inventory
    ["сумки"]="bag", ["сумку"]="bag",

    -- Misc
    ["раздел"]="section", ["раздела"]="section",
    ["крики"]="shouts",
    ["аттюны"]="attunements",
    ["вариант"]="option", ["ленивых"]="lazy",
    ["локация"]="location",

    -- Abbreviations / possessives
    ["свою"]="my", ["свой"]="my",
    ["тиму"]="team", ["тима"]="team", ["тимы"]="team",

    -- Mistypes / rare
    ["свяяжись"]="contact (typo)", ["свяжись"]="contact",
    ["обьядиниться"]="unite (typo)",

    -- Stuff
    ["собирает"]="gathers", ["собирается"]="is gathering",

    -- Yes/no variants
    ["неет"]="nooo", ["даа"]="yesss",

    -- Tech
    ["гуглит"]="googles", ["гугл"]="google",

    -- Go/other
    ["гоу"]="go",

    -- Misc adjectives
    ["опытных"]="experienced", ["опытный"]="experienced",
    ["эффективного"]="effective", ["эффективный"]="effective",
    ["прохождения"]="progression", ["прохождение"]="progression",
    ["усиления"]="strengthening",

    -- Helper fillers
    ["видимо"]="apparently",
    ["нафиг"]="whatever", ["нафик"]="whatever",
    ["сдались"]="needed", -- "не сдались" = "nobody needs"

    -- ---- Final gap-fill from log-006 simulation ----
    ["можно"]="can", ["можна"]="can",
    ["нельзя"]="cannot",
    ["лока"]="warlock (acc)", ["локу"]="warlock",
    ["св"]="Steamvault",  -- in LFG "СВ норм" = Steamvault normal
    ["инвиз"]="stealth", ["инвизе"]="in stealth", ["в инвизе"]="in stealth",
    ["уйти"]="to leave", ["ушел"]="left", ["уходит"]="leaves",
    ["2х2"]="2v2", ["3х3"]="3v3", ["5х5"]="5v5",
    ["2на2"]="2v2", ["3на3"]="3v3", ["5на5"]="5v5",
    ["чет"]="kinda", ["чёт"]="kinda",
    ["которого"]="whom/which", ["которую"]="which",
    ["этим"]="this", ["этих"]="these",
    ["назад"]="ago",
    ["мосту"]="on the bridge", ["мост"]="bridge", ["моста"]="bridge",
    ["арен"]="arenas",
    ["туртлу"]="Turtle WoW", ["туртл"]="Turtle WoW",
    ["дрочило"]="(vulgar)",
    ["играют7"]="play?",  -- common typo: Shift+7 = "?" on EN layout
    ["делать7"]="do?",
    ["есть7"]="any?",
    ["играют"]="play",
    ["4у"]="I have",  -- typo "у меня" -> "4у меня"
    ["нгадо"]="need (typo)",
    ["гуглит"]="googles", ["погугли"]="google it",
    ["льдии"]="guild (truncated)",
    -- Latin 'c' instead of Cyrillic 'с' — keyboard layout mishap
    ["cум"]="summon",  -- latin c + cyrillic um
    ["cумм"]="summon",
    -- More verb / adjective conjugations
    ["купил"]="bought (m)", ["купила"]="bought (f)", ["купили"]="bought",
    ["пишет"]="writes", ["пишут"]="they write",
    ["вступаешь"]="you join",
    -- Misc slang
    ["юип"]="yep",
    -- Days-of-week full Russian
    ["понедельник"]="Monday", ["вторник"]="Tuesday", ["среда"]="Wednesday",
    ["четверг"]="Thursday", ["пятница"]="Friday", ["суббота"]="Saturday",
    ["воскресенье"]="Sunday",
    ["кару"]="Karazhan",  -- accusative missing in v0.6.2
    ["выбирайте"]="choose", ["выбирай"]="choose", ["выбери"]="choose",
    ["выбираем"]="we choose",

    -- =================================================================
    -- Full case-form coverage (v0.8.0)
    -- Russian declines nouns through 6 cases × 2 numbers. Without all
    -- forms a dictionary-based translator misses half of what players
    -- type. Below: systematic coverage for the high-frequency categories.
    -- Cases: Nom (кто?что?) / Gen (кого?чего?) / Dat (кому?чему?) /
    --        Acc (кого?что?) / Ins (кем?чем?) / Prep (о ком/чём?)
    -- =================================================================

    -- ---- INSTANCES (raids + 5-mans) full declension ----
    -- Karazhan (fem. like кара/кары/каре/кару/карой/каре)
    ["каре"]="in Karazhan", ["карой"]="with Karazhan", ["карах"]="in Karazhans",
    ["каражан"]="Karazhan", ["каражану"]="to Karazhan",
    ["каражаном"]="with Karazhan",
    -- Gruul (masc. animate: груул/груула/груулу/груула/груулом/грууле)
    ["груулу"]="to Gruul", ["груулом"]="with Gruul", ["грууле"]="at Gruul",
    -- Magtheridon (masc.)
    ["магтеридону"]="to Magtheridon", ["магтеридоном"]="with Magtheridon",
    ["магтеридоне"]="at Magtheridon",
    ["магтера"]="Magtheridon", ["магтеру"]="Magtheridon",
    ["магтером"]="Magtheridon", ["магтере"]="Magtheridon",
    -- Hyjal (masc.)
    ["хиджалу"]="to Hyjal", ["хиджалом"]="with Hyjal", ["хиджале"]="at Hyjal",
    -- Black Temple (abbreviation, doesn't decline — but "бтшка" does)
    ["бтшке"]="at Black Temple", ["бтшки"]="Black Temple",
    -- Serpentshrine
    ["серпенту"]="to Serpentshrine", ["серпенте"]="at Serpentshrine",
    -- Eye / The Eye (око / глаз)
    ["оку"]="to The Eye", ["оком"]="with The Eye", ["оке"]="at The Eye",
    ["глаза"]="The Eye", ["глазу"]="to The Eye", ["глазом"]="with The Eye",
    -- Zul'Aman (masc.)
    ["зуля"]="Zul'Aman", ["зулю"]="to Zul'Aman", ["зулем"]="with Zul'Aman",
    ["зуле"]="at Zul'Aman",
    ["зульамана"]="Zul'Aman", ["зульаману"]="to Zul'Aman",
    ["зульамане"]="at Zul'Aman", ["зульаманом"]="with Zul'Aman",
    -- Ramparts (fem. pl: рампы/рамп/рампам/рампы/рампами/рампах)
    ["рамп"]="Ramparts", ["рампам"]="to Ramparts",
    ["рампами"]="with Ramparts", ["рампах"]="in Ramparts",
    -- Blood Furnace (bф - доесn't decline; пекло крови / печи крови)
    ["пекла"]="of Blood Furnace", ["печи"]="Blood Furnace",
    -- Shattered Halls — Russian: "Разрушенные Залы"
    ["шхе"]="in Shattered Halls",
    -- Shadow Labs
    ["шме"]="in Shadow Labs",
    -- Mana-Tombs
    ["мту"]="Mana-Tombs", ["мтом"]="with Mana-Tombs", ["мте"]="at Mana-Tombs",
    ["мт-ах"]="in Mana-Tombs",
    -- Arcatraz
    ["арку"]="Arcatraz", ["аркой"]="with Arcatraz", ["арке"]="at Arcatraz",
    ["аркатраза"]="of Arcatraz", ["аркатразу"]="to Arcatraz",
    ["аркатразе"]="at Arcatraz", ["аркатразом"]="with Arcatraz",
    -- Botanica (fem.)
    ["ботанике"]="at Botanica", ["ботанику"]="to Botanica",
    ["ботаникой"]="with Botanica", ["ботаники"]="Botanica (gen)",
    -- Mechanar (masc.)
    ["механара"]="Mechanar (gen)", ["механару"]="to Mechanar",
    ["механаре"]="at Mechanar", ["механаром"]="with Mechanar",
    -- Sethekk Halls
    ["сетов"]="Sethekks", ["сетам"]="to Sethekk",
    ["сетками"]="with Sethekks", ["сетках"]="at Sethekks",
    -- Steamvault
    ["паровому"]="to Steamvault", ["паровым"]="with Steamvault",
    ["паровом"]="at Steamvault",
    -- Magisters' Terrace
    ["магтерасе"]="at Magisters' Terrace", ["магтерасу"]="to Magisters' Terrace",
    -- Underbog / Slave Pens in declension
    ["нижетопи"]="Underbog (gen)", ["нижетопью"]="with Underbog",
    ["загона"]="of Slave Pens", ["загону"]="to Slave Pens",
    ["загоне"]="at Slave Pens",

    -- ---- CLASSES (full masc. animate declension for singular/plural) ----
    -- Mage: маг/мага/магу/мага/магом/маге, маги/магов/магам/магов/магами/магах
    ["магу"]="to mage", ["магом"]="with mage", ["маге"]="at mage",
    ["магам"]="to mages", ["магами"]="with mages", ["магах"]="at mages",
    -- Hunter: хант
    ["ханту"]="to hunter", ["хантом"]="with hunter", ["ханте"]="at hunter",
    ["хантам"]="to hunters", ["хантами"]="with hunters", ["хантах"]="at hunters",
    ["хантов"]="hunters (gen)", ["ханты"]="hunters", ["хантеру"]="to hunter",
    ["хантером"]="with hunter", ["хантере"]="at hunter",
    -- Paladin: паль/паладин
    ["палю"]="to paladin", ["палем"]="with paladin", ["пале"]="at paladin",
    ["палям"]="to paladins", ["палями"]="with paladins", ["палях"]="at paladins",
    ["палу"]="to paladin", ["палом"]="with paladin",
    ["паладином"]="with paladin", ["паладине"]="at paladin",
    ["паладинам"]="to paladins", ["паладинами"]="with paladins",
    ["паладинах"]="at paladins",
    -- Warlock: лок
    ["локу"]="to warlock", ["локом"]="with warlock", ["локе"]="at warlock",
    ["локам"]="to warlocks", ["локами"]="with warlocks", ["локах"]="at warlocks",
    ["варлоку"]="to warlock", ["варлоком"]="with warlock",
    ["варлоке"]="at warlock", ["варлоки"]="warlocks",
    ["варлоков"]="warlocks", ["варлокам"]="to warlocks",
    -- Shaman: шам/шаман
    ["шаму"]="to shaman", ["шамом"]="with shaman", ["шаме"]="at shaman",
    ["шамам"]="to shamans", ["шамами"]="with shamans", ["шамах"]="at shamans",
    ["шаманом"]="with shaman", ["шамане"]="at shaman", ["шаманов"]="shamans",
    ["шаманам"]="to shamans", ["шаманами"]="with shamans", ["шаманах"]="at shamans",
    -- Priest: прист
    ["присту"]="to priest", ["пристом"]="with priest", ["присте"]="at priest",
    ["пристам"]="to priests", ["пристами"]="with priests", ["пристах"]="at priests",
    ["пристов"]="priests",
    -- Rogue: ро/рога/рожка/разбойник
    ["рогу"]="to rogue", ["рогой"]="with rogue", ["роге"]="at rogue",
    ["рогам"]="to rogues", ["рогами"]="with rogues", ["рогах"]="at rogues",
    ["разбойнику"]="to rogue", ["разбойником"]="with rogue",
    ["разбойнике"]="at rogue", ["разбойники"]="rogues",
    ["разбойников"]="rogues", ["разбойникам"]="to rogues",
    -- Warrior: варик/воин
    ["варику"]="to warrior", ["вариком"]="with warrior", ["варике"]="at warrior",
    ["варикам"]="to warriors", ["вариками"]="with warriors",
    ["воина"]="warrior", ["воину"]="to warrior", ["воином"]="with warrior",
    ["воине"]="at warrior", ["воинов"]="warriors",
    ["воинам"]="to warriors", ["воинами"]="with warriors",
    -- Druid: друид
    ["друиду"]="to druid", ["друидом"]="with druid", ["друиде"]="at druid",
    ["друидов"]="druids", ["друидам"]="to druids", ["друидами"]="with druids",
    ["друидах"]="at druids",

    -- ---- ROLES full declension ----
    -- Tank: танк/танка/танку/танка/танком/танке
    ["танку"]="to tank", ["танком"]="with tank", ["танке"]="at tank",
    ["танкам"]="to tanks", ["танками"]="with tanks", ["танках"]="at tanks",
    -- Healer: хил/хила/хилу/хила/хилом/хиле
    ["хилу"]="to healer", ["хилом"]="with healer", ["хиле"]="at healer",
    ["хилам"]="to healers", ["хилами"]="with healers", ["хилах"]="at healers",
    -- DPS (indeclinable acronym, covered)
    -- Hunter, etc. already above

    -- ---- GEAR SLOTS full declension ----
    -- Cloak: плащ (masc): плащ/плаща/плащу/плащ/плащом/плаще
    ["плащу"]="to cloak", ["плащом"]="with cloak", ["плаще"]="at cloak",
    ["плащи"]="cloaks", ["плащей"]="cloaks (gen)",
    -- Weapon: оружие (neut): оружие/оружия/оружию/оружие/оружием/оружии
    ["оружию"]="to weapon", ["оружием"]="with weapon", ["оружии"]="at weapon",
    -- Ring: кольцо (neut)
    ["кольцу"]="to ring", ["кольцом"]="with ring", ["кольце"]="at ring",
    ["колец"]="rings (gen)", ["кольцам"]="to rings", ["кольцами"]="with rings",
    -- Shield: щит
    ["щита"]="shield (gen)", ["щиту"]="to shield", ["щитом"]="with shield",
    ["щите"]="at shield", ["щитов"]="shields", ["щиты"]="shields",
    -- Armor: броня (fem.)
    ["брони"]="armor (gen)", ["броне"]="at armor", ["броню"]="armor (acc)",
    ["бронёй"]="with armor", ["броней"]="with armor",
    -- Helmet: шлем
    ["шлема"]="helm (gen)", ["шлему"]="to helm", ["шлемом"]="with helm",
    ["шлеме"]="at helm", ["шлемы"]="helms", ["шлемов"]="helms (gen)",
    -- Legs/pants: штаны (pl tantum)
    ["штанам"]="to pants", ["штанами"]="with pants", ["штанах"]="at pants",
    -- Belt: пояс
    ["пояса"]="belt (gen)", ["поясу"]="to belt", ["поясом"]="with belt",
    ["поясе"]="at belt", ["пояса"]="belts", ["поясов"]="belts",
    -- Boots: боты/сапоги
    ["ботам"]="to boots", ["ботами"]="with boots", ["ботах"]="on boots",
    ["ботов"]="of boots",
    ["сапог"]="boots (gen)", ["сапогам"]="to boots", ["сапогами"]="with boots",
    ["сапогах"]="in boots",
    -- Gloves: перчи/перчатки
    ["перчам"]="to gloves", ["перчами"]="with gloves", ["перчах"]="on gloves",
    ["перчаток"]="gloves (gen)", ["перчаткам"]="to gloves",
    ["перчатками"]="with gloves", ["перчатках"]="on gloves",
    -- Shoulders: плечи/наплечи
    ["плечам"]="to shoulders", ["плечами"]="with shoulders", ["плечах"]="on shoulders",
    ["наплечам"]="to shoulders", ["наплечами"]="with shoulders",
    -- Bracers: наручи/браслеты
    ["наручам"]="to bracers", ["наручами"]="with bracers", ["наручах"]="on bracers",
    ["браслетам"]="to bracers", ["браслетами"]="with bracers",
    ["браслетах"]="on bracers",
    -- Amulet/neck: амулет
    ["амулета"]="neck (gen)", ["амулету"]="to neck", ["амулетом"]="with neck",
    ["амулете"]="at neck",
    -- Trinket: тринкет/тринька
    ["тринкета"]="trinket (gen)", ["тринкету"]="to trinket", ["тринкетом"]="with trinket",
    ["триньке"]="at trinket", ["тринькой"]="with trinket",

    -- ---- STATS full declension ----
    -- Strength: сила/силы/силе/силу/силой/силе (fem)
    ["силы"]="strength (gen)", ["силе"]="at strength", ["силу"]="strength",
    ["силой"]="with strength", ["силах"]="at strengths",
    -- Agility: ловкость (fem on ь)
    ["ловкостью"]="with agility", ["ловкостям"]="to agilities",
    -- Intellect: интеллект (masc.)
    ["интеллекта"]="intellect (gen)", ["интеллекту"]="to intellect",
    ["интеллектом"]="with intellect", ["интеллекте"]="at intellect",
    ["инту"]="to int", ["интом"]="with int", ["инте"]="at int",
    -- Stamina: стамина (fem.)
    ["стамины"]="stamina (gen)", ["стамине"]="at stamina", ["стамину"]="stamina",
    ["стаминой"]="with stamina",
    -- Crit: крит (masc.)
    ["криту"]="to crit", ["критом"]="with crit", ["крите"]="at crit",
    -- Haste: хаст
    ["хаста"]="haste (gen)", ["хасту"]="to haste", ["хастом"]="with haste",
    ["хасте"]="at haste",
    -- Hit: хит
    ["хита"]="hit (gen)", ["хиту"]="to hit", ["хитом"]="with hit", ["хите"]="at hit",
    -- Spell power: спелл
    ["спеллу"]="to spellpower", ["спеллом"]="with spellpower", ["спелле"]="at spellpower",
    -- Resistance: резист
    ["резиста"]="resist (gen)", ["резисту"]="to resist", ["резистом"]="with resist",
    ["резисте"]="at resist",
    ["сопротивления"]="resistance", ["сопротивлению"]="to resistance",
    ["сопротивлением"]="with resistance", ["сопротивлении"]="at resistance",
    -- Rating: рейт
    ["рейта"]="rating (gen)", ["рейту"]="to rating", ["рейтом"]="with rating",
    ["рейте"]="at rating",
    ["рейтинга"]="rating (gen)", ["рейтингу"]="to rating",
    ["рейтингом"]="with rating", ["рейтинге"]="at rating",

    -- ---- MONEY & UNITS ----
    -- Gold: голд/золото
    ["голды"]="gold (gen)", ["голду"]="to gold", ["голдом"]="with gold",
    ["золота"]="gold (gen)", ["золоту"]="to gold", ["золотом"]="with gold",
    ["золоте"]="in gold",
    -- Silver / copper
    ["сильва"]="silver (gen)", ["сильву"]="to silver",
    -- Stack
    ["стака"]="stack", ["стаку"]="to stack", ["стаком"]="with stack",

    -- ---- KEY VERBS — top 20 full conjugation ----
    -- быть: "to be"
    ["будучи"]="being",
    -- идти: "to go"
    ["шёл"]="went (m)", ["шла"]="went (f)", ["шли"]="went (pl)",
    -- делать: "to do"
    ["делала"]="did (f)", ["делали"]="did (pl)",
    -- мочь: "to be able"
    ["могло"]="could (n)",
    -- знать: "to know"
    ["знала"]="knew (f)", ["знали"]="knew (pl)", ["знал"]="knew (m)",
    -- хотеть: "to want"
    ["хочется"]="want to", ["хотелось"]="wanted",
    -- видеть: "to see"
    ["видят"]="they see",
    -- слышать: "to hear"
    ["слышат"]="they hear", ["слышала"]="heard (f)", ["слышали"]="heard (pl)",
    -- помогать / помочь
    ["помогаю"]="I help", ["помогают"]="help",
    ["помоги же"]="help please", ["помогал"]="helped (m)",
    ["помогала"]="helped (f)", ["помогали"]="helped (pl)",
    -- дать: "to give"
    ["даёт"]="gives", ["даём"]="we give",
    -- купить/покупать
    ["куплен"]="bought", ["купленный"]="bought",
    ["покупаешь"]="you buy", ["покупают"]="they buy",
    ["покупал"]="was buying (m)", ["покупала"]="was buying (f)",
    -- продать/продавать
    ["продался"]="sold", ["продадут"]="will sell",
    ["продавал"]="was selling", ["продавала"]="was selling (f)",
    -- искать: "to search"
    ["искала"]="was looking (f)", ["искали"]="were looking (pl)",
    ["ищите"]="search", ["искать"]="to search",
    -- найти: "to find"
    ["найдем"]="we'll find", ["найдёте"]="you'll find", ["найдут"]="they'll find",
    ["нашёл"]="found (m)",
    -- ждать: "to wait"
    ["ждала"]="waited (f)", ["ждали"]="waited (pl)",
    ["ждёшь"]="you wait", ["ждите же"]="please wait",
    -- говорить / сказать
    ["говорил"]="was saying (m)", ["говорила"]="was saying (f)",
    ["говорили"]="were saying (pl)",
    ["скажем"]="we'll say", ["скажут"]="they'll say", ["сказано"]="said",
    -- писать / написать
    ["писал"]="was writing (m)", ["писала"]="was writing (f)",
    ["писали"]="were writing (pl)", ["напишем"]="we'll write",
    ["напишите"]="write (formal)", ["напишут"]="they'll write",
    -- думать
    ["думаем"]="we think", ["думают"]="they think",
    ["думал"]="thought (m)", ["думала"]="thought (f)", ["думали"]="thought (pl)",
    -- помнить
    ["помнили"]="remembered (pl)", ["помнят"]="they remember",
    ["помнила"]="remembered (f)",
    -- ходить
    ["ходил"]="went (m)", ["ходила"]="went (f)", ["ходили"]="went (pl)",
    ["ходит"]="goes", ["ходят"]="they go", ["ходи"]="go",
    -- брать / взять
    ["беру"]="I take", ["берём"]="we take", ["возьмите"]="take",
    ["брал"]="was taking (m)", ["брала"]="was taking (f)",
    -- убить / убивать
    ["убивал"]="was killing (m)", ["убивала"]="was killing (f)",
    ["убивали"]="were killing (pl)", ["убьёшь"]="you'll kill",
    ["убиваем"]="we kill", ["убил бы"]="would kill",
    -- играть
    ["играл"]="played (m)", ["играла"]="played (f)", ["играли"]="played (pl)",
    ["поиграл"]="played", ["поиграть"]="to play",
    -- качаться
    ["качались"]="were leveling (pl)", ["качалась"]="was leveling (f)",
    ["качался"]="was leveling (m)", ["покачался"]="leveled",
    -- писать в ЛС
    ["пишешь"]="you write",

    -- ---- ADJECTIVES — common ones get basic declension ----
    -- хороший (good, masc): хороший/хорошего/хорошему/хорошего/хорошим/хорошем
    ["хорошего"]="good (gen)", ["хорошему"]="to good", ["хорошим"]="with good",
    ["хорошем"]="at good",
    -- плохой
    ["плохого"]="bad (gen)", ["плохому"]="to bad", ["плохим"]="with bad",
    ["плохом"]="at bad",
    -- крутой
    ["крутого"]="cool (gen)", ["крутому"]="to cool", ["крутым"]="with cool",
    ["крутом"]="at cool",
    -- новый
    ["нового"]="new (gen)", ["новому"]="to new", ["новым"]="with new",
    ["новом"]="at new", ["новом же"]="in new",
    -- старый
    ["старого"]="old (gen)", ["старому"]="to old", ["старым"]="with old",
    ["старом"]="at old",
    -- большой
    ["большого"]="big (gen)", ["большому"]="to big", ["большим"]="with big",
    ["большом"]="at big",
    -- маленький
    ["маленького"]="small (gen)", ["маленькому"]="to small", ["маленьким"]="with small",
    ["маленьком"]="at small",
    -- сильный
    ["сильного"]="strong (gen)", ["сильному"]="to strong", ["сильным"]="with strong",
    ["сильном"]="at strong",
    -- слабый
    ["слабого"]="weak (gen)", ["слабому"]="to weak", ["слабым"]="with weak",

    -- ---- PRONOUNS full cases (patch holes) ----
    ["мною"]="by me", ["тобою"]="by you",
    ["нами"]="by us",
    ["собой"]="by self", ["себе"]="to self",
    ["им же"]="they", ["ей же"]="to her", ["ему же"]="to him",

    -- ---- NUMERALS full forms ----
    ["одного"]="one (gen)", ["одному"]="to one", ["одним"]="with one", ["одном"]="at one",
    ["двух"]="two (gen)", ["двум"]="to two", ["двумя"]="with two",
    ["трёх"]="three (gen)", ["трём"]="to three", ["тремя"]="with three",
    ["четырёх"]="four (gen)", ["четырём"]="to four", ["четырьмя"]="with four",
    ["пяти"]="five (gen)", ["пятью"]="with five",
    ["шести"]="six (gen)", ["шестью"]="with six",
    ["семи"]="seven (gen)", ["семью"]="with seven",
    ["восьми"]="eight (gen)", ["восемью"]="with eight",
    ["девяти"]="nine (gen)", ["девятью"]="with nine",
    ["десяти"]="ten (gen)", ["десятью"]="with ten",
    ["двадцати"]="20 (gen)", ["тридцати"]="30 (gen)",
    ["пятидесяти"]="50 (gen)", ["ста"]="100 (gen)",
    ["тысячи"]="1000 (gen)", ["тысяче"]="to 1000", ["тысячу"]="1000 (acc)",
    ["тысячей"]="with 1000",

    -- ---- KEY NOUNS: friends/people ----
    ["другом"]="with friend", ["друге"]="at friend",
    ["друзей"]="friends (gen)", ["друзьям"]="to friends", ["друзьями"]="with friends",
    ["друзьях"]="at friends",
    ["ребятам"]="to guys", ["ребятами"]="with guys", ["ребятах"]="about guys",
    ["пацанам"]="to guys", ["пацанами"]="with guys", ["пацанах"]="about guys",
    ["народу"]="to folks", ["народом"]="with folks", ["народе"]="at folks",

    -- ---- LOCATION & MOVEMENT ----
    ["городу"]="to city", ["городом"]="with city", ["городе"]="in city",
    ["городов"]="cities", ["городам"]="to cities", ["городах"]="in cities",
    ["локации"]="location (gen/pl)", ["локацию"]="location (acc)",
    ["локацией"]="with location",
    ["данжу"]="to dungeon", ["данжем"]="with dungeon", ["данже"]="at dungeon",
    ["инсту"]="to instance", ["инстом"]="with instance", ["инсте"]="at instance",
    ["рейду"]="to raid", ["рейдом"]="with raid", ["рейде"]="in raid",
    ["рейдам"]="to raids", ["рейдами"]="with raids", ["рейдах"]="in raids",
    ["пати"]="party",

    -- ---- TIME ----
    ["часу"]="to hour", ["часом"]="with hour", ["часе"]="at hour",
    ["часам"]="to hours", ["часами"]="with hours", ["часах"]="at hours",
    ["дню"]="to day", ["днем"]="by day", ["днях"]="days",
    ["недели"]="week (gen)", ["неделе"]="at week", ["неделю"]="week (acc)",
    ["неделей"]="with week", ["недель"]="weeks (gen)",
    ["месяцу"]="to month", ["месяцем"]="with month", ["месяце"]="in month",
    ["года"]="year (gen)", ["году"]="to year", ["годом"]="with year", ["годе"]="at year",
    ["лет"]="years",

    -- ---- QUEST / GAME ----
    ["квесту"]="to quest", ["квестом"]="with quest", ["квесте"]="at quest",
    ["квестам"]="to quests", ["квестами"]="with quests", ["квестах"]="in quests",
    ["книгу"]="book", ["книгой"]="with book",
    -- книги, книге already there
    ["ключа"]="key (gen)", ["ключу"]="to key", ["ключом"]="with key", ["ключе"]="at key",
    ["ключи"]="keys", ["ключей"]="keys (gen)",
    ["моба"]="mob (gen)", ["мобу"]="to mob", ["мобом"]="with mob", ["мобе"]="at mob",
    ["мобов"]="mobs (gen)", ["мобам"]="to mobs", ["мобами"]="with mobs",
    ["босса"]="boss (gen)", ["боссу"]="to boss", ["боссом"]="with boss",
    ["боссе"]="at boss", ["боссы"]="bosses", ["боссов"]="bosses",
    ["боссам"]="to bosses", ["боссами"]="with bosses",

    -- ---- GUILD / STATUS ----
    ["гильдией"]="with guild", ["гильдиях"]="in guilds", ["гильдиям"]="to guilds",
    ["гильдиями"]="with guilds", ["гильдий"]="guilds (gen)",
    ["аккаунта"]="account (gen)", ["аккаунту"]="to account",
    ["аккаунтом"]="with account", ["аккаунте"]="at account",
    ["сервера"]="server (gen)", ["серверу"]="to server", ["сервером"]="with server",

    -- ---- ENCHANT / CRAFT ----
    ["энчанта"]="enchant (gen)", ["энчанту"]="to enchant", ["энчантом"]="with enchant",
    ["гема"]="gem (gen)", ["гему"]="to gem", ["гемом"]="with gem", ["геме"]="at gem",
    ["гемов"]="gems (gen)", ["гемам"]="to gems", ["гемами"]="with gems",

    -- ---- MONEY COMPOUNDS ----
    ["донатом"]="with donation", ["донату"]="to donation",
    ["бонусу"]="to bonus", ["бонусом"]="with bonus", ["бонусе"]="at bonus",

    -- ---- COMMON CHAT TIME/ASPECT EXPRESSIONS ----
    ["скорее"]="faster", ["раньше всех"]="first",
    ["позже всех"]="last",
    ["этим же"]="with this",

    -- ---- WOW-SPECIFIC (zones already handled, adding missing forms) ----
    ["шаттрате"]="in Shattrath", ["шаттрату"]="to Shattrath",
    ["шаттратом"]="with Shattrath",
    ["ормрожара"]="of Orgrimmar",
    ["штормграду"]="to Stormwind", ["штормградом"]="with Stormwind",
    ["оргриммару"]="to Orgrimmar", ["оргриммаром"]="with Orgrimmar",
    ["даларану"]="to Dalaran", ["дараланом"]="with Dalaran",
    ["экзодаром"]="with Exodar", ["экзодаре"]="at Exodar",

    -- ---- BADGES / JUSTICE ----
    ["баджами"]="with badges", ["баджам"]="to badges", ["баджах"]="in badges",

    -- ---- ATTUNEMENT ----
    ["атюна"]="attunement (gen)", ["атюну"]="to attunement",
    ["атюне"]="at attunement",
    ["аттюна"]="attunement (gen)", ["аттюну"]="to attunement",
    ["аттюнам"]="to attunements", ["аттюнах"]="at attunements",

    -- ---- TOKENS / LOOT ----
    ["токена"]="token (gen)", ["токену"]="to token", ["токеном"]="with token",
    ["токене"]="at token", ["токены"]="tokens", ["токенов"]="tokens (gen)",
    ["токен"]="token",
    ["лута"]="loot (gen)", ["луту"]="to loot", ["лутом"]="with loot", ["луте"]="at loot",

    -- ---- "НАДО" verb forms ----
    ["надоело"]="bored of", ["надоели"]="fed up with",

    -- =================================================================
    -- Log-007 (rolling WoWChatLog.txt) gap fills
    -- =================================================================
    ["больше"]="more", ["меньше"]="less",    -- were missing in single form
    ["русич"]="Russian (folksy)", ["русичи"]="Russians", ["русичей"]="Russians (gen)",
    ["русичам"]="to Russians",
    ["сумануть"]="to summon", ["сумани"]="summon me", ["сумань"]="summon me",
    ["сумани меня"]="summon me",
    ["можете"]="you (pl) can", ["можем"]="we can",
    ["жднм"]="wait (typo: ждём)", ["ждем"]="we wait", ["ждёмс"]="waiting",
    ["пох"]="don't care (vulgar)", ["похер"]="don't care (vulgar)",
    ["похую"]="don't give a fuck (vulgar)",
    ["передавать"]="to pass/transfer", ["передать"]="to pass",
    ["передаю"]="I'm passing", ["передал"]="passed (m)",
    ["передала"]="passed (f)", ["передали"]="passed (pl)",
    ["передадим"]="we'll pass",
    ["че"]="what",                -- alongside "чё", "чо"
    ["бич"]="loser (slang)", ["бичи"]="losers (slang)",
    ["бичей"]="losers (gen)", ["бичам"]="to losers",
    ["пиздец"]="fucked up (vulgar)", ["пиздецу"]="to disaster (vulgar)",
    ["пиздеца"]="of disaster (vulgar)",

    -- Common vocative / filler particles also seen in logs
    ["слыш"]="hey/listen (slang)", ["слышь"]="hey/listen (slang)",
    ["ёмаё"]="oh my", ["ёпт"]="damn", ["ёпрст"]="damn (euphemism)",
    ["ептыть"]="damn",

    -- A few more high-frequency adverbs / connectors
    ["ниже"]="below", ["выше"]="above",
    ["среди"]="among",
    ["сразу"]="immediately", ["тотчас"]="at once",
    ["постоянно"]="constantly", ["редко же"]="rarely",

    -- =================================================================
    -- Log-008 individual words
    -- =================================================================

    -- Shadow Labs / dungeon talk
    ["тем"]="Shadow (Labs)", ["лаб"]="Labs",
    ["сумон"]="summon", ["сумона"]="summon",
    ["бос"]="boss", ["босу"]="to boss", ["босом"]="with boss",
    -- Bota / Bota cases
    ["бота"]="Botanica", ["боте"]="in Botanica",

    -- TBC NPCs / places
    ["трала"]="Thrall", ["тралла"]="Thrall", ["тралу"]="to Thrall",
    ["келя"]="Kael'thas (short)", ["келю"]="Kael'thas",
    ["бормотун"]="Murmur",
    ["девы"]="Maidens (Deadmines/realm)",  -- contextual
    ["дева"]="Maiden",

    -- Honor / PvP
    ["хонора"]="of honor", ["хонору"]="to honor",
    ["недельный"]="weekly", ["недельная"]="weekly", ["недельное"]="weekly",
    ["капает"]="caps", ["капнет"]="will cap", ["капнуло"]="capped",
    ["стопарнулся"]="stopped", ["стопаришь"]="you stop",
    ["перестал"]="stopped", ["перестала"]="stopped", ["перестали"]="stopped",
    ["начисляться"]="accrue", ["начисляет"]="accrues",
    ["потратил"]="spent", ["потратила"]="spent", ["потратили"]="spent",
    ["бей"]="hit", ["бейте"]="hit",
    ["килы"]="kills (slang)",

    -- Admin / formal Russian
    ["муты"]="mutes", ["мутов"]="mutes (gen)",
    ["отвечать"]="to answer", ["ответь"]="answer", ["ответьте"]="answer",
    ["вопросы"]="questions", ["вопросам"]="to questions",
    ["гражданин"]="citizen", ["гражданка"]="citizen (f)",
    ["начальник"]="chief", ["начальство"]="the chiefs",
    ["уважаемая"]="dear (f)", ["уважаемые"]="dear (pl)",
    ["уважаемый"]="dear (m)", ["уважаемых"]="dear (gen)",
    ["уважительно"]="respectfully",
    ["использование"]="use", ["использования"]="of use",
    ["ненормативной"]="non-normative",
    ["лексики"]="vocabulary", ["лексика"]="vocabulary",
    ["глобальном"]="global", ["глобальный"]="global", ["глобальная"]="global",
    ["выдаваться"]="be given", ["выдают"]="they give out",
    ["научитесь"]="you'll learn", ["научусь"]="I'll learn",
    ["научиться"]="to learn",
    ["общаться"]="to communicate", ["общаемся"]="we communicate",
    ["начну"]="I'll start", ["начнут"]="they'll start",
    ["поставленный"]="posed", ["поставленная"]="posed (f)",
    ["врятле"]="hardly", ["врядли"]="hardly", ["вряд ли"]="hardly",
    ["пиздуй"]="fuck off (vulgar)", ["пиздуйте"]="fuck off (pl)",
    ["раздаете"]="you hand out", ["раздают"]="they give out",

    -- Enchanting
    ["чарю"]="I enchant", ["чаришь"]="you enchant", ["чарят"]="they enchant",
    ["чарим"]="we enchant",
    ["наложение"]="application", ["наложения"]="of application",
    ["бесплатно"]="free", ["бесплатный"]="free",

    -- Items / crafting
    ["стабилизированный"]="stabilized", ["стабилизированная"]="stabilized (f)",
    ["этерниевый"]="eternium (adj)", ["этерниум"]="eternium",
    ["антикварный"]="antique", ["антикварная"]="antique (f)",
    ["сундук"]="chest", ["сундука"]="chest (gen)", ["сундуке"]="in chest",
    ["рубашка"]="shirt", ["рубашку"]="shirt (acc)",
    ["нежити"]="undead (gen)", ["нежить"]="undead",
    ["посох"]="staff",  -- already have; adding inflected forms
    ["божественного"]="divine (gen)", ["божественная"]="divine",
    ["вливания"]="infusion",
    ["аналог"]="analog/equivalent",
    ["кузнечка"]="blacksmith (f)", ["кузнечку"]="blacksmith (f, acc)",
    ["кузнечики"]="blacksmiths (f pl)",
    ["фуловая"]="fully geared (f)", ["фуловый"]="fully geared",

    -- Misc verbs/nouns
    ["дальше"]="further", ["дальний"]="far (adj)",
    ["почисти"]="clean", ["почистите"]="clean (pl)",
    ["кэш"]="cache", ["кэша"]="cache (gen)",
    ["водить"]="to run/lead", ["вожу"]="I lead", ["водят"]="they lead",
    ["побежду"]="I'll win",
    ["победили"]="won", ["победил"]="won (m)", ["победила"]="won (f)",
    ["победа"]="victory", ["победу"]="victory (acc)",
    ["войны"]="war/warriors", ["войну"]="war (acc)",
    ["короли"]="kings", ["король"]="king", ["королева"]="queen",
    ["названием"]="named", ["название"]="name", ["названия"]="names",
    ["названа"]="named (f)", ["назван"]="named (m)",
    ["быстра"]="fast (slang)",
    ["других"]="others", ["другими"]="with others", ["другим"]="to others",
    ["сервах"]="on servers",
    ["этом"]="this", ["том"]="that",
    ["таким"]="such (ins)", ["такими"]="such (ins pl)",
    ["нахуй"]="fuck (vulgar)", ["нахуй?"]="what the fuck",
    ["хуя"]="vulgar", ["хуй"]="vulgar",
    ["хуеш"]="bullshit (vulgar)",
    ["чисто"]="cleanly", ["чистый"]="clean", ["чистая"]="clean",

    -- Chat particles
    ["ясас"]="yasas (greek hi)", ["эт"]="this (slang)",
    ["некст"]="next", ["некста"]="next (gen)",
    ["еще"]="more/still",
    ["бесу"]="to imp/whim (slang)", ["бесом"]="by imp",
    ["базарю"]="I chat (slang)", ["базарит"]="chats",
    ["зондер"]="special", ["команда"]="team/command", ["команде"]="in team",

    -- Formal chat words
    ["волшебное"]="magic", ["волшебная"]="magic (f)",
    ["слово"]="word", ["слова"]="words", ["слову"]="to word",
    ["забыл"]="forgot (m)", ["забыла"]="forgot (f)", ["забыли"]="forgot (pl)",
    ["предателя"]="of the traitor", ["предатель"]="traitor",
    ["гибель"]="death/demise", ["гибели"]="of death",

    -- Arena class tags (missing from previous lists)
    ["хпал"]="holy paladin", ["хпала"]="holy paladin",
    ["хпалом"]="with holy pal",
    ["вару"]="to warrior", ["варом"]="with warrior", ["варе"]="at warrior",

    -- Realm / location fragments
    ["девы"]="Devy (slang/realm)",

    -- Remaining loose ends
    ["2с"]="2v2", ["3с"]="3v3", ["5с"]="5v5",
    ["остальных"]="others (gen)", ["остальные"]="others", ["остальное"]="rest",
    ["закрыт"]="closed", ["закрыта"]="closed (f)", ["закрыто"]="closed (n)",
    ["регайте"]="reg (imperative pl)", ["региум"]="let's reg",
    ["фазы"]="phases", ["фазу"]="phase (acc)",

    -- Bug word that appeared
    ["исполнении"]="performance (prep)", ["исполнение"]="performance",

    -- Last-mile tokens from WoWChatLog.txt
    ["тан"]="tank (short)",
    ["поменяю"]="I'll exchange", ["поменяй"]="exchange",
    ["будьте"]="be (pl)", ["будь"]="be",
    ["любезный"]="kind (m)", ["любезная"]="kind (f)",
    ["любезно"]="kindly",
    ["сення"]="today (slang)", ["сёдня"]="today (slang)",
    ["ответ"]="answer", ["ответа"]="answer (gen)", ["ответу"]="to answer",
    ["чи"]="or (Ukr particle)",
    ["программер"]="programmer", ["программист"]="programmer",
    ["деняк"]="money (slang)", ["денег"]="money (gen)", ["деньгам"]="to money",
    ["аррену"]="arena (typo)",
    ["слабые"]="weak (pl)", ["слабые"]="weak", ["слабых"]="weak (gen)",
    ["сатира"]="satire",
    ["ебаная"]="fucking (vulgar f)", ["ебаный"]="fucking (vulgar m)",
    ["ебать"]="to fuck (vulgar)",
    ["сфера"]="sphere", ["сферы"]="spheres",
    ["фаст"]="fast", ["фасту"]="to fast",
    ["бомжи"]="beggars", ["бомжей"]="beggars (gen)",
    ["узнать"]="to find out", ["узнаю"]="I'll find out", ["узнал"]="found out",
    ["трансфер"]="transfer", ["трансфера"]="transfer (gen)",
    ["пришел"]="came (m)", ["пришла"]="came (f)",

    -- Misc verb forms
    ["возьмёмся"]="let's take", ["беритесь"]="take",
    ["увидимся"]="see you", ["увидимся позже"]="see you later",

    -- =================================================================
    -- Log-009 (live WoWChatLog.txt, 394 unique Russian lines, arg/drama
    -- session with song lyrics, insults, idiomatic Russian, jeer
    -- phrases, movie/pop-culture references).
    -- Basic words that were surprisingly missing: наверное, тогда,
    -- давай, раз, конечно (as standalone), etc.
    -- =================================================================
    -- Base common words missing
    ["наверное"]="probably", ["наверно"]="probably",
    ["тогда"]="then",
    ["конечно"]="of course", ["конеш"]="of course",
    ["давай"]="come on", ["давайте"]="come on (pl)",
    ["давайся"]="let's go",
    ["раз"]="once/time", ["разы"]="times", ["разов"]="times (gen)",
    ["будто"]="as if", ["как будто"]="as if",
    ["иначе"]="otherwise",
    ["тихо"]="quietly", ["тихий"]="quiet (m)", ["тихая"]="quiet (f)",

    -- Discord / tech
    ["дс"]="Discord", ["с дс"]="from Discord", ["в дс"]="on Discord",
    ["кикнули"]="kicked",  -- plural past

    -- Argument / drama vocabulary (this session had a flame war)
    ["базар"]="talk (slang)", ["за базар"]="for your talk",
    ["за свой базар"]="for your words",
    ["отвечаешь"]="you answer", ["не отвечаешь"]="you don't answer",
    ["отвечай"]="answer", ["отвечать"]="to answer",
    ["отевет"]="answer (typo)",
    ["обещал"]="promised (m)", ["обещала"]="promised (f)", ["обещали"]="promised (pl)",
    ["гму"]="to GM", ["с гм"]="with GM",
    ["матерится"]="cursing", ["материться"]="to curse",
    ["мат"]="profanity",
    ["разивите"]="typo (develop)", ["развивайте"]="develop",
    ["куток"]="corner (slang)",
    ["обиженных"]="offended (gen pl)", ["обиженный"]="offended",
    ["кидают"]="they throw", ["кидают везде"]="kicked from everywhere",
    ["раскидаешь"]="you'll throw", ["раскидай"]="throw",
    ["слабее"]="weaker", ["слабости"]="weakness",
    ["слабый"]="weak (m)", ["слабая"]="weak (f)",
    ["вряд"]="hardly", ["ли"]="(question particle)",
    ["лишний"]="extra", ["лишняя"]="extra (f)",
    ["доказывает"]="proves", ["доказать"]="to prove", ["доказал"]="proved (m)",
    ["пу"]="pu (onomatopoeia)",
    ["ааа"]="aaa", ["аааа"]="aaaa", ["аааааа"]="aaaaaa",
    ["факты"]="facts", ["факт"]="fact",
    ["расходимся"]="we're done here",
    ["сенсации"]="sensation (gen)", ["сенсация"]="sensation",
    ["не будет"]="won't be",
    ["причем"]="by the way", ["причём"]="by the way",
    ["разьеб"]="fuckup (vulgar)", ["разъеб"]="fuckup (vulgar)",
    ["ждал"]="waited (m)",
    ["наконец"]="finally", ["наконец-то"]="finally",
    ["послушать"]="to listen", ["слушать"]="to listen",
    ["разнос"]="scolding",
    ["опущенный"]="humiliated", ["опущен"]="humiliated",
    ["пвешные"]="PvE players", ["пвешник"]="PvE player",
    ["почитаю"]="I'll read", ["почитать"]="to read",
    ["рот"]="mouth", ["рота"]="mouth (gen)", ["рту"]="in mouth",
    ["публично"]="publicly",
    ["пойму"]="I'll understand", ["поймёшь"]="you'll understand",
    ["непойму"]="don't understand",
    ["херовый"]="shitty (m)", ["херовая"]="shitty (f)", ["херово"]="shittily",
    ["нахуя"]="why the fuck (vulgar)",

    -- Items / gear
    ["узда"]="bridle", ["узду"]="bridle (acc)",
    ["белого"]="white (gen)", ["белый"]="white", ["белая"]="white (f)",
    ["жеребца"]="stallion (gen)", ["жеребец"]="stallion",
    ["роль"]="role", ["роли"]="roles",
    ["сундуков"]="chests (gen pl)",
    ["закинул"]="threw in (m)", ["закинула"]="threw in (f)",
    ["шекелей"]="shekels (money slang)", ["шекель"]="shekel",
    ["трансфер"]="transfer", ["трансфера"]="transfer (gen)",
    ["перса"]="character (gen)", ["перс"]="character",
    ["с шторма"]="from Storm (server)",
    ["шторма"]="Storm (server gen)",

    -- Cultural / pop
    ["фильм"]="movie", ["фильма"]="movie (gen)", ["фильмы"]="movies",
    ["свадебную"]="wedding (acc f)", ["свадебная"]="wedding (f)",
    ["вазу"]="vase (acc)", ["ваза"]="vase",
    ["глянь"]="look (slang imp)",
    ["река"]="river", ["реки"]="rivers",
    ["берега"]="shores/banks",
    ["закате"]="at sunset", ["закат"]="sunset",
    ["крутые"]="cool (pl)", ["крутой"]="cool",
    ["неси"]="carry", ["носи"]="carry",
    ["меня"]="me",
    ["тебя"]="you",
    ["имени"]="by name", ["имя"]="name",
    ["ключевой"]="key (adj)", ["ключевая"]="key (f)",
    ["водой"]="by water", ["воде"]="in water",
    ["напои"]="give to drink", ["напоить"]="to give drink",
    ["позови"]="call", ["позову"]="I'll call",
    ["грусть"]="sadness", ["печаль"]="sorrow", ["грусть-печаль"]="sadness",
    ["черкизовский"]="Cherkizovsky (brand)",

    -- More conjugations / forms
    ["мной"]="by me", ["со мной"]="with me",
    ["надо же"]="what do you know",
    ["ясно"]="clear",

    -- Misc
    ["кстати"]="by the way",

    -- Drama session idioms (still from log-009)
    ["иди"]="go",
    ["бы"]="would", ["б"]="would",
    ["открыть"]="to open", ["открывать"]="to open (imp)",
    ["открой"]="open", ["открываю"]="I open",
    ["уф"]="uf (sigh)",
    ["маньяк"]="maniac", ["маньяка"]="maniac (gen)",
    ["непристойности"]="indecencies", ["непристойность"]="indecency",
    ["пики"]="pics", ["пик"]="pic",
    ["шлет"]="sends", ["шлёт"]="sends", ["шлёшь"]="you send",
    ["согласился"]="agreed (m)", ["согласилась"]="agreed (f)",
    ["петушином"]="rooster (slang)",
    ["словарь"]="dictionary", ["словаря"]="dictionary (gen)",
    ["впадлу"]="too lazy (slang)", ["впадло"]="too lazy",
    ["инчат"]="enchant",
    ["кинули"]="threw (pl)",
    ["трагедия"]="tragedy", ["трагедия)"]="tragedy",
    ["тредс"]="Threads (social)", ["тредсе"]="on Threads",
    ["читал"]="read (m)", ["читала"]="read (f)", ["читали"]="read (pl)",
    ["путин"]="Putin",
    ["сдох"]="died (vulgar m)", ["сдохла"]="died (vulgar f)",
    ["сдохли"]="died (vulgar pl)",
    ["мах"]="Makh (name)",
    ["читать"]="to read", ["почитай"]="read (imp)", ["почитайте"]="read (pl imp)",
    ["прекращайте"]="stop it (pl)", ["прекрати"]="stop",
    ["создадут"]="will create", ["создадим"]="we'll create",
    ["оперу"]="Opera (Kara boss)",  -- Big Bad Wolf / Opera Event in Karazhan
    ["опера"]="Opera (Kara)",
    ["бурги"]="burgs (slang)", ["бурга"]="burg",
    ["даже"]="even",
    ["любым"]="any (inst)", ["любого"]="any (gen)", ["любую"]="any (f acc)",
    ["любыми"]="any (inst pl)",
    ["поговорю"]="I'll talk", ["поговорим"]="let's talk",
    ["забанили"]="banned (pl)", ["забанил"]="banned (m)", ["забанила"]="banned (f)",
    ["навечно"]="forever", ["навсегда"]="forever",
    ["вот"]="here's/well",
    ["тобой"]="by you", ["с тобой"]="with you",
    ["фуфлометы"]="fakes (slang)", ["фуфломет"]="fake (slang)",
    ["вся"]="all (f)", ["вся ги"]="whole guild",
    ["жалуются"]="complaining", ["жалуется"]="complains",
    ["жалоба"]="complaint", ["жалобы"]="complaints",
    ["баганный"]="bugged (m)", ["баганная"]="bugged (f)",
    ["исправьте"]="fix (pl imp)", ["исправь"]="fix",
    ["исправить"]="to fix",
    ["инфа"]="info",  -- probably dup but safe
    ["на форуме"]="on forum",  -- phrase-ish

    -- Misc high-freq
    ["ги"]="guild (slang short)",  -- already had, reinforcing
    ["оперу"]="Opera Event",
    ["отдам"]="I'll give",
    ["никому"]="to nobody",
    ["многие"]="many",
    ["мало кто"]="few",
    ["никто не"]="nobody",

    -- "Если б" conditional
    ["если б"]="if only", ["если бы"]="if",
    ["было бы"]="would be",
    ["я б"]="I would", ["я бы"]="I would",

    -- =================================================================
    -- Log-latest single-token additions (WoWChatLog.txt Apr 19-21)
    -- =================================================================

    -- Zones / dungeons / bosses
    ["хилсбрад"]="Hillsbrad",
    ["сеттеки"]="Sethekk",
    ["шл"]="Shadow Labyrinth (SL)",
    ["анзу"]="Anzu (Sethekk)",
    ["паров"]="Steamvault",
    ["паро"]="Steam (dungeon)",
    ["паровые"]="Steam (Steamvaults)",
    ["паровая"]="Steam (dungeon)",
    ["тралмар"]="Thrallmar",
    ["траллмар"]="Thrallmar",
    ["шторме"]="Stormwind (prep)",
    ["оргримаре"]="Orgrimmar (prep)",
    ["награнде"]="Nagrand (prep)",
    ["награнда"]="Nagrand Arena",
    ["гранд"]="grand (Nagrand)",
    ["залы"]="halls",
    ["залах"]="halls (prep)",
    ["гробницы"]="tombs",
    ["уварус"]="Uvarus (boss)",
    ["адало"]="Adal",
    ["майден"]="Maiden (Kara boss)",
    ["оперы"]="Opera (gen)",
    ["груля"]="Gruul (slang)",
    ["узилищер"]="Arcatraz (slang)",

    -- Classes / roles shorthand
    ["ппал"]="prot paladin",
    ["вар"]="warrior (slang)",
    ["сова"]="moonkin druid",
    ["рдру"]="resto druid",
    ["рпал"]="holy paladin",

    -- Acronyms / internet
    ["вк"]="VK (social)",
    ["нпс"]="NPC",
    ["фп"]="flight point",
    ["хд"]="xD",
    ["рф"]="Russia",
    ["свп"]="Sunwell Plateau",
    ["т6"]="T6",
    ["а4"]="arena season 4",
    ["чв"]="chV",

    -- Verbs
    ["фарм"]="farm",
    ["пишите"]="write (pl imp)",
    ["пишем"]="we write",
    ["пиши"]="write (imp)",
    ["играть"]="to play",
    ["играли"]="played (pl)",
    ["перенос"]="transfer",
    ["переносят"]="transferring (pl)",
    ["переноs"]="transfer (typo)",
    ["перено"]="transfer",
    ["вступить"]="to join",
    ["вступлю"]="I'll join",
    ["вступишь"]="you'll join",
    ["похилю"]="I'll heal",
    ["хилю"]="I heal",
    ["танканите"]="tank (pl imp)",
    ["кошмарить"]="to torment",
    ["гонять"]="to chase/drive",
    ["гонят"]="(they) chase",
    ["гоните"]="chase (pl)",
    ["принеси"]="bring (imp)",
    ["подскажите"]="tell me (pl)",
    ["подскажет"]="will tell",
    ["подать"]="to submit",
    ["регай"]="register (imp)",
    ["регаем"]="we register",
    ["побил"]="beat (m)",
    ["бить"]="to beat",
    ["били"]="beat (pl past)",
    ["качнулись"]="leveled (pl)",
    ["делаешь"]="you do",
    ["делал"]="did (m)",
    ["назови"]="name (imp)",
    ["вошли"]="entered (pl)",
    ["развивай"]="develop (imp)",
    ["молчали"]="were silent (pl)",
    ["замолчали"]="went silent (pl)",
    ["пострадал"]="suffered",
    ["превратимся"]="we'll turn into",
    ["жил"]="lived (m)",
    ["изучить"]="to learn",
    ["показывает"]="shows",
    ["пойдет"]="will go",
    ["идем"]="we're going",
    ["отбить"]="to reclaim",
    ["подождать"]="to wait",
    ["появляются"]="appear (pl)",
    ["увеличить"]="to increase",
    ["сменить"]="to change",
    ["практикует"]="practices",
    ["включил"]="turned on (m)",
    ["одела"]="dressed (f)",
    ["одели"]="dressed (pl)",
    ["одевали"]="were dressing (pl)",
    ["одевала"]="was dressing (f)",
    ["отпишитесь"]="reply (pl imp)",
    ["заберать"]="to take",
    ["кидал"]="threw (m)",
    ["создал"]="created (m)",
    ["докачаемся"]="we'll level up",
    ["запустили"]="launched (pl)",
    ["промолчал"]="kept silent (m)",
    ["проверить"]="to check",
    ["рофлите"]="(you) ROFL",
    ["прекращайте"]="stop it (pl)",
    ["читай"]="read (imp)",
    ["выбрать"]="to choose",
    ["выкупить"]="to buy out",
    ["задонить"]="to donate",
    ["записать"]="to record",
    ["соглашайтесь"]="agree (pl imp)",
    ["чешиш"]="(you) wag",
    ["напишет"]="will write",
    ["отошли"]="left (pl)",
    ["отойдём"]="we'll step aside",
    ["подсекать"]="to hook (fish)",
    ["срывается"]="breaks off",
    ["стоишь"]="(you) stand",
    ["говоришь"]="(you) say",
    ["киданул"]="scammed (m)",
    ["отдавали"]="were giving (pl)",
    ["собирать"]="to gather",
    ["справляется"]="copes",
    ["защемило"]="ached",
    ["отталкиваюсь"]="go off (prices)",
    ["сдох"]="died (vulgar m)",
    ["разккачивайте"]="don't rock (imp)",
    ["вбухал"]="dumped (money)",
    ["гунди"]="whine (imp)",
    ["лежит"]="lies/sits",
    ["пашут"]="they work",
    ["работают"]="work (pl)",
    ["шарю"]="I get it / I'm good at",
    ["думает"]="thinks",
    ["шло"]="went (n)",
    ["шли"]="went (pl)",

    -- Nouns
    ["жизнь"]="life",
    ["бой"]="fight",
    ["боев"]="fights (gen pl)",
    ["праздник"]="holiday",
    ["яйцо"]="egg",
    ["старт"]="start",
    ["старта"]="start (gen)",
    ["ник"]="nickname",
    ["дальность"]="distance",
    ["далность"]="distance (typo)",
    ["отдаление"]="distance away",
    ["камеры"]="camera (gen)",
    ["камеру"]="camera (acc)",
    ["прорисовки"]="rendering (gen)",
    ["рублей"]="rubles",
    ["группу"]="group (acc)",
    ["группе"]="group (prep)",
    ["групе"]="group (typo)",
    ["анонса"]="announcement (gen)",
    ["вайпа"]="wipe (gen)",
    ["цепочка"]="chain",
    ["цепочку"]="chain (acc)",
    ["хранители"]="keepers",
    ["реклама"]="advertisement",
    ["рекламу"]="advertisement (acc)",
    ["рекламы"]="advertisement (gen)",
    ["мошеничество"]="fraud (misspelled)",
    ["мошенник"]="fraud (person)",
    ["дешевка"]="cheap-ass",
    ["дилдо"]="dildo",
    ["анрол"]="offspec roll",
    ["анролом"]="as offspec roll",
    ["шутки"]="jokes",
    ["народец"]="little folk",
    ["экономика"]="economy",
    ["экономике"]="economy (prep)",
    ["универе"]="uni (prep)",
    ["копи"]="mines",
    ["карте"]="map (prep)",
    ["урон"]="damage",
    ["ценовой"]="price (adj)",
    ["политики"]="policy (gen)",
    ["фантация"]="fantasy (misspelled)",
    ["фантацию"]="fantasy (acc misspelled)",
    ["кристалл"]="crystal",
    ["вечеров"]="evenings",
    ["заявок"]="applications (gen pl)",
    ["заявку"]="application (acc)",
    ["новичку"]="to a newbie",
    ["настройки"]="settings",
    ["настройках"]="settings (prep)",
    ["деревни"]="village (gen)",
    ["цивилизацию"]="civilization (acc)",
    ["крепости"]="fortress (gen)",
    ["условиях"]="conditions (prep)",
    ["видео"]="video",
    ["коленях"]="knees (prep)",
    ["кыргыз"]="Kyrgyz",
    ["штук"]="pieces (gen pl)",
    ["бой"]="fight",
    ["москва"]="Moscow",
    ["московского"]="Moscow (gen)",
    ["иркутску"]="Irkutsk (dat)",
    ["доплата"]="surcharge",
    ["слиток"]="ingot",
    ["железа"]="iron (gen)",
    ["премка"]="premium (slang)",
    ["манекены"]="dummies",
    ["столицах"]="capitals (prep)",
    ["патти"]="party",
    ["шрифтов"]="fonts (gen)",
    ["шатером"]="with tent (name?)",
    ["трансфера"]="transfer (gen)",
    ["варлорд"]="warlord",
    ["сет"]="set",
    ["элитку"]="elite (acc)",
    ["народ"]="people/folks",
    ["туртла"]="Turtle WoW (gen)",
    ["туртл"]="Turtle WoW",
    ["вова"]="WoW",
    ["варкрафт"]="Warcraft",
    ["форум"]="forum",
    ["форуме"]="forum (prep)",
    ["новости"]="news",
    ["пвпшники"]="PvPers",
    ["донат"]="donation",
    ["доната"]="donation (gen)",
    ["донате"]="donation (prep)",
    ["акция"]="promo",
    ["августа"]="August",
    ["аддон"]="addon",
    ["ауке"]="auction house (prep)",
    ["аук"]="AH",
    ["аука"]="AH (gen)",
    ["езда"]="riding",
    ["сумке"]="bag (prep)",
    ["сумон"]="summon",
    ["мобам"]="mobs (dat)",
    ["мобах"]="mobs (prep)",
    ["армора"]="armor (gen)",
    ["ваниле"]="Vanilla (prep)",
    ["бг"]="BG",
    ["ед"]="units",
    ["плюхи"]="smacks (slang)",
    ["метров"]="meters",
    ["объектов"]="objects (gen)",
    ["рейды"]="raids",
    ["рейде"]="raid (prep)",
    ["минутку"]="a minute (acc)",
    ["шах"]="Shah (name/ex)",
    ["опущенца"]="loser (acc)",
    ["кентов"]="buddies (gen pl)",
    ["куколды"]="cucks",
    ["терпилы"]="pushovers",
    ["слов"]="words (gen)",
    ["язык"]="language",
    ["языком"]="language (inst)",
    ["аккаунта"]="account (gen)",
    ["оформления"]="processing (gen)",
    ["фу"]="ew",
    ["ку"]="hi (slang)",
    ["бай"]="bye",
    ["ой"]="oh",
    ["ай"]="ouch",
    ["ауф"]="auf (slang)",
    ["нуну"]="yeah yeah",
    ["ёда"]="Yoda (nick)",
    ["ёдик"]="Yodik (nick)",
    ["развлекуха"]="entertainment",
    ["популяция"]="population",
    ["киллами"]="kills (inst)",
    ["неки"]="necks (slang)",
    ["генеральские"]="general's",
    ["лодку"]="boat (acc)",
    ["парни"]="lads",
    ["персов"]="characters (gen pl)",
    ["челы"]="dudes",
    ["карте"]="map (prep)",
    ["триня"]="trainer (slang)",
    ["пантерку"]="panther (acc)",
    ["садист"]="sadist",
    ["пиаршики"]="promoters",
    ["город"]="city",
    ["нижний"]="lower",
    ["кладбищах"]="graveyards (prep)",
    ["адамантитовый"]="Adamantite (adj m)",
    ["адантитовый"]="Adamantite (typo)",
    ["жезл"]="rod",
    ["пачку"]="pack (acc)",
    ["чароткань"]="Spellcloth",
    ["луноткань"]="Mooncloth",
    ["тенеткань"]="Shadowcloth",
    ["ткань"]="cloth",
    -- NOTE: "рог" stays as "rogue" from earlier entry — horn sense is rare
    -- and would mistranslate every "ищу рог" in LFG chat.
    ["волка"]="wolf (gen)",
    ["полярного"]="polar",
    ["осколок"]="shard",
    ["радужный"]="prismatic/rainbow",
    ["субстанция"]="essence",
    ["планарная"]="planar",
    ["великая"]="great (f)",
    ["изначальная"]="primal (f)",
    ["изначальную"]="primal (f acc)",
    ["рубин"]="ruby",
    ["рубинпродает"]="ruby sells (glued)",
    ["животворный"]="life-giving",
    ["целительная"]="healing",
    ["природы"]="nature (gen)",
    ["сила"]="power",
    ["безжалостные"]="ruthless (pl)",
    ["планы"]="plans",
    ["демонический"]="demonic",
    ["кориевая"]="khorium (f)",
    ["адамантитовая"]="Adamantite (f)",
    ["оскверненного"]="fel (gen)",
    ["наручи"]="bracers",
    ["сообразительности"]="quickness (gen)",
    ["повязки"]="bands",
    ["исцеления"]="healing (gen)",
    ["исцеленияпродам"]="healing sells (glued)",
    ["пояс"]="belt",
    ["ноги"]="legs",
    ["колец"]="rings (gen pl)",
    ["пухи"]="weapons (slang)",
    ["путь"]="path",
    ["завоевания"]="conquest (gen)",
    ["бич"]="scourge",
    ["разыскивается"]="wanted",
    ["разрушенные"]="shattered (pl)",
    ["призрачные"]="ghostly (pl)",
    ["призрачной"]="ghostly (gen f)",
    ["долины"]="valley (gen)",
    ["луны"]="moon (gen)",
    ["кровавого"]="bloody (gen m)",
    ["дозора"]="watch (gen)",
    ["земли"]="lands",
    ["ум"]="summon (typo fragment)",
    ["ищю"]="looking for (typo)",
    ["кроссфрак"]="crossfaction",
    ["стабильная"]="stable",
    ["опытом"]="experience (inst)",
    ["требуются"]="required",
    ["желающих"]="willing ones (gen pl)",
    ["готовенькое"]="ready-made",
    ["быстрого"]="quick (gen)",
    ["быстрый"]="quick",
    ["бысстрый"]="quick (typo)",
    ["свободных"]="free (gen pl)",
    ["юзаный"]="used (slang)",

    -- Pronouns / small words
    ["всех"]="everyone (gen)",
    ["ним"]="him (inst)",
    ["твоего"]="your (m gen)",
    ["твоих"]="your (pl gen)",
    ["вашей"]="your (f)",
    ["того"]="that (m gen)",
    ["этого"]="this (m gen)",
    ["каком"]="which (m prep)",
    ["какой"]="which (m)",
    ["которому"]="to whom (m)",
    ["сколько"]="how much",
    ["наоборот"]="on the contrary",
    ["вон"]="over there",
    ["аж"]="even",
    ["бай"]="bye",
    ["вместо"]="instead",
    ["возле"]="near",
    ["далеко"]="far",
    ["кароч"]="in short",
    ["каром"]="oh",
    ["ко"]="to",
    ["мно"]="much (fragment)",
    ["мож"]="maybe (slang)",
    ["ниче"]="nothing (slang)",
    ["ну"]="well",
    ["пож"]="plz",
    ["прям"]="right",
    ["рано"]="early",
    ["спокойно"]="calmly",
    ["страшная"]="scary (f)",
    ["такое"]="such",
    ["теже"]="same (pl)",
    ["те же"]="same (pl)",
    ["уж"]="at all",
    ["целый"]="whole",
    ["целую"]="whole (f acc)",
    ["чтож"]="well then",
    ["ту"]="that (f acc)",
    ["лишь"]="only",
    ["ниче"]="nothing (slang)",
    ["красиво"]="beautifully",
    ["никак"]="no way",
    ["поч"]="why (slang)",
    ["хахахахахаха"]="hahahahaha",
    ["ахахаха"]="ahahaha",
    ["аахаххаа"]="ahahaha",
    ["аххахахахааххаха"]="hahahaha",
    ["аххахаах"]="ahahah",
    ["ааааааааааааааааааааааааааааааа"]="aaaa",
    ["ляяяя"]="whoa",
    ["ауууу"]="aaaaa",
    ["аууууу"]="aaaaa",
    ["тшшшшш"]="shhhh",

    -- Adjectives
    ["черная"]="black (f)",
    ["чёрная"]="black (f)",
    ["чёрные"]="black (pl)",
    ["золотой"]="gold (adj)",
    ["зеленой"]="green (f gen)",
    ["зеленого"]="green (gen)",
    ["игрушечный"]="toy (adj)",
    ["отличных"]="excellent (gen pl)",
    ["главное"]="main thing",
    ["жирных"]="fat (gen pl)",
    ["лицемерная"]="hypocritical (f)",
    ["лживая"]="lying (f)",
    ["простых"]="simple (gen pl)",
    ["гнилым"]="rotten (inst)",
    ["должно"]="should",
    ["быть"]="to be",
    ["брат"]="brother",
    ["дружественной"]="friendly (f)",
    ["атмосфере"]="atmosphere (prep)",
    ["буйненько"]="rowdy",
    ["вечерком"]="in the evening (dim)",
    ["стандарт"]="standard",
    ["максимум"]="maximum",
    ["корректно"]="correctly",
    ["лоулевельные"]="low-level (pl)",
    ["мертвые"]="dead (pl)",
    ["сервы"]="servers",
    ["серв"]="server",
    ["премка"]="premium (slang)",

    -- Arena/PvP
    ["напа"]="partner (acc)",
    ["напу"]="partner (acc)",
    ["кап"]="cap",
    ["рег"]="reg (arena)",
    ["регай"]="register (imp)",

    -- Common misc verbs completion
    ["откапался"]="dug up (slang)",
    ["переоел"]="over-ate",
    ["огорчился"]="got upset",
    ["чота"]="something (slang)",
    ["помовина"]="help (fragment)",

    -- Tech QA
    ["впритык"]="close-up/tight",
    ["отображения"]="display (gen)",
    ["колёсиком"]="with the wheel",
    ["отдали"]="they gave away",
    ["найди"]="find (imp)",
    ["нашёл"]="found (m)",

    -- Social / culture
    ["куколд"]="cuck",
    ["терпила"]="pushover",
    ["кыргызкой"]="Kyrgyz (f gen)",
    ["населенную"]="populated (f acc)",
    ["людьми"]="people (inst)",
    ["безплатно"]="free (typo)",
    ["вчера"]="yesterday (already?)",
    ["прекрасно"]="perfectly",
    ["петушиная"]="rooster's (f)",
    ["человеку"]="to a person",
    ["стебешься"]="trolling (you)",
    ["живой"]="alive",
    ["онлайн"]="online",
    ["орк"]="orc",

    -- Trade typos / glued words
    ["авар"]="Avar (nick/abbr)",

    -- Numbers with case
    ["пару"]="a couple (acc)",
    ["пары"]="pair (gen)",

    -- Moonkin extras
    ["совой"]="moonkin (inst)",
    ["сове"]="moonkin (dat)",

    -- Misc final
    ["скок"]="how many (slang)",
    ["еба"]="f*ck (interj)",
    ["фул"]="full",
    ["регаем"]="we queue",
    ["хх"]="hh",
    ["хж"]="oh (slang)",

    -- Common short verbs missed
    ["кинули"]="threw (pl)",
    ["кидала"]="scammer (f)",

    -- Transfer saga
    ["туртл"]="Turtle",
    ["туртла"]="Turtle (gen)",
    ["турта"]="Turtle (abbr)",

    -- Quest / guild
    ["гильдии"]="guilds",
    ["гильдию"]="guild (acc)",
    ["гильдиях"]="guilds (prep)",

    -- "далность" vs "дальность" (already)
    ["далеко"]="far",

    -- Drama response
    ["садист"]="sadist",
    ["дилдо"]="dildo",

    -- Round-2 polish from the same log
    ["бегает"]="runs around",
    ["нравится"]="likes/is liked",
    ["нить"]="any (slang for -нибудь)",
    ["посидеть"]="to sit a while",
    ["правильно"]="correctly/right",
    ["принял"]="understood/accepted",
    ["сначала"]="first of all",
    ["функцию"]="function (acc)",
    ["траву"]="herb (acc)",
    ["знаете"]="(you pl) know",
    ["набирает"]="is recruiting",
    ["старики"]="old-timers",
    ["приветствуются"]="are welcome",
    ["подтвердить"]="to confirm",
    ["недостаточно"]="not enough",
    ["доказательством"]="proof (inst)",
    ["неявляется"]="is not (glued)",
    ["выражения"]="expressions",
    ["рассказал"]="told (m)",
    ["арене"]="arena (prep)",
    ["сори"]="sorry",
    ["недопонял"]="misunderstood",
    ["раза"]="times (gen)",
    ["делов"]="deeds (gen slang)",
    ["парн"]="guys (frag)",
    ["парни"]="guys",
    ["контактный"]="contact (adj)",
    ["продает"]="sells",
    ["оптом"]="wholesale",
    ["красава"]="well done (slang)",
    ["рыба"]="fish",
    ["рода"]="kind (gen)",
    ["умнее"]="smarter",
    ["другого"]="other (gen m)",
    ["вид"]="look/kind",
    ["полное"]="full (n)",
    ["похуй"]="don't give a f*ck",
    ["пацански"]="gangster-style",
    ["долбаны"]="dumbasses",
    ["пиздиш"]="bullshit (you)",
    ["запрещено"]="forbidden",
    ["дед"]="dead (Deadmines)",
    ["майнсах"]="mines (Deadmines prep)",
    ["вармейне"]="warmane",
    ["заапали"]="boosted (slang)",
    ["гдеж"]="where else",
    ["насколько"]="to what extent",
    ["прорисовываются"]="get rendered",
    ["обч"]="normal (slang)",
    ["нз"]="dunno / not known",
    ["чер"]="Chr (fragment)",
    ["фан"]="fan",
    ["понос"]="diarrhea (slang)",

    -- Fragments left as-is (sentence-internal artifacts)
    ["сэрца"]="heart (dial)",
    ["явок"]="appointments (gen)",
    ["удмин"]="admin (typo)",
    ["есту"]="quest (fragment)",
    ["етер"]="? (name fragment)",
    ["теб"]="? (you fragment)",
    ["сутен"]="? (name fragment)",
    ["анок"]="Anok (name)",
}

-- Prebuilt list of phrase keys sorted by length descending (byte length).
-- Core.lua uses this so the longest phrase wins (greedy match).
ns.PHRASE_ORDER = {}
for k in pairs(ns.PHRASES) do
    table.insert(ns.PHRASE_ORDER, k)
end
table.sort(ns.PHRASE_ORDER, function(a, b) return #a > #b end)
