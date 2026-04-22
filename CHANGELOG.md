# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.9.4] - 2026-04-22

### Quality-focus release
Previous version reported 99.45% dictionary coverage but a spot-audit on
30 random chat lines found only **47% of translations actually read
naturally** in English. This release goes after the gap.

### Fixed — false-positive 2-letter "nicknames"
The addressee detector had 5 cascading rules that could promote ANY
first word of a message into `session.knownNames` (the nickname roster)
based on context — "next word is a pronoun", "punctuation follows",
"word not in dictionary". This produced permanent false-positive nicks
for short Russian function words like `ну`, `за`, `об`, `ку`, `ах`,
`ой` the moment someone typed "ну ты чего?" or "за что?". Once
promoted, Rule 1 recognised them on every future message without any
dictionary check. Result: 2-character "nicknames" that don't exist on
any WoW server (character names are min 3 chars by Blizzard rules).

**Fix**: removed `DetectAddressee` and its 5-rule heuristic entirely.
The ONLY source of nicknames now is the `sender` field of the actual
chat event in `FilterImpl` — i.e. only people who literally speak on
chat get recognised as nicknames. Added defensive checks in
`FilterImpl`: min 3 Cyrillic letters, reject if sender is itself a
dictionary word.

### Fixed — grammar tags leaking into user output
Dictionary values carrying linguist metadata like `(gen)`, `(acc)`,
`(slang)`, `(imp pl)`, `(nick/abbr)`, `(realm)` were being written
verbatim to the translated chat line. Stripped **560 grammatical
annotations** from values (case, gender, number, style tags). Only
semantically meaningful parentheticals like `(Kara boss)`, `(heroic)`,
`(paid svc)` remain.

### Fixed — double "to" in `к N босу`
`босу` had the translation "to boss", but `к` immediately before
already renders as "to". Result: `к 4 босу` → "to 4 **to** boss".
Changed `босу` and `боссу` to bare "boss".

### Added — frame-level idioms (~40 phrases)
Phrases whose literal word-by-word translation reads as garbage:
- `должно быть` → "probably" (was "should to be")
- `причём тут это` → "what does that have to do with this" (was "by the way here this")
- `уже сделал` → "already done" (was "already did")
- `в броне` → "in gear" (was "in at armor")
- `мы ценим` → "we value" (was "we we value")
- `не вступишь` → "won't you join" (was "not you'll join")
- `шутки лет на` → "jokes for kids aged" (was "jokes years on/for")
- `по атюну` → "for attunement" (was "along/via to attunement")
- `по мск` / `по иркутску` → "MSK" / "Irkutsk time"
- `по итогу` → "in the end", `по порядку` → "in order"
- `плевать на`, `мне плевать`, `всем похуй` → "don't care" family
- `в гробнице маны`, `гробницу маны`, `в разрушенные залы` — instance
  names with case-forms so the preposition chain reads naturally.

### Added — arena-season gear shorthand
`а1`, `а2`, `а3`, `а5`, `а6` as single tokens (previously split into
`а` + digit, rendering as "but2" / "but3"). 15+ in this log.

### Added — fresh log Apr 22 (1353 total lines, +248 new)
New clusters encountered in this session:
- **Zul'Gurub mount-farming** (vanilla raid ran by TBC-alt players):
  `зул гуруб`, `стремительный зульский тигр`, `стремительный ящер
  раззаши`, `рол` (roll), `маунт/маунтов`, `каражан со скипом`.
- **Server population debate**: `онлик`, `прайм`, `в праймтайме`,
  `реальный онлайн`, `реальных`, `нарисованы`, `с лишним`, `по миру`.
- **Skuf / zoomer slang**: `скуф`, `скуфы`, `скуфье`, `зумерок`,
  `помечтай`, `хорош болтать`, `скуфы не болтают, они общаются`.
- **Bot-farming rant vocab**: `хуева куча`, `куча скелетов`,
  `кусок уебища`, `крабить`, `крабя`, `одеваясь с профы`, `онли`,
  `удаляли тикет`, `скинул в телегу`.
- **GM rules boilerplate**: `добрый день`, `уважаемые игроки`,
  `соблюдайте правила сервера`, `избежать наказаний в виде мута/бана`,
  `ознакомиться с правилами`, `на нашем сайте`.
- **Twisted Nether recruit template**: `ведет набор любых уровней`,
  `взрослый и адекватный коллектив`, `играем в удовольствие`,
  `без обязательного`.
- **Misc**: `стальгорн(е)`, `калимдор(у)`, `восточные королевства`,
  `цитадель адского пламени`, `террокар(е)`, `бластед ленс`,
  `магическая ткань`, `к элему`, `2ух факторку`, `перенести перса`,
  `верните мой 2007`, etc.

Dictionary grew **4627 → 5289 entries** (+662 after cleanup & dedup).
Coverage on the full 1353-line combined log: **99.46%**. Remaining
27 unknowns are all player nicknames, typos, or URL-encoded garbage.

## [0.9.3] - 2026-04-21

### Coverage
Fresh live `WoWChatLog.txt` pulled from the WoW install (1105 Russian
lines over April 19–21). Starting coverage was **84.2 %** — this window
opened up three previously-underserved topics: **server-transfer /
Quick-Start drama** from Turtle-WoW refugees, **render-distance &
camera-zoom tech QA**, and a **flame war with Karmeli's guild** full
of anrol/куколд/терпила slang. After this release: **99.45 %**
on the full session. Dictionary grew **4409 → 4627 entries** (+218).

### Added
- **Zones & dungeons** missed until now: `Хилсбрад` (Hillsbrad),
  `Сеттеки` (Sethekk), `ШЛ` (Shadow Labyrinth slang), `Анзу`
  (Sethekk boss), `Паров/Паро/Паровые` (Steamvault), `Тралмар`,
  `Оргримаре` (prep case), `Награнде` (prep case), `Разрушенные залы`
  (Shattered Halls), `Чёрные топи` (Black Morass), `Гробницы маны`
  (Mana-Tombs), `Нижний город` (Lower City), `Долина Призрачной Луны`
  (Shadowmoon Valley), `Призрачные земли` (Ghostlands).
- **Quest / NPC names**: `Уварус` (boss), `Адало` (Adal), `Майден`
  (Maiden), `Оперы` (Opera gen), `Путь Завоевания`, `Битва у
  Кровавого Дозора`, `Принеси мне яйцо!`.
- **Trade item localisations** (ruRU → enUS): `Адамантитовая руда`,
  `Кориевая руда`, `Слиток оскверненного железа`, `Великая планарная
  субстанция`, `Рог полярного волка`, `Чароткань`, `Луноткань`,
  `Тенеткань`, `Большой радужный осколок`, `Демонический кристалл`,
  `Изначальная жизнь`, `Изначальная луноткань`, `Безжалостные планы`,
  `Целительная сила природы`, `Животворный рубин`, `Наручи
  сообразительности`, `Повязки быстрого исцеления`.
- **Quick-Start paid-service vocabulary**: `быстрый старт`, `быстрого
  старта`, `фул а2`, `перенос аккаунта`, `оформления`, `заявку`,
  `подать`, `задонить`, `донате`, `рублей`, `молотушка` (service-
  pricing discussion), `а4`, `т6`, `свп`.
- **Render-distance QA thread**: `дальность прорисовки`, `дальность
  отображения`, `отдаление камеры`, `настройки камеры`, `колёсиком`,
  `впритык`, `метров`, `объектов`, `мобах`, `прорисовываются`.
- **Karmeli flame war**: `анрол`, `анролом`, `куколды`, `терпилы`,
  `мошеничество`, `дешевка`, `лицемерная`, `лживая`, `дилдо`, `шах`,
  `опущенца`, `кенты`, `садист`, `красава`, `киданул`, `кидала`,
  `одевала`, `одевали`.
- **Classes/roles shorthand**: `ппал` (prot paladin), `вар` (warrior),
  `сова` (moonkin), `рдру` (resto druid), `рпал` (holy paladin),
  `кроссфрак` (crossfaction).
- **Acronyms**: `вк` (VK), `нпс` (NPC), `фп` (flight point), `хд` (xD),
  `рф` (Russia).
- **~100 verbs** in missing conjugations: `фарм`, `играть`, `вступить`,
  `похилю`, `танканите`, `принеси`, `подскажите`, `подскажет`, `побил`,
  `гонять`, `качнулись`, `переносят`, `включил`, `отпишитесь`,
  `практикует`, `соглашайтесь`, `подтвердить`, `развивай`,
  `превратимся`, `собирать`, `задонить`, `записать`, `докачаемся`,
  `приветствуются`, `промолчал`, `проверить`, and many more.
- **Nouns / adjectives** completing the long tail: `жизнь`, `бой`,
  `праздник`, `яйцо`, `старт`, `ник`, `группу`, `цепочка`, `урон`,
  `кристалл`, `крепости`, `видео`, `коленях`, `аккаунта`, `деревни`,
  `цивилизацию`, `населенную`, `условиях`, `лоулевельные`, `мертвые`,
  `стабильная`, `готовенькое`, `главное`, `отличных`, and so on.

### Notes
- Remaining **22 unknowns** after this release are all player nicknames
  (Молотушка, Кармели, Перкусионист, Павлия, Чилдорик, Дима, Дулма,
  Флоки, Разор, Макидза, Песюносос, Вазилин, Потаскушка, Райзенов)
  plus typos (тообй, дикпики, екфтыаук, дняпозови, годд) and urlencoded
  garbage. Nicknames get caught by the 5-rule addressee detector the
  moment they speak, so they don't need dictionary entries.
- Dictionary is now **99.45 %** on this log — essentially the ceiling
  before diminishing returns take over.

## [0.9.2] - 2026-04-21

### Coverage
Fresh live `WoWChatLog.txt` from the WoW install (634 Russian lines,
394 unique — a long drama/flame-war session with song lyrics, movie
references, Discord kick stories, formal Russian idioms, and many
basic words somehow never added). Starting coverage was **84 %**;
after this release **94 %** on the full session. Dictionary grew
from 4189 → **4409 entries** (+220).

### Added
- **Missing basics** that had evaded the dictionary so far as bare
  single words: `наверное`, `тогда`, `конечно`, `давай`, `раз`,
  `будто`, `иначе`, `вот`, `даже`, `иди`, `бы`/`б`, `если бы`,
  `было бы`, `кстати`, `вся`. These were only present inside phrase
  entries like `жаль конечно` and `нет конечно`.
- **Discord / drama vocab**: `дс` (Discord), `кикнули`, `кинули`,
  `базар` / `за свой базар`, `отвечаешь`, `матерится`, `обещал`,
  `вряд ли`, `лишний`, `доказывает`, `слабее`, `слабости`, `разнос`,
  `расходимся`, `сенсации`.
- **Insults / rant words**: `херовый`, `нахуя`, `пу пу пу`, `разьеб`,
  `опущенный`, `фуфлометы`, `куток для обиженных`, `шекелей`,
  `сдох`.
- **Items / trade**: `узда белого жеребца`, `открыть сундук`,
  `шекелей`, `трансфер перса с шторма`.
- **Song-lyric / cultural words**: `неси меня, река`, `за крутые
  берега`, `позови меня тихо по имени`, `закате`, `грусть-печаль`,
  `черкизовский`.
- **Pop / tech refs**: `тредс` (social), `путин`, `свадебная ваза`,
  `херовый фильм`, `оперу` (Karazhan boss).
- **Kara Opera event**: `оперу` / `опера`.
- **Tech**: `исправьте`, `баганный`, `жалуются`, `инфа на форуме`.
- **Conditional particles**: `если б`, `если бы`, `было бы`,
  `я б`/`я бы`.

Remaining ~6% unknowns are mostly player nicknames and multi-token
numeric concats (`1дд`, `2дд` — already handled by the runtime
preprocessor, they're only "unknown" in my simulation tool that
doesn't run the full preprocessor chain).

## [0.9.1] - 2026-04-20

### Coverage
Fresh live log (`C:\Gry\World of WarcraftOLD\Logs\WoWChatLog.txt`,
335 unique Russian lines, much richer content than previous logs —
GM moderation messages, quest boss names, longer sentences, more
formal vocabulary). Starting coverage was **84 %**; after this release
it is **98 %**. Dictionary grew from 3814 → **4189 entries** (+375).

### Added
- **Shadow Labs Russian shorthand**: `тем лаб` / `тем лабиринт` /
  `тёмный лабиринт` → "Shadow Labs". Paired with heroic/normal
  variants and `в тем лаб` / `в тем лабе` locatives.
- **Shadow Labs boss**: `бормотун` → "Murmur".
- **Quest names**: `зулухед измученный` (Zul'jin the Exhausted),
  `гибель предателя` (Death of the Betrayer — Illidan chain).
- **Item names**: `посох божественного вливания` (Staff of Infusion),
  `антикварный сундук` (Antique Chest), `стабилизированный
  этерниевый прицел` (Stabilized Eternium Scope), `рубашка нежити`
  (Undead Shirt).
- **TBC NPCs**: `трала` (Thrall), `келя` (Kael'thas short form).
- **GM / admin boilerplate** (formal Russian from moderation
  messages): `уважаемые игроки`, `за использование ненормативной
  лексики`, `в глобальном чате`, `будут выдаваться муты`, `научитесь
  общаться уважительно`, `я начну отвечать на ваши вопросы`,
  `уважаемая администрация`, `гражданин начальник`, `поставленный
  вопрос`.
- **Honor cap talk**: `недельный кап`, `кап хонора`, `дальше не
  капает`, `перестал начисляться`, `какого хуя`, `какого хрена`.
- **Enchanting services**: `чарю шмот за ваши реги`, `наложение
  чар`, `чарю бесплатно`.
- **Arena team shorthand**: `к вару в 2с`, `ршам/хпал/рдру`,
  `на 10 игр`.
- **LFG preamble**: `сумон к 3 босу`, `сумон сразу`, `1 дд в`,
  `к ласт слот`.
- **Class abbreviation variants**: `хпал` (Holy Paladin), `вару`
  (warrior dative), `тан` (tank short).
- **~180 single-word additions** covering the verbs, adjectives,
  nouns, and case forms seen in this session that weren't in the
  previous 3814-entry dictionary.

## [0.9.0] - 2026-04-20

### Added
- **Interface Options panel.** All four persistent settings are now
  clickable from WoW's native settings UI:
    **Esc → Interface → AddOns → Russian Translator**
  - Enable translation
  - Show original Cyrillic in parentheses after translation
  - Auto-enable /chatlog on login
  - Debug mode (hex dump each message)

  Every checkbox writes directly to the `db.*` field used by the rest of
  the addon, so clicking one in the panel is equivalent to the matching
  slash command (`/rt on`, `/rt orig`, `/rt chatlog`, `/rt debug`) and
  persists to `SavedVariables` the same way — no separate save step.
- New slash command: **`/rt options`** (alias: `/rt config`) opens the
  panel directly. Calls `InterfaceOptionsFrame_OpenToCategory` twice to
  work around the well-known Blizzard single-click bug where the first
  call opens the root and the second actually selects the category.

## [0.8.5] - 2026-04-20

### Added — layered addressee detection

The v0.8.4 nickname recognition only worked for senders who had already
spoken this session. Real chat doesn't wait: people address nicknames
that haven't spoken yet, often without a comma. This release layers
four more rules on top of the sender-roster check so addressing gets
caught even from the first message of a session.

Rules, applied to the first Cyrillic token of each message, in order
(first match wins):

1. **In `knownNames`** (sender seen speaking) → nick. *(v0.8.4)*
2. **First word is itself an address-context token** (a question word
   like `кто`/`где`/`как` or a 2nd-person pronoun like `ты`) → NOT
   nick. This stops false positives like "Кто ты" tagging `кто` as a
   nickname.
3. **Next token is an address-context word** (`ты`, `вы`, `где`, `дай`,
   `скажи`, `помоги`, `кинь`, `приди`, `иди`, `пиши`, `жди`, `бери`,
   `смотри`, `слушай`, `сюда`, and a few dozen more). Catches
   `Мукк ты где?`, `Кара дай инв`, `Панацея, где?`.
4. **Vocative punctuation `,` `;` `:` `!` right after first word** AND
   the first word is NOT a dictionary word. Catches `Мукк, инв дай`.
   Requires "not in dictionary" to avoid tagging listings like
   `Кара, БТ, ШХ` as a nickname address.
5. **First word is not in the dictionary and there IS more content** →
   nick. Catches unknown-proper-noun at start with continuation.

When any rule fires, the addressee is auto-added to the session roster
so follow-up messages are recognised by rule 1 directly.

### Test cases (from the simulator)

| Input                          | Detected? | Rule |
|--------------------------------|-----------|------|
| `Мукк, инв дай`                | yes       | 4 (punct + unknown) |
| `Мукк инв дай`                 | yes       | 5 (unknown + continuation) |
| `Мукк ты где?`                 | yes       | 3 (pronoun after) |
| `Кара ты где?`                 | yes       | 3 (pronoun, overrides dict) |
| `Кара сегодня стартует`        | no        | no markers, Кара in dict → Karazhan |
| `Привет всем`                  | no        | привет in dict, всем not context |
| `Кто ты`                       | no        | rule 2 early exit (first is context) |
| `Панацея, где?`                | yes       | 3 (где after punct) |
| `Панацея спасет мир`           | no        | Панацея in dict, no address signal |
| `Кара, БТ, ШХ`                 | no        | Кара in dict + listing, rule 4 skipped |
| `Хрр все сюда`                 | yes       | 5 (unknown word) |
| `Кара дай инв`                 | yes       | 3 (дай is imperative) |
| `Мукк: инв дай`                | yes       | 4 (colon) |

## [0.8.4] - 2026-04-20

### Added
- **Session-local nickname roster.** Every `sender` seen in any chat
  event is recorded in a RAM-only set (`session.knownNames`). When
  translating, the FIRST Cyrillic token of a message is checked against
  that set — if it's a known nickname, it's passed through untranslated
  and rendered in soft green (`|cff88cc88`) to signal "this is a
  player, not a word". Subsequent Cyrillic tokens in the same message
  are translated normally, because mid-message occurrences of a
  nickname-word are usually the real word (e.g. someone with nick
  `Кара` saying something about `кара` the dungeon later in the line).

  Why: several real WoWCircle TBC nicknames happen to be normal Russian
  words — `Панацея` (panacea), `Кара` (Karazhan), `Борей` (Boreas),
  `Мукк` etc. Without this, addressing "Панацея ты где?" would
  translate as "panacea where are you?" and lose the addressing sense.

  The roster is **intentionally not persisted** — it's rebuilt each
  session. A nick that coincides with a Russian word should earn its
  "don't translate" status every session by actually being online.

### Added — new commands
- `/rt names` — list the tracked nicknames of the current session with
  talk-counts. Capped at 30 rows on screen.
- `/rt status` now also reports `nicks=N`.

## [0.8.3] - 2026-04-19

### Added
Continuation of the live WoWCircle TBC session (rolling `WoWChatLog.txt`,
440 Russian lines, 248 unique). Starting coverage was **97 %**; after
this release it is **98 %** and the only remaining unknowns are player
nicknames.

- `больше`, `меньше` (were somehow missing in bare form)
- `русич`, `русичи`, `русичей` — colloquial "Russian"
- `сумануть`, `сумани` — summon (infinitive + imperative variants)
- `можете`, `можем` — verb "can" (you-pl, we) — complementing the
  existing `может`, `могу`, `можешь`, `могут`
- `ждем`, `ждёмс`, `жднм` (typo variant) — "we wait"
- `пох`, `похер`, `похую` — vulgar "don't care" variants
- `передавать`, `передать` + all past-tense forms — "to pass"
- `че` — what (alongside existing `чё` / `чо`)
- `бич`, `бичи`, `бичей` — "loser" slang
- `пиздец` + cases — vulgar "disaster"
- Filler particles: `слыш`, `слышь`, `ёмаё`, `ёпт`, `ёпрст`, `ептыть`
- Minor adverbs: `ниже`, `выше`, `среди`, `сразу`, `тотчас`, `постоянно`

## [0.8.2] - 2026-04-19

### Added
- **Auto-enable `/chatlog` on every login.** On WoW 2.4.3 the
  `/chatlog` state is not persisted between sessions, so every
  relog/reboot the flag turns off. Miss it and the whole session's
  chat buffer is lost. The addon now calls `LoggingChat(true)` from
  its `PLAYER_LOGIN` handler so the log is always capturing without
  you having to remember.
- New slash command `/rt chatlog on|off` to toggle the behaviour (the
  setting is stored in `SavedVariables` as `db.autoChatLog`,
  default **on**).
- `/rt status` now shows both the persisted setting and the live state
  of the WoW chat logger (`autoChatLog=true  chatlog-now=on`).
- Startup banner displays `chatlog=on|off` so you can see at a glance
  that it's active.

The `/chatlog` output lands in
`<WoW install>\Logs\WoWChatLog.txt`. On 2.4.3 the file is buffered —
it fully flushes on clean logout or `/reload`. If your client crashes,
lines written since the last flush are lost (unavoidable; buffering is
on the engine side).

## [0.8.1] - 2026-04-19

### Added
- **Slavic smiley convention** (`)`, `))`, `)))` for happy, `((`, `(((` for
  sad) is now recognised and rewritten as the Western `:)` / `:(` form.
  Russian and neighbouring nations drop the leading colon; to an English
  reader this reads as a stray unmatched parenthesis.

  The transform is paren-pair aware — we count opens vs closes and only
  treat the excess as smileys. Ordinary parentheticals like
  `кто на кару (хс)?` are left alone because their parens balance. A
  leading colon from `:)` / `:))` is respected (no double-prefixing).

  Transforms:

  | Input                                | Output                         |
  |--------------------------------------|--------------------------------|
  | `привет)`                            | `привет :)`                    |
  | `ппц скучно)))`                      | `ппц скучно:)))`               |
  | `ура))))`                            | `ура:))))`                     |
  | `жаль(((((`                          | `жаль:(((((`                   |
  | `что-то не работает (`               | `что-то не работает :(`        |
  | `(smth) дальше)`                     | `(smth) дальше :)`             |
  | `(хс) вечером го))`                  | `(хс) вечером го:))`           |
  | `смотри (это тут)` (balanced)        | unchanged                      |
  | `lol :))` (already has colon)        | unchanged                      |
  | `пока ;)` (wink)                     | unchanged                      |

## [0.8.0] - 2026-04-19

### Added — full grammatical-case coverage

Russian has 6 cases (nominative, genitive, dative, accusative,
instrumental, prepositional) × 2 numbers × 3 genders. A given noun can
appear in chat in up to ~12 different surface forms. A pure
word-lookup dictionary therefore needs every form as a separate entry
or it misses half of incoming text. This release fills in the missing
case forms for every high-frequency category:

- **Instances/raids**: full declension for Karazhan, Gruul,
  Magtheridon, Hyjal, Serpentshrine, The Eye, Zul'Aman, Arcatraz,
  Botanica, Mechanar, Ramparts, Mana-Tombs, Magisters' Terrace,
  Underbog, Slave Pens, Sethekk Halls, Steamvault.
- **Classes** (sg+pl, all cases): mage, hunter, paladin, warlock,
  shaman, priest, rogue, warrior, druid — dative/instrumental/
  prepositional forms that were missing (магу, магом, маге, магах,
  хантом, пале, друиду, разбойником, and so on).
- **Roles**: tank, healer in all cases (танку, танком, танке,
  танкам, хилу, хилом, хиле…).
- **Gear slots**: cloak, weapon, ring, shield, armor, helm, pants,
  belt, boots, gloves, shoulders, bracers, neck, trinket — genitive
  (плаща, щита, брони), dative (плащу, щиту, броне), instrumental
  (плащом, щитом, бронёй), prepositional (плаще, щите, броне).
- **Stats**: strength, agility, intellect, stamina, crit, haste, hit,
  spell power, resistance, rating — all cases.
- **Key verbs** (top 20): быть, идти, делать, мочь, знать, хотеть,
  видеть, слышать, помогать/помочь, дать, купить/покупать,
  продать/продавать, искать, найти, ждать, говорить/сказать,
  писать/написать, думать, помнить, ходить, брать/взять, убить,
  играть, качаться — all past-tense forms (m/f/pl), 1st/2nd/3rd
  person present, imperative, future.
- **Adjectives**: good, bad, cool, new, old, big, small, strong, weak
  — full declension (genitive, dative, instrumental, prepositional).
- **Numerals**: 1-10, 20, 30, 50, 100, 1000 — all cases (одного,
  двух, трёх, пяти, десяти, ста, тысячи, тысяче…).
- **Pronouns**: instrumental forms that were missed (мною, тобою,
  нами, собой, себе).
- **Time words**: час, день, неделя, месяц, год — all cases
  (часу, часом, часе, дню, неделе, месяце, году…).
- **Quest/game nouns**: quest, book, key, mob, boss — all cases.
- **Money**: gold, silver, stack — all cases.

### Dictionary size

Grew from **3261 → 3814 entries** (+553). File is ~140 KB. Load-time
and memory impact still below every measurable threshold — a fully
loaded `GetAddOnMemoryUsage()` reports under 1 MB for the whole
addon. Practical limit of the architecture is around 20 000 entries
before anything slows down; we're at 19 %.

### Coverage

All six existing chat logs still at **98 %** coverage. Benefit of the
new case forms is future-facing: the dictionary now no longer misses
common inflected forms players type in context (e.g. `магом` when a
player says "иду магом" / "going as a mage", `плащу` when someone
writes "на плащу" / "on the cloak").

## [0.7.1] - 2026-04-19

### Fixed
- **Removed an accidental user-mention from the author credit strings.**
  The author credit previously contained an at-symbol followed by the
  literal text `"WoW"`, which GitHub interpreted as a user mention and
  auto-linked to an unrelated GitHub account (username: `wow`). That
  stranger was being notified on every release and every render of the
  README. Credit is now simply `"(Poczwarka)"`. All six previous
  release notes were retro-edited to strip the mention, and source,
  README, TOC author field, and in-game startup credit were all updated.
  No functional changes.

## [0.7.0] - 2026-04-19

### Coverage
Fresh WoWCircle TBC session (log 006, 2248 lines, ~230 unique Russian
messages with very different themes from previous logs — guild-chat
recruiting, heroic-dungeon LFG, attunement questions, schedule posts,
Russian-localised quest/item names, complaints about spam). Starting
coverage was **71 %** (710/991 Cyrillic tokens covered); after this
release it is **98 %** (697/710 tokens, remaining 13 are mostly
player nicknames). Dictionary grew from 2361 → **3261 entries**
(698 phrases + 2563 words).

### Added
- **Difficulty-mode slang**: `гер`/`геры` (heroic), `нормалы`/`нм`/`нормалку`
  (normal), `дейлик` (daily). These are the dominant way Russian TBC
  players tag LFG posts, previously falling through as unknown.
- **Loot / raid-roster idioms**: `ласт`/`ласта`/`ласту` (last boss),
  `сум к ласту` (summon to last), `слот`, `штаны рез`/`штаны резерв`
  (pants reserved), `перчи рез`, `плащ рез`, `ласт слот`.
- **Instance-with-mode phrases**: `рампы гер`, `рампы нм`, `бф гер`,
  `шх гер`, `шм гер`, `паровое нм`, `паровое гер`, `узилище гер`,
  `узилищер` (Arcatraz heroic).
- **Weekly-schedule vocabulary**: days of week short (пн, вт, ср, чт, пт,
  сб, вс) and full (понедельник..воскресенье), `сб и вс`, `с пн по пт`,
  `пн-чт`, `выходной`, `сбор в 19:00`, `по иркутскому времени`,
  `по московскому времени`.
- **Quest-flow phrases** seen in log: `прикосновение занзила`
  (Touch of Zanzil), `как выполнить`, `сдать не могу`, `квест не сдаётся`,
  `в журнале пишет`, `за дейлик`, `ключ за дейлик`.
- **Russian-localised item names**: `туз из колоды зверей` (Ace of
  Beasts), `фолиант сотворения воды` (Tome of Conjure Water),
  `изначальная мощь` (Primal Might), `ткань пустоты` (Netherweave Cloth),
  `руническая ткань` (Runecloth), `ездовой хлыст назана` (Nazan's Riding
  Crop).
- **Russian-localised zone names**: `сёрные топи` (Swamp of Sorrows),
  `алый монастырь` / `монастырь алого` (Scarlet Monastery), `на кладбище`
  (SM Graveyard wing), `лабиринты иглошкуры` (Razorfen Kraul),
  `баресне`/`барренс` (Barrens), `каменор` (Stonard).
- **Attunement talk**: `атюн`/`аттюн` + case forms, `атюн на бт`
  (BT attunement), `с барабанами` (with drums), `прохождения санвела`
  (Sunwell progression), `для уcиления гильдии` (latin-'c' typo
  variant included).
- **Guild-recruit boilerplate**: `помогаем одеваем подсказываем`, `связь
  обязательная (дискорд)`, `для походов в рейды`, `по доп. вопросам в пм`,
  `приоритет в новых людях`, `шмот не важен`, `мы ценим`.
- **Complaint vocabulary**: `задолбали спамить ги`, `гавно-спам`, `эго
  гильд лидеров`, `обьядиниться`/`объединиться`, `игнорировать`,
  `сервак лагает`, `не готов к наплыву беженцев`.
- **Arena-rating team search**: `ищу напа в свою тиму`, short class tags
  `ршам`/`рдру`/`рпал`/`энх`/`энха`.

### Added (preprocessors in Core.lua)
- `<num>рейт` → `<num> rating`  (e.g. `1712рейт` → `1712 rating`)
- `<num>мин` → `<num> min`
- `<num>сек` → `<num> sec`
- `<num>лвл` → `<num> lvl`
  (complementing existing `<num>к/г/дд/хил/танк` preprocessors.)

### Fixed
- Missing `кару` (Karazhan accusative) — common in "кто на кару".
- Disambiguated `можно`, `лока`, `св`, `инвиз`, `уйти` that were falling
  through as unknowns.

## [0.6.2] - 2026-04-19

### Fixed
- **`боты` disambiguated.** A duplicate key was mapping `боты` to "bots"
  later in the file and overriding the earlier "boots" definition, so
  `зачарить боты` (enchant boots) came out as "enchant bots". Kept the
  "boots" default and added phrase overrides `боты пишут`, `все боты`,
  `боты онлайн`, etc. for the bot-complaint sense.

### Added
- **Contextual phrases that fix bad word-by-word translations.** Several
  Russian words are ambiguous in isolation but unambiguous inside common
  phrases; added phrase entries to pick the correct sense:
  - `кто может` / `кто может зачарить` / `может помочь` / `может сделать`
    → "who can" / "who can enchant" / "can help" / "can do" (was landing
    on "maybe" from the single-token fallback).
  - `с какого левела` → "from what level" (bare "с" + "какого" + "левела"
    previously missed).
  - `птица у друида` → "druid flight form" (literal was "bird at druid").
  - `дальний восток` → "Far East" (guild name on WoWCircle).
  - `московского времени` / `от московского времени` → "Moscow time" /
    "from Moscow time".
  - `для тех у кого` → "for those with" (three words none of which were in
    the single-token dictionary in their genitive/dative forms).
- **LFG professional-services phrases**: `ищу инженера`, `ищу ювелира`,
  `ищу кожевника`, `ищу портного`, `ищу алхимика`, `ищу кузнеца`,
  `ищу напа`/`ищу напарника`, and `нужен X` counterparts.
- **Crit-scope phrases**: `прицел 28 крита` / `прицел 28 криты` →
  "28-crit scope", plus `28 крита` / `28 криты` as short forms. Handles
  both crit-count genitive forms used in trade chat.
- **Instance-suffix phrases** for Steamvault (`паровое нормал`,
  `паровое норм`, `паровое хс`, `паровое хк`).
- **Boot-enchant shorthand**: `стамина+бег`, `стам+бег`, `ловкость+бег`
  → "stamina + run speed" etc. `бег` is dictionary-mapped to "run speed"
  (boot enchant context) rather than "run" to avoid mistranslation in
  trade chat.
- **Misc chat**: `лол сосать`, `сосать на` (vulgar losing slang),
  `wtb/куплю` and `куплю/wtb` (slash-joined mixed tokens), `мой реги`,
  `на 10 игр` (arena partner search count).
- **50+ single-word additions** covering the genitive/dative/instrumental
  forms missed in log-005: `дальний`, `восток`, `примет`, `новых`, `тех`,
  `кого`, `кому`, `какого`, `время`, `времени`, `московского`, `инженера`,
  `ювелира`, `алхимика`, `зачарить`, `реги`, `левела`, `птица`, `напа`,
  `напарника`, `игр`, `криты`, `бег`, `сосать`, `форум`, `тема`, `пост`
  and more.

### Coverage
After v0.6.2, live-chat token coverage on WoWCircle TBC Global is
**98 %** (338 Cyrillic tokens, 334 hits, 4 remaining are player
nicknames).

## [0.6.1] - 2026-04-19

### Added
- Registered `CHAT_MSG_BATTLEGROUND` and `CHAT_MSG_BATTLEGROUND_LEADER`.
  Battleground chat (`/bg`) was the only public channel not covered.
  All other channels (Say, Yell, Party, Raid, Raid-Leader, Raid-Warning,
  Guild, Officer, Whisper-in, Whisper-out, numbered channels like Global
  and Trade, Emotes, NPC speech) were already filtered — the addon just
  looked "Global-only" because that channel carries ~95 % of public chat
  traffic on a typical Russian TBC server.

## [0.6.0] - 2026-04-19

### Fixed
- **Gold-shorthand preprocessor no longer eats into following words.**
  v0.5 converted `28 крита` (28 crit) into `28Kрита` because the regex
  `(%d+)%s*к` matched the leading `к` of `крита`. Fixed with a word-boundary
  constraint: the suffix is only consumed if the next byte is not a Cyrillic
  letter or ASCII word character.

### Added
- **Numeric shorthand preprocessors extended**:
  - `20г` → `20g` (gold single-letter shorthand, same boundary rule as `к`).
  - `1дд` / `2дд` / `3дд` … → `1 dps` / `2 dps` / `3 dps`.
  - `1хил` / `2хилл` → `1 healer` / `2 healers`.
  - `1танк` / `2танк` → `1 tank` / `2 tank`.
- **Dictionary gaps filled from real v0.4 chat session** (WoWChatLog_004): 50+
  new entries covering the words that fell through — modal verbs and
  particles (`может`, `мб`, `пусть`, `возможно`, `возможность`), pronouns
  (`кому`, `который`, `которая`, `них`, `него`), conjunctions (`чтоб`,
  `чем`, `помимо`), verbs (`убить`, `видеть`, `дают`, `лежит`, `кажется`,
  `воспринимай`, `подумал`, `убрали`), nouns (`администрация`, `гробница`,
  `топики`, `чате`, `пиво`, `язык`, `удача`), time (`суток`, `порой`),
  affective (`скорей`, `англ`, `удачи`), laughter-length variants, and
  insult/slur placeholders for completeness.
- **Explicit pre-baked gold shortcuts** for common amounts: `20г`, `10г`,
  `50г`, `100г`, `500г`, `1к`..`100к`.

### Coverage
After v0.6.0 the live chat log from WoWCircle TBC Global channel reaches
**98 %** translation coverage at the Cyrillic-token level (323 tokens,
318 hits, remaining 5 are player nicknames).

## [0.5.0] - 2026-04-19

### Added
- Major dictionary expansion: **2361 entries** (409 phrases + 1952 words), up
  from 586 in v0.4.0 — a ~4x increase. Harvested in parallel by three
  research agents:
  - **General Russian-English vocabulary**: conjugated verbs in common forms
    (я иду, пришёл, сделаю), everyday adjectives with all grammatical forms,
    adverbs, pronouns in all cases, numerals 1–1000, time words, chat slang
    (хз, имхо, норм, збс, ща, юзать), internet reactions (ору, жесть, кринж,
    топчик, жиза), and emotional/insult vocabulary common in MMO chat.
  - **Russian WoW TBC forum slang**: class/spec abbreviations (фростик,
    ретрик, холик, протик, элька, энха, рестик, афлик, деструктор, мункин,
    совунья), instance shorthand variants (шатхол, маналей, муни, маркнар),
    server economy terms (буст, бустер, прем, примка, донат, реалманы,
    пинкод), PvP/arena slang (бурст, кайт, контроль, кц, ммр, глад).
  - **Broader Russian WoW web content**: Russian localised zone names
    (Запределье, Нордскол, Калимдор, Штормград, Оргриммар, Даларан,
    Шаттрат, Награнд, Зангартопь), Russian-language spell names players
    shorthand (полимаг, молния цепью, удар в спину), professions and ranks
    (алхимик, кузнец, ювелир, пошив, кожевник, горное дело), combat
    call-outs (вайп, трай, клир, фокус огонь, не стой в огне).
- Grammatical-case coverage for high-frequency WoW nouns (штормграда/
  штормграде, оргриммара/оргриммаре, каражана/каражане/каре/кары).

### Fixed
- **Number + "к" is now translated as "K" thousand-shorthand** (e.g.
  "продам за 5к" → "WTS for 5K", "4.5 к голда" → "4.5K gold"). Previously
  the single-token "к" fell through to its preposition meaning "to",
  producing nonsense like "WTS for 4.5 to". Implemented as a pre-token
  regex replacement in the translation pipeline.
- **Standalone "за" now defaults to "for"** instead of "Zul'Aman". The
  Zul'Aman sense is already covered by phrases like "го за" and "кто на за",
  so the common trade sense ("за 5к" = "for 5K") now translates correctly.



### Added
- Comprehensive starter dictionary seeded from real Global-channel chat logs
  on a Russian TBC server: ~140 multi-word phrases + ~440 single-word tokens
  covering instance names (all TBC 5-mans + raids), class/role abbreviations,
  LFG/LFM idioms, trade/arena shorthand, common slang and small words.
- Russian raid-progress pattern recognition (e.g. `ХС 5/5 БТ 7/9`).
- Per-session activity log written to `SavedVariables` at logout/reload:
  encoding detected, first hex bytes per encoding, filter call count,
  sampled chat rows, and per-token unknown-word frequency with sample context.
- Startup credit line.

### Changed
- Untranslated Cyrillic tokens are now kept in Cyrillic (coloured orange)
  instead of being transliterated, so it is immediately clear which parts
  of a message the dictionary did not match.

## [0.3.1] - 2026-04-19

### Changed
- Unknown tokens keep their Cyrillic form (orange) rather than being
  transliterated to Latin.

## [0.3.0] - 2026-04-19

### Fixed
- Chat filter signature corrected for WoW 2.4.3. Earlier versions used the
  modern `(self, event, msg, ...)` signature, which on a 2.4.3 client
  shifts every positional argument by two (so `event` receives `sender`,
  `msg` receives `language`, etc.) and crashes inside `string.format` for
  events with no sender.  Now uses the real TBC signature `(msg, ...)` with
  the event name captured via a closure at registration time.
- Filter body wrapped in `pcall` so a bug in the pipeline no longer taints
  the chat frame.

## [0.2.0] - 2026-04-19

### Fixed
- Shared-namespace initialisation. The common Lua idiom
  `local addonName, ns = ...` silently fails on 2.4.3 because top-level
  addon varargs were not introduced until patch 3.0.2 (WotLK); every
  subsequent `ns.foo = ...` then errored as "attempt to index nil value".
  Replaced with a shared-global-table pattern that works on every WoW
  version.

### Added
- Automatic CP1251 → UTF-8 normalisation for servers that ship Cyrillic
  chat in the legacy Windows-1251 encoding.
- `/rt debug`, `/rt test <text>`, `/rt log`, `/rt reregister`.

## [0.1.0] - 2026-04-19

Initial working draft (did not survive contact with a live 2.4.3 client;
kept for history).
