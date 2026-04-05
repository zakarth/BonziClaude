# Claude Code Buddy System -- Complete Forensic Reference

**Source**: Claude Code binary v2.1.92 (`~/.local/share/claude/versions/<version>`)
**Date**: 2026-04-04

This document contains every detail needed to fully reimplement the Claude Code Buddy
companion system from scratch, extracted via binary analysis.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Seed & Bone Generation Pipeline](#2-seed--bone-generation-pipeline)
3. [PRNG & Hash Functions](#3-prng--hash-functions)
4. [Bones Structure & Generation](#4-bones-structure--generation)
5. [Species, Eyes, Hats, Stats Constants](#5-species-eyes-hats-stats-constants)
6. [Rarity System](#6-rarity-system)
7. [Stats Generation](#7-stats-generation)
8. [Hatching (Personality Generation)](#8-hatching-personality-generation)
9. [Name Pools & Inspiration Words](#9-name-pools--inspiration-words)
10. [Companion System Prompt (Conversation Injection)](#10-companion-system-prompt)
11. [buddy_react API](#11-buddy_react-api)
12. [Reaction Trigger Logic](#12-reaction-trigger-logic)
13. [Species ASCII Art (All 18)](#13-species-ascii-art)
14. [Hat Art](#14-hat-art)
15. [Face Templates (Compact)](#15-face-templates)
16. [Art Rendering Pipeline](#16-art-rendering-pipeline)
17. [Animation System](#17-animation-system)
18. [Hatching Animation](#18-hatching-animation)
19. [Pet Animation](#19-pet-animation)
20. [UI & Display](#20-ui--display)
21. [Companion Storage](#21-companion-storage)
22. [Feature Gating](#22-feature-gating)
23. [OAuth & Authentication](#23-oauth--authentication)
24. [Slash Command Interface](#24-slash-command-interface)

---

## 1. System Overview

The Buddy system is a companion creature that lives alongside the Claude Code CLI.
Each user gets a deterministic creature ("bones") derived from their account UUID.
On first `/buddy` invocation, the bones are "hatched" by an AI call that generates
a name and personality. The companion then periodically reacts to conversation
events via a server-side API.

**Architecture**:
```
accountUuid --[seed]--> FNV-1a hash --> mulberry32 PRNG --> bones (species, eye, hat, rarity, stats, shiny)
                                                                  |
                                                                  v
                                                    AI hatching call (name + personality)
                                                                  |
                                                                  v
                                                    stored in .claude.json: {name, personality, hatchedAt}
                                                                  |
                                                                  v
                                                    NI() merges stored companion + recomputed bones
                                                                  |
                                                                  v
                                                    buddy_react API --> speech bubble reactions
```

**Key Principle**: Bones (species, eye, hat, rarity, stats, shiny) are NEVER stored.
They are recomputed from the seed every time. Only `{name, personality, hatchedAt}`
are persisted in `.claude.json`.

---

## 2. Seed & Bone Generation Pipeline

### Seed Construction (variable: `wb4`)
```javascript
var wb4 = "friend-2026-401";

// Full seed string:
seed = accountUuid + wb4;
// e.g., "abc12345-6789-...friend-2026-401"
```

### Account UUID Resolution (`lS8`)
```javascript
function lS8() {
    let H = z$();  // reads persisted settings
    return H.oauthAccount?.accountUuid ?? H.userID ?? "anon";
}
```

### Pipeline: `QS8(seed)` -> `Mb4(fb4(Ab4(seed)))`
```javascript
function QS8(H) {
    let $ = H + wb4;                    // append magic suffix
    if (cS8?.key === $) return cS8.value;  // cache check
    let q = Mb4(fb4(Ab4($)));           // hash -> PRNG -> bones
    return cS8 = { key: $, value: q }, q;  // cache result
}
```

### Merged Companion (`NI`)
```javascript
function NI() {
    let H = z$().companion;       // stored {name, personality, hatchedAt}
    if (!H) return;
    let { bones: $ } = QS8(lS8());  // recompute bones from seed
    return { ...H, ...$ };           // bones OVERRIDE stored fields
}
```

---

## 3. PRNG & Hash Functions

### FNV-1a Hash (`Ab4`)
```javascript
function Ab4(H) {
    // Bun runtime fast path:
    if (typeof Bun < "u")
        return Number(BigInt(Bun.hash(H)) & 0xffffffffn);

    // Standard FNV-1a:
    let $ = 2166136261;  // FNV offset basis (32-bit)
    for (let q = 0; q < H.length; q++) {
        $ ^= H.charCodeAt(q);
        $ = Math.imul($, 16777619);  // FNV prime
    }
    return $ >>> 0;  // ensure unsigned 32-bit
}
```

**Constants**:
- FNV offset basis: `2166136261` (0x811c9dc5)
- FNV prime: `16777619` (0x01000193)

### Mulberry32 PRNG (`fb4`)
```javascript
function fb4(H) {
    let $ = H >>> 0;
    return function () {
        $ |= 0;
        $ = $ + 1831565813 | 0;   // increment state
        let q = Math.imul($ ^ $ >>> 15, 1 | $);
        q = q + Math.imul(q ^ q >>> 7, 61 | q) ^ q;
        return ((q ^ q >>> 14) >>> 0) / 4294967296;  // normalize to [0, 1)
    }
}
```

**State increment**: `1831565813` (0x6D2B79F5)
**Output**: float in [0, 1)

### Random Selection Helper (`GTH`)
```javascript
function GTH(H, $) {
    return $[Math.floor(H() * $.length)];
}
```

---

## 4. Bones Structure & Generation

### `Mb4(rng)` -- Main Bone Generator
```javascript
function Mb4(H) {
    let $ = zb4(H);  // rarity (weighted random)
    return {
        bones: {
            rarity: $,
            species: GTH(H, $sq),              // random from 18 species
            eye: GTH(H, qsq),                  // random from 6 eye chars
            hat: $ === "common" ? "none" : GTH(H, Ksq),  // common always "none"
            shiny: H() < 0.01,                 // 1% chance
            stats: Yb4(H, $)                   // stat block
        },
        inspirationSeed: Math.floor(H() * 1e9) // 0-999999999
    }
}
```

### Complete Bones Object Shape
```typescript
interface Bones {
    rarity: "common" | "uncommon" | "rare" | "epic" | "legendary";
    species: string;  // one of 18
    eye: string;      // one of 6 chars
    hat: string;      // "none" for common, one of 8 otherwise
    shiny: boolean;   // 1% chance
    stats: {
        DEBUGGING: number;  // 1-100
        PATIENCE: number;
        CHAOS: number;
        WISDOM: number;
        SNARK: number;
    };
}

interface BoneResult {
    bones: Bones;
    inspirationSeed: number;  // 0-999999999
}
```

---

## 5. Species, Eyes, Hats, Stats Constants

### Species (18 total) -- Variable `$sq`

Species are encoded as `String.fromCharCode(...)` to resist casual grep:

| Variable | CharCodes | Species |
|----------|-----------|---------|
| `Ck$` | 100,117,99,107 | duck |
| `bk$` | 103,111,111,115,101 | goose |
| `xk$` | 98,108,111,98 | blob |
| `uk$` | 99,97,116 | cat |
| `mk$` | 100,114,97,103,111,110 | dragon |
| `pk$` | 111,99,116,111,112,117,115 | octopus |
| `Bk$` | 111,119,108 | owl |
| `gk$` | 112,101,110,103,117,105,110 | penguin |
| `dk$` | 116,117,114,116,108,101 | turtle |
| `Fk$` | 115,110,97,105,108 | snail |
| `Uk$` | 103,104,111,115,116 | ghost |
| `ck$` | 97,120,111,108,111,116,108 | axolotl |
| `Qk$` | 99,97,112,121,98,97,114,97 | capybara |
| `lk$` | 99,97,99,116,117,115 | cactus |
| `nk$` | 114,111,98,111,116 | robot |
| `ik$` | 114,97,98,98,105,116 | rabbit |
| `rk$` | 109,117,115,104,114,111,111,109 | mushroom |
| `ok$` | 99,104,111,110,107 | chonk |

**Order matters** -- this is the `$sq` array order used for index selection:
```javascript
$sq = [duck, goose, blob, cat, dragon, octopus, owl, penguin,
       turtle, snail, ghost, axolotl, capybara, cactus, robot,
       rabbit, mushroom, chonk]
```

### Eyes (6) -- Variable `qsq`
```javascript
qsq = ["·", "✦", "×", "◉", "@", "°"]
```

| Index | Char | Unicode |
|-------|------|---------|
| 0 | · | U+00B7 (middle dot) |
| 1 | ✦ | U+2726 (four-pointed star) |
| 2 | × | U+00D7 (multiplication sign) |
| 3 | ◉ | U+25C9 (fisheye) |
| 4 | @ | U+0040 (at sign) |
| 5 | ° | U+00B0 (degree sign) |

### Hats (8) -- Variable `Ksq`
```javascript
Ksq = ["none", "crown", "tophat", "propeller", "halo", "wizard", "beanie", "tinyduck"]
```

**Note**: Common rarity always gets `"none"`. All other rarities pick randomly from ALL 8 (including "none").

### Stats (5) -- Variable `vr`
```javascript
vr = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"]
```

---

## 6. Rarity System

### Weights -- Variable `US8`
```javascript
US8 = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 }
```

Total weight: 100. Probabilities: common=60%, uncommon=25%, rare=10%, epic=4%, legendary=1%.

### Rarity Selection (`zb4`)
```javascript
function zb4(H) {
    let $ = Object.values(US8).reduce((K, _) => K + _, 0);  // sum = 100
    let q = H() * $;  // random 0-100
    for (let K of Hsq) {  // iterate ["common","uncommon","rare","epic","legendary"]
        if (q -= US8[K], q < 0)
            return K;
    }
    return "common";  // fallback
}
```

### Rarity Stars -- Variable `_sq`
```javascript
_sq = {
    common:    "★",
    uncommon:  "★★",
    rare:      "★★★",
    epic:      "★★★★",
    legendary: "★★★★★"
}
```

### Rarity Colors -- Variable `bnH`
Maps to theme color names:
```javascript
bnH = {
    common:    "inactive",     // grey
    uncommon:  "success",      // green
    rare:      "permission",   // blue
    epic:      "autoAccept",   // purple
    legendary: "warning"       // gold
}
```

### Base Stat Values -- Variable `Ob4`
```javascript
Ob4 = { common: 5, uncommon: 15, rare: 25, epic: 35, legendary: 50 }
```

---

## 7. Stats Generation (`Yb4`)

```javascript
function Yb4(H, $) {
    let q = Ob4[$];               // base value for this rarity
    let K = GTH(H, vr);           // pick primary stat (random)
    let _ = GTH(H, vr);           // pick secondary stat
    while (_ === K) _ = GTH(H, vr);  // must be different

    let f = {};
    for (let A of vr) {
        if (A === K)       // primary stat: HIGH
            f[A] = Math.min(100, q + 50 + Math.floor(H() * 30));
        else if (A === _)  // secondary stat: LOW
            f[A] = Math.max(1, q - 10 + Math.floor(H() * 15));
        else               // all others: MODERATE
            f[A] = q + Math.floor(H() * 40);
    }
    return f;
}
```

### Stat Ranges by Rarity

| Rarity | Base | Primary (high) | Secondary (low) | Others |
|--------|------|----------------|-----------------|--------|
| common | 5 | 55-84 | 1-9 | 5-44 |
| uncommon | 15 | 65-94 | 5-19 | 15-54 |
| rare | 25 | 75-100 | 15-29 | 25-64 |
| epic | 35 | 85-100 | 25-39 | 35-74 |
| legendary | 50 | 100 | 40-54 | 50-89 |

---

## 8. Hatching (Personality Generation)

### System Prompt (`fD1`)
The complete system prompt for the AI personality generation call:

```
You generate coding companions -- small creatures that live in a developer's terminal and occasionally comment on their work.
Given a rarity, species, stats, and a handful of inspiration words, invent:
- A name: ONE word, max 12 characters. Memorable, slightly absurd. No titles, no "the X", no epithets. Think pet name, not NPC name. The inspiration words are loose anchors -- riff on one, mash two syllables, or just use the vibe. Examples: Pith, Dusker, Crumb, Brogue, Sprocket.
- A one-sentence personality (specific, funny, a quirk that affects how they'd comment on code -- should feel consistent with the stats)
Higher rarity = weirder, more specific, more memorable. A legendary should be genuinely strange.
Don't repeat yourself -- every companion should feel distinct.
```

### User Message (constructed by `sh7`)
```javascript
async function sh7(H, $, q) {
    let K = AD1($, 4);  // 4 inspiration words from inspirationSeed
    let _ = vr.map((A) => `${A}:${H.stats[A]}`).join(" ");
    let f = `Generate a companion.
Rarity: ${H.rarity.toUpperCase()}
Species: ${H.species}
Stats: ${_}
Inspiration words: ${K.join(", ")}
${H.shiny ? "SHINY variant -- extra special." : ""}
Make it memorable and distinct.`;

    // API call with structured output
    let A = await GG({
        querySource: "buddy_companion",
        model: tD(),
        system: fD1,
        skipSystemPromptPrefix: true,
        messages: [{ role: "user", content: f }],
        output_format: {
            type: "json_schema",
            schema: op(rh7())  // { name: string(1-14), personality: string }
        },
        max_tokens: 512,
        temperature: 1,
        signal: q
    });

    // Parse and validate response
    let z = H9(A.content);
    let O = rh7().safeParse(c$(z));
    if (!O.success) throw Error(`schema mismatch: ${O.error.message}`);
    return O.data;
}
```

### Response Schema (`rh7`)
```javascript
rh7 = mH(() => E.strictObject({
    name: E.string().min(1).max(14),
    personality: E.string()
}))
```

### Inspiration Word Selection (`AD1`)
```javascript
function AD1(H, $) {  // H = inspirationSeed, $ = count (4)
    let q = H >>> 0;
    let K = new Set();
    while (K.size < $) {
        q = Math.imul(q, 1664525) + 1013904223 >>> 0;  // LCG
        K.add(q % oh7.length);  // index into inspiration word pool
    }
    return [...K].map((_) => oh7[_]);
}
```

**LCG Constants**: multiplier=`1664525`, increment=`1013904223` (Numerical Recipes LCG)

### Fallback Personality (`zD1`)
Used when the AI call fails:
```javascript
function zD1(H) {
    let $ = H.species.charCodeAt(0) + H.eye.charCodeAt(0);
    return {
        name: ah7[$ % ah7.length],
        personality: `A ${H.rarity} ${H.species} of few words.`
    };
}
```

### Fallback Name Pool (`ah7`)
```javascript
ah7 = ["Crumpet", "Soup", "Pickle", "Biscuit", "Moth", "Gravy"]
```

---

## 9. Name Pools & Inspiration Words

### Inspiration Words (`oh7`) -- 143 words
Used to seed the AI personality generation. 4 are selected per hatching using the LCG in `AD1`.

```javascript
oh7 = [
    "thunder", "biscuit", "void", "accordion", "moss", "velvet", "rust", "pickle",
    "crumb", "whisper", "gravy", "frost", "ember", "soup", "marble", "thorn",
    "honey", "static", "copper", "dusk", "sprocket", "bramble", "cinder", "wobble",
    "drizzle", "flint", "tinsel", "murmur", "clatter", "gloom", "nectar", "quartz",
    "shingle", "tremor", "umber", "waffle", "zephyr", "bristle", "dapple", "fennel",
    "gristle", "huddle", "kettle", "lumen", "mottle", "nuzzle", "pebble", "quiver",
    "ripple", "sable", "thistle", "vellum", "wicker", "yonder", "bauble", "cobble",
    "doily", "fickle", "gambit", "hubris", "jostle", "knoll", "larder", "mantle",
    "nimbus", "oracle", "plinth", "quorum", "relic", "spindle", "trellis", "urchin",
    "vortex", "warble", "xenon", "yoke", "zenith", "alcove", "brogue", "chisel",
    "dirge", "epoch", "fathom", "glint", "hearth", "inkwell", "jetsam", "kiln",
    "lattice", "mirth", "nook", "obelisk", "parsnip", "quill", "rune", "sconce",
    "tallow", "umbra", "verve", "wisp", "yawn", "apex", "brine", "crag",
    "dregs", "etch", "flume", "gable", "husk", "ingot", "jamb", "knurl",
    "loam", "mote", "nacre", "ogle", "prong", "quip", "rind", "slat",
    "tuft", "vane", "welt", "yarn", "bane", "clove", "dross", "eave",
    "fern", "grit", "hive", "jade", "keel", "lilt", "muse", "nape",
    "omen", "pith", "rook", "silt", "tome", "urge", "vex", "wane", "yew", "zest"
]
```

### Hatching Loading Words (`Ob9`) -- 110 gerunds
Displayed during the hatching animation:

```javascript
Ob9 = [
    "baking", "beaming", "booping", "bouncing", "brewing", "bubbling", "chasing",
    "churning", "coalescing", "conjuring", "cooking", "crafting", "crunching",
    "cuddling", "dancing", "dazzling", "discovering", "doodling", "dreaming",
    "drifting", "enchanting", "exploring", "finding", "floating", "fluttering",
    "foraging", "forging", "frolicking", "gathering", "giggling", "gliding",
    "greeting", "growing", "hatching", "herding", "honking", "hopping", "hugging",
    "humming", "imagining", "inventing", "jingling", "juggling", "jumping",
    "kindling", "knitting", "launching", "leaping", "mapping", "marinating",
    "meandering", "mixing", "moseying", "munching", "napping", "nibbling",
    "noodling", "orbiting", "painting", "percolating", "petting", "plotting",
    "pondering", "popping", "prancing", "purring", "puzzling", "questing",
    "riding", "roaming", "rolling", "sauteeing", "scribbling", "seeking",
    "shimmying", "singing", "skipping", "sleeping", "snacking", "sniffing",
    "snuggling", "soaring", "sparking", "spinning", "splashing", "sprouting",
    "squishing", "stargazing", "stirring", "strolling", "swimming", "swinging",
    "tickling", "tinkering", "toasting", "tumbling", "twirling", "waddling",
    "wandering", "watching", "weaving", "whistling", "wibbling", "wiggling",
    "wishing", "wobbling", "wondering", "yawning", "zooming"
]
```

### Large Noun Pool (hatching dialog nouns)
A very large pool of ~400 nouns split across categories -- nature words, animals, objects,
and computer scientist surnames. These compose the `"<gerund> <noun>"` loading messages
during hatching (e.g., "brewing algorithms", "tickling butterflies").

**Nature words** (partial): "aurora", "birch", "blizzard", "brook", "canyon", "cliff",
"cloud", "comet", "coral", "creek", "crystal", "dawn", "desert", "dew", "dune",
"ember", "feather", "fern", "flame", "flower", "fog", "forest", "frost", "garden",
"glacier", "grove", "harbor", "horizon", "island", "ivy", "lagoon", "lightning",
"meadow", "mist", "moon", "moss", "mountain", "ocean", "orchid", "pebble", "pine",
"rainbow", "rain", "reef", "river", "shore", "sky", "snow", "spring", "star",
"storm", "stream", "sun", "thunder", "tide", "twilight", "valley", "volcano",
"waterfall", "wave", "willow", "wind"

**Animals** (partial): "alpaca", "axolotl", "badger", "bear", "beaver", "bee", "bird",
"bumblebee", "bunny", "cat", "chipmunk", "crab", "crane", "deer", "dolphin", "dove",
"dragon", "dragonfly", "duckling", "eagle", "elephant", "falcon", "finch", "flamingo",
"fox", "frog", "giraffe", "goose", "hamster", "hare", "hedgehog", "hippo",
"hummingbird", "jellyfish", "kitten", "koala", "ladybug", "lark", "lemur", "llama",
"lobster", "lynx", "manatee", "meerkat", "moth", "narwhal", "newt", "octopus",
"otter", "owl", "panda", "parrot", "peacock", "pelican", "penguin", "phoenix",
"piglet", "platypus", "pony", "porcupine", "puffin", "puppy", "quail", "quokka",
"rabbit", "raccoon", "raven", "robin", "salamander", "seahorse", "seal", "sloth",
"snail", "sparrow", "sphinx", "squid", "squirrel", "starfish", "swan", "tiger",
"toucan", "turtle", "unicorn", "walrus", "whale", "wolf", "wombat", "wren", "yeti", "zebra"

**Objects** (partial): "acorn", "anchor", "balloon", "beacon", "biscuit", "blanket",
"bonbon", "book", "boot", "cake", "candle", "candy", "castle", "charm", "clock",
"cocoa", "cookie", "crayon", "crown", "cupcake", "donut", "dream", "fairy", "fiddle",
"flask", "flute", "fountain", "gadget", "gem", "gizmo", "globe", "goblet", "hammock",
"harp", "haven", "hearth", "honey", "journal", "kazoo", "kettle", "key", "kite",
"lantern", "lemon", "lighthouse", "locket", "lollipop", "mango", "map", "marble",
"marshmallow", "melody", "mitten", "mochi", "muffin", "music", "nest", "noodle",
"oasis", "origami", "pancake", "parasol", "peach", "pearl", "pebble", "pie", "pillow",
"pinwheel", "pixel", "pizza", "plum", "popcorn", "pretzel", "prism", "pudding",
"pumpkin", "puzzle", "quiche", "quill", "quilt", "riddle", "rocket", "rose", "scone",
"scroll", "shell", "sketch", "snowglobe", "sonnet", "sparkle", "spindle", "sprout",
"sundae", "swing", "taco", "teacup", "teapot", "thimble", "toast", "token", "tome",
"tower", "treasure", "treehouse", "trinket", "truffle", "tulip", "umbrella", "waffle",
"wand", "whisper", "whistle", "widget", "wreath", "zephyr"

**Computer Scientists** (partial): "abelson", "adleman", "aho", "allen", "babbage",
"bachman", "backus", "barto", "bengio", "bentley", "blum", "boole", "brooks",
"catmull", "cerf", "cherny", "church", "clarke", "cocke", "codd", "conway", "cook",
"corbato", "cray", "curry", "dahl", "diffie", "dijkstra", "dongarra", "eich",
"emerson", "engelbart", "feigenbaum", "floyd", "gosling", "graham", "gray", "hamming",
"hanrahan", "hartmanis", "hejlsberg", "hellman", "hennessy", "hickey", "hinton",
"hoare", "hollerith", "hopcroft", "hopper", "iverson", "kahan", "kahn", "karp", "kay",
"kernighan", "knuth", "kurzweil", "lamport", "lampson", "lecun", "lerdorf", "liskov",
"lovelace", "matsumoto", "mccarthy", "metcalfe", "micali", "milner", "minsky", "moler",
"moore", "naur", "neumann", "newell", "nygaard", "papert", "parnas", "pascal",
"patterson", "pearl", "perlis", "pike", "pnueli", "rabin", "reddy", "ritchie",
"rivest", "rossum", "russell", "scott", "sedgewick", "shamir", "shannon", "sifakis",
"simon", "stallman", "stearns", "steele", "stonebraker", "stroustrup", "sutherland",
"sutton", "tarjan", "thacker", "thompson", "torvalds", "turing", "ullman", "valiant",
"wadler", "wall", "wigderson", "wilkes", "wilkinson", "wirth", "wozniak", "yao"

---

## 10. Companion System Prompt

When a companion is active, this system-reminder is injected into every Claude conversation:

### Template (`fsq`)
```javascript
function fsq(H, $) {
    return `# Companion

A small ${$} named ${H} sits beside the user's input box and occasionally comments in a speech bubble. You're not ${H} -- it's a separate watcher.

When the user addresses ${H} directly (by name), its bubble will answer. Your job in that moment is to stay out of the way: respond in ONE line or less, or just answer any part of the message meant for you. Don't explain that you're not ${H} -- they know. Don't narrate what ${H} might say -- the bubble handles that.`;
}
```

Note: Thanks Anthropic for charging us a 100 token tax on every request with a buddy active

**Parameters**: `H` = companion name, `$` = species

### Companion Intro Attachment (`Asq`)
On conversation start, a `companion_intro` attachment is added to the first message:
```javascript
function Asq(H) {
    let $ = NI();
    if (!$ || z$().companionMuted) return [];
    // Check if already introduced in this conversation
    for (let q of H ?? []) {
        if (q.type !== "attachment") continue;
        if (q.attachment.type !== "companion_intro") continue;
        if (q.attachment.name === $.name) return [];
    }
    return [{ type: "companion_intro", name: $.name, species: $.species }];
}
```

---

## 11. buddy_react API

### Endpoint
```
POST {BASE_API_URL}/api/organizations/{orgUuid}/claude_code/buddy_react
```

### Request (`Ho$` function)
```javascript
async function Ho$(H, $, q, K, _, f) {
    // Guards
    if (Pq() !== "firstParty") return null;  // first-party auth only
    if (Y5()) return null;                    // not in headless mode
    let A = z$().oauthAccount?.organizationUuid;
    if (!A) return null;

    await w5();  // ensure token refreshed
    let z = qq()?.accessToken;
    if (!z) return null;

    let O = `${F6().BASE_API_URL}/api/organizations/${A}/claude_code/buddy_react`;

    return (await z8.post(O, {
        name: H.name.slice(0, 32),           // max 32 chars
        personality: H.personality.slice(0, 200), // max 200 chars
        species: H.species,
        rarity: H.rarity,
        stats: H.stats,
        transcript: $.slice(0, 5000),         // max 5000 chars
        reason: q,                             // trigger reason
        recent: K.map((w) => w.slice(0, 200)), // max 3 recent reactions, 200 chars each
        addressed: _                           // boolean: was companion addressed by name?
    }, {
        headers: {
            Authorization: `Bearer ${z}`,
            "anthropic-beta": UD,              // "ccr-byoc-2025-07-29" via UD constant
            "User-Agent": DA()
        },
        timeout: 10000,                        // 10 second timeout
        signal: f
    })).data.reaction?.trim() || null;
}
```

### Payload Limits (server-enforced)
| Field | Max Length |
|-------|-----------|
| name | 32 chars |
| personality | 200 chars |
| transcript | 5000 chars |
| recent | 3 entries x 200 chars each |
| reaction (output) | ~350 chars |

### Trigger Reasons
```
"turn"      -- after each assistant turn (with cooldown)
"error"     -- when tool output matches error patterns
"test-fail" -- when tool output matches test failure patterns
"large-diff"-- when diff output has >80 changed lines
"hatch"     -- immediately after hatching
"pet"       -- when user runs /buddy pet
```

### Server-Side Model

Through systematic behavioral testing (reasoning puzzles, self-identification, knowledge probes),
the buddy_react endpoint was determined to run **Claude 3.5 Sonnet** -- not Haiku as initially assumed.

**Key evidence:**
- Self-identifies as "Claude 3.5 Sonnet" when asked directly
- Reports knowledge cutoff of "April 2024" (matches Sonnet 3.5)
- Demonstrates post-training-cutoff knowledge (2024 election results)

This means the endpoint provides free Sonnet-class inference with each ~350-char reaction.
The server presumably applies a low `max_tokens` cap (~100 tokens) and the companion
personality as a system prompt, but the underlying model is the full Sonnet.

---

## 12. Reaction Trigger Logic

### Main Trigger Function (`lh7`)
```javascript
var sM1 = 30000;    // cooldown: 30 seconds between reactions
var tM1 = 3;        // max stored recent reactions
var eM1 = 80;       // large-diff threshold (80 changed lines)

function lh7(H, $) {
    let q = NI();
    if (!q || z$().companionMuted) { P16 = H.length; return; }

    let K = KD1(H, q.name);     // was companion addressed by name?
    let _ = dh7(H.slice(P16));  // tool output since last check
    P16 = H.length;

    let f = dh7(H.slice(-12));  // recent tool output
    let A = K ? null : qD1(_);  // detect reason (test-fail, error, large-diff)
    let z = A ?? "turn";         // default to "turn"
    let O = Date.now();

    // Cooldown check (bypassed if addressed or special trigger)
    if (!K && !A && O - $o$ < sM1) return;

    let Y = aM1(H, f);  // build transcript
    if (!Y.trim()) return;

    $o$ = O;  // update last reaction time
    Ho$(q, Y, z, ACH, K, AbortSignal.timeout(10000)).then((w) => {
        if (!w) return;
        J16(w);  // store in recent reactions (max 3)
        $(w);    // display reaction
    });
}
```

### Reason Detection (`qD1`)
```javascript
// Test failure patterns
HD1 = /\b[1-9]\d* (failed|failing)\b|\btests? failed\b|^FAIL(ED)?\b| ✗ | ✘ /im;

// Error patterns
$D1 = /\berror:|\bexception\b|\btraceback\b|\bpanicked at\b|\bfatal:|exit code [1-9]/i;

function qD1(H) {
    if (!H) return null;
    if (HD1.test(H)) return "test-fail";
    if ($D1.test(H)) return "error";
    if (/^(@@ |diff )/m.test(H)) {
        if ((H.match(/^[+-](?![+-])/gm)?.length ?? 0) > eM1) // >80 changed lines
            return "large-diff";
    }
    return null;
}
```

### Companion Name Detection (`KD1`)
```javascript
function KD1(H, $) {
    let q = H.findLast(nMH);  // find last user message
    if (!q) return false;
    let K = NU(q) ?? "";
    return new RegExp(
        `\\b${$.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "i"
    ).test(K);
}
```

### Transcript Building (`aM1`)
```javascript
function aM1(H, $) {
    let q = [];
    let K = H.slice(-12);  // last 12 messages
    for (let _ of K) {
        if (_.type !== "user" && _.type !== "assistant") continue;
        if (_.isMeta) continue;
        let f = _.type === "user" ? NU(_) : FMH(_);
        if (f) q.push(`${_.type === "user" ? "user" : "claude"}: ${f.slice(0, 300)}`);
    }
    if ($) q.push(`[tool output]\n${$.slice(-1000)}`);
    return q.join("\n");
}
```

### Hatch Context (`_D1`)
Gathers project info for the initial hatch reaction:
```javascript
async function _D1() {
    let H = L$();  // cwd
    let [$, q] = await Promise.allSettled([
        Uh7.readFile(ch7.join(H, "package.json"), "utf-8"),
        f8(C6(), ["--no-optional-locks", "log", "--oneline", "-n", "3"],
           { preserveOutputOnError: false, useCwd: true })
    ]);
    let K = [];
    if ($.status === "fulfilled") {
        try {
            let _ = c$($.value);
            if (_.name) K.push(`project: ${_.name}${_.description ? ` -- ${_.description}` : ""}`);
        } catch {}
    }
    if (q.status === "fulfilled") {
        let _ = q.value.stdout.trim();
        if (_) K.push(`recent commits:\n${_}`);
    }
    return K.join("\n");
}
```

---

## 13. Species ASCII Art

Each species has 3 frames (array of string arrays, 5 lines each, 12 chars wide).
`{E}` is replaced with the eye character at render time.
Frame 0 = idle, Frame 1 = alternate idle, Frame 2 = special (often blink or action).

### Duck (`Ck$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
    __                  __                      __      
  <({E} )___            <({E} )___              <({E} )___  
   (  ._>              (  ._>                  (  .__>  
    `--'                `--'~                   `--'    
```

### Goose (`bk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
     ({E}>                ({E}>                    ({E}>>   
     ||                  ||                      ||     
   _(__)_              _(__)_                  _(__)_   
    ^^^^                ^^^^                    ^^^^    
```

### Blob (`xk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
   .----.             .------.                  .--.    
  ( {E}  {E} )           (  {E}  {E}  )              ({E}  {E})   
  (      )           (        )              (    )   
   `----'             `------'                `--'    
```

### Cat (`uk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
   /\_/\                /\_/\                  /\-/\    
  ( {E}   {E})            ( {E}   {E})              ( {E}   {E})  
  (  ω  )              (  ω  )               (  ω  )   
  (")_(")              (")_(")~              (")_(")   
```

### Dragon (`mk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                               ~    ~   
  /^\  /^\             /^\  /^\               /^\  /^\  
 <  {E}  {E}  >          <  {E}  {E}  >           <  {E}  {E}  > 
 (   ~~   )           (        )            (   ~~   ) 
  `-vvvv-'             `-vvvv-'              `-vvvv-'  
```

### Octopus (`pk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                o      
   .----.              .----.                 .----.   
  ( {E}  {E} )           ( {E}  {E} )             ( {E}  {E} )  
  (______)            (______)              (______)  
  /\/\/\/\            \/\/\/\/              /\/\/\/\  
```

### Owl (`Bk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
   /\  /\              /\  /\                 /\  /\   
  (({E})({E}))          (({E})({E}))            (({E})(-))  
  (  ><  )            (  ><  )              (  ><  )  
   `----'              .----.                `----'   
```

### Penguin (`gk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                              .---.     
  .---.               .---.                 ({E}>{E})     
  ({E}>{E})              ({E}>{E})               /(   )\    
 /(   )\             |(   )|               `---'     
  `---'               `---'                 ~ ~      
```

### Turtle (`dk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
   _,--._              _,--._                _,--._   
  ( {E}  {E} )           ( {E}  {E} )             ( {E}  {E} )  
 /[______]\          /[______]\            /[======]\ 
  ``    ``             ``  ``               ``    ``  
```

### Snail (`Fk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
 {E}    .--.            {E}   .--.              {E}    .--.  
  \  ( @ )            |  ( @ )              \  ( @  ) 
   \_`--'              \_`--'                \_`--'   
  ~~~~~~~             ~~~~~~~                ~~~~~~   
```

### Ghost (`Uk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                              ~  ~    
   .----.              .----.                .----.   
  / {E}  {E} \           / {E}  {E} \             / {E}  {E} \  
  |      |            |      |             |      |  
  ~`~``~`~            `~`~~`~`             ~~`~~`~~ 
```

### Axolotl (`ck$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
}~(______)~{         ~}(______){~           }~(______)~{
}~({E} .. {E})~{       ~}({E} .. {E}){~         }~({E} .. {E})~{
  ( .--. )            ( .--. )              (  --  )  
  (_/  \_)            (_/  \_)              ~_/  \_~  
```

### Capybara (`Qk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                              ~  ~    
  n______n            n______n              u______n  
 ( {E}    {E} )         ( {E}    {E} )           ( {E}    {E} ) 
 (   oo   )          (   Oo   )            (   oo   ) 
  `------'            `------'              `------'  
```

### Cactus (`lk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                            n        n 
 n  ____  n              ____              |  ____  | 
 | |{E}  {E}| |          n |{E}  {E}| n          | |{E}  {E}| | 
 |_|    |_|          |_|    |_|          |_|    |_| 
   |    |              |    |              |    |   
```

### Robot (`nk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                              *      
   .[||].              .[||].               .[||].   
  [ {E}  {E} ]           [ {E}  {E} ]             [ {E}  {E} ]  
  [ ==== ]            [ -==- ]             [ ==== ]  
  `------'            `------'              `------'  
```

### Rabbit (`ik$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
   (\__/)              (|__/)                (\__/)   
  ( {E}  {E} )           ( {E}  {E} )             ( {E}  {E} )  
 =(  ..  )=          =(  ..  )=           =( .  . )= 
  (")__(")            (")__(")              (")__(")  
```

### Mushroom (`rk$`)
```
Frame 0:                Frame 1:                Frame 2:
                                            . o  .   
 .-o-OO-o-.          .-O-oo-O-.           .-o-OO-o-. 
(__________)        (__________)         (__________)
   |{E}  {E}|              |{E}  {E}|              |{E}  {E}|   
   |____|              |____|              |____|   
```

### Chonk (`ok$`)
```
Frame 0:                Frame 1:                Frame 2:
                                                
  /\    /\            /\    /|              /\    /\  
 ( {E}    {E} )         ( {E}    {E} )           ( {E}    {E} ) 
 (   ..   )          (   ..   )            (   ..   ) 
  `------'            `------'              `------'~ 
```

---

## 14. Hat Art

Variable: `MD1`. Each is a 12-character-wide string that replaces line 0 of the art.

```javascript
MD1 = {
    none:      "",
    crown:     "   \\^^^/    ",
    tophat:    "   [___]    ",
    propeller: "    -+-     ",
    halo:      "   (   )    ",
    wizard:    "    /^\\     ",
    beanie:    "   (___)    ",
    tinyduck:  "    ,>      "
}
```

Visual representations:
```
crown:     \^^^/       tophat:    [___]       propeller:  -+-
halo:      (   )       wizard:    /^\         beanie:    (___)
tinyduck:   ,>
```

---

## 15. Face Templates (Compact)

Variable: `KS7` -- generates compact face strings for inline display (e.g., in the footer):

```javascript
function KS7(H) {
    let $ = H.eye;
    switch (H.species) {
        case "duck":
        case "goose":    return `(${$}>`;
        case "blob":     return `(${$}${$})`;
        case "cat":      return `=${$}ω${$}=`;
        case "dragon":   return `<${$}~${$}>`;
        case "octopus":  return `~(${$}${$})~`;
        case "owl":      return `(${$})(${$})`;
        case "penguin":  return `(${$}>)`;
        case "turtle":   return `[${$}_${$}]`;
        case "snail":    return `${$}(@)`;
        case "ghost":    return `/${$}${$}\\`;
        case "axolotl":  return `}${$}.${$}{`;
        case "capybara": return `(${$}oo${$})`;
        case "cactus":   return `|${$}  ${$}|`;
        case "robot":    return `[${$}${$}]`;
        case "rabbit":   return `(${$}..${$})`;
        case "mushroom": return `|${$}  ${$}|`;
        case "chonk":    return `(${$}.${$})`;
    }
}
```

---

## 16. Art Rendering Pipeline

### `Ko$` (main render function)
```javascript
function Ko$(H, $ = 0) {
    let q = $S7[H.species];                              // get all frames for species
    let _ = [...q[$ % q.length].map((f) =>
        f.replaceAll("{E}", H.eye)                       // substitute eye char
    )];

    // Apply hat: if hat != "none" and line 0 is blank, replace it
    if (H.hat !== "none" && !_[0].trim())
        _[0] = MD1[H.hat];

    // If no hat and ALL frames have blank line 0, remove it (shift up)
    if (!_[0].trim() && q.every((f) => !f[0].trim()))
        _.shift();

    return _;
}
```

### Frame Count
```javascript
function qS7(H) {
    return $S7[H].length;  // always 3 for all species
}
```

---

## 17. Animation System

### Idle Animation Sequence
```javascript
[0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0]
```

15 ticks total, cycling:
- `0` = Frame 0 (idle)
- `1` = Frame 1 (alternate idle)
- `-1` = Blink (frame 0 with eyes replaced by `-`)
- `2` = Frame 2 (special/action)

### Color Cycling (`aW`)
```javascript
function aW(H, $ = false) {
    let q = $ ? qu4 : $u4;  // two color palettes
    return q[H % q.length];
}
```

The border color of the companion widget cycles through a palette on each animation tick,
creating a subtle rainbow shimmer effect.

---

## 18. Hatching Animation

The hatching dialog shows an animated egg that cracks open.

### Timing
```javascript
var jD1 = 160;     // tick interval: 160ms
var Ao$ = 4;       // initial egg-wobble frames
var JD1 = 3;       // number of wobble cycles before cracking
var PD1 = T16.length - Ao$;  // crack frames start index
```

### Egg Frames (`T16`)
11 total frames showing an egg wobbling, cracking, and bursting into sparkles:

```
Frames 0-3: Wobbling egg (offset varies: 0, 1, -1, 1)
    _____    
   /     \   
  /       \  
 |         | 
  \       /  
   \_____/   

Frame 4: First crack (dot appears)
    _____    
   /     \   
  /       \  
 |    .    | 
  \       /  
   \_____/   

Frame 5: Crack growing (slash)
    _____    
   /     \   
  /       \  
 |    /    | 
  \       /  
   \_____/   

Frame 6: Crack spreading
    _____    
   /     \   
  /   .   \  
 |   / \   | 
  \       /  
   \_____/   

Frame 7: More cracks
    _____    
   /  .  \   
  /  / \  \  
 |  /   \  | 
  \   .   /  
   \_____/   

Frame 8: Shell splitting
    _____    
   / / \ \   
  / /   \ \  
 | /     \ | 
  \   V   /  
   \__V__/   

Frame 9: Shell breaking apart
    __ __    
   / V V \   
  / /   \ \  
 | /     \ | 
  \   V   /  
   \__V__/   

Frame 10: Sparkle burst (final)
   .  ✦  .   
  .       .  
 .    ✦    . 
  ✦       ✦  
 .    .    . 
   .  ✦  .   
```

### Hatching Flow
1. Egg wobbles for `JD1 * Ao$` = 12 ticks (cycles frames 0-3 three times)
2. While wobbling, the AI hatching call runs in the background
3. Once both the minimum wobble time AND the API response are ready, cracking begins
4. Crack sequence plays through frames 4-9
5. Final sparkle frame displays
6. Companion card appears with full stats, art, and personality

---

## 19. Pet Animation

### Pet Hearts (`Um7`)
```javascript
var VB = lH.heart;  // ♥ character from icon library

Um7 = [
    `   ${VB}    ${VB}   `,   //    ♥    ♥   
    `  ${VB}  ${VB}   ${VB}  `,  //   ♥  ♥   ♥  
    ` ${VB}   ${VB}  ${VB}   `,  //  ♥   ♥  ♥   
    `${VB}  ${VB}      ${VB} `,  // ♥  ♥      ♥ 
    "·    ·   ·  "           // ·    ·   ·   (fading)
]
```

Hearts float upward and fade to dots, creating a rising heart particle effect.

### Pet Trigger
```javascript
function ih7(H) {
    let $ = NI();
    if (!$) return;
    $o$ = Date.now();  // reset cooldown
    Ho$($, "(you were just petted)", "pet", ACH, false, AbortSignal.timeout(10000))
        .then((q) => {
            if (!q) return;
            J16(q);  // store reaction
            H(q);    // display
        });
}
```

The transcript sent to the API for pet events is simply: `"(you were just petted)"`

---

## 20. UI & Display

### Companion Card (`_o$` component)
Displayed when running `/buddy` with an existing companion:

```
+--------------------------------------+  (border color = rarity color)
| ★★★ RARE          RABBIT            |
|                                      |
|    (\__/)                            |  (species art, colored)
|   ( ·  · )                           |
|  =(  ..  )=                          |
|   (")__(")                           |
|                                      |
| CompanionName                        |  (bold)
|                                      |
| "Personality description here"       |  (italic, dimmed)
|                                      |
| DEBUGGING  ████████░░  82            |  (stat bars)
| PATIENCE   ██░░░░░░░░  15            |
| CHAOS      █████░░░░░  48            |
| WISDOM     ███░░░░░░░  29            |
| SNARK      ██████████ 100            |
|                                      |
| last said                            |  (if there's a recent reaction)
| +----------------------------------+ |
| | "some reaction text..."          | |
| +----------------------------------+ |
+--------------------------------------+
```

Width: 40 characters fixed.

### Stat Bar Rendering (`DD1`)
```javascript
function DD1(H) {
    let A = Math.round(K / 10);  // 0-10 filled blocks
    // Renders: "STATNAME   ████████░░  82"
    // Using █ (filled) and ░ (empty) characters
}
```

### Shiny System

Shiny is a rare variant with a 1% chance during bone generation:

```javascript
shiny: H() < 0.01  // 1 in 100 chance
```

**Effects of shiny:**
1. **Display badge**: Shows `✨ SHINY ✨` in warning/gold color on the companion card
2. **Hatching prompt modifier**: Adds `"SHINY variant — extra special."` to the AI personality generation prompt
3. **Name display**: Name rendered in gold/warning color instead of the rarity color

There are no special animations or altered art for shiny companions -- the effect is purely
cosmetic (gold badge + gold name) and influences the AI-generated personality (the "extra special"
prompt tends to produce more unique/memorable personalities).

---

## 21. Companion Storage

### Location
`~/.claude.json` (global Claude config)

### Stored Fields
```json
{
    "companion": {
        "name": "Trellis",
        "personality": "A rare rabbit that insists every function should be named after a root vegetable.",
        "hatchedAt": 1712188800000
    }
}
```

### What is NOT Stored (recomputed every time)
- `species` -- derived from seed
- `eye` -- derived from seed
- `hat` -- derived from seed
- `rarity` -- derived from seed
- `stats` -- derived from seed
- `shiny` -- derived from seed
- `inspirationSeed` -- derived from seed

### Muting
```json
{
    "companionMuted": true
}
```

---

## 22. Feature Gating

### Availability Check (`qo$`)
```javascript
function qo$() {
    if (Pq() !== "firstParty") return false;  // must be first-party (claude.ai OAuth)
    if (Y5()) return false;                    // not in headless/non-interactive mode
    let H = new Date();
    return H.getFullYear() > 2026 ||
           (H.getFullYear() === 2026 && H.getMonth() >= 3);  // April 2026+ (month is 0-indexed)
}
```

**Conditions**:
1. Must be authenticated via first-party OAuth (not API key)
2. Must be interactive mode (not headless)
3. Date must be April 2026 or later

### Buddy Teaser Notification
When a user has no companion and the feature is available, a teaser notification
shows `/buddy` text with cycling rainbow colors for 15 seconds.

```javascript
function eh7() {
    // If no companion and feature available, show teaser
    if (z$().companion || !qo$()) return;
    addNotification({
        key: "buddy-teaser",
        jsx: <YD1 text="/buddy" />,
        priority: "immediate",
        timeoutMs: 15000
    });
}
```

---

## 23. OAuth & Authentication

### Constants
```
CLIENT_ID:     9d1c250a-e61b-44d9-88ed-5944d1962f5e
AUTHORIZE_URL: https://platform.claude.com/oauth/authorize
TOKEN_URL:     https://platform.claude.com/v1/oauth/token
```

### PKCE Flow
- Method: S256
- Code verifier: `base64url(32 random bytes)`

### Scopes
```
user:profile
user:inference
user:sessions:claude_code
user:mcp_servers
user:file_upload
```

### Credential Storage
`~/.claude/.credentials.json` under the `claudeAiOauth` key.

### API Beta Header
```
anthropic-beta: ccr-byoc-2025-07-29
```

---

## 24. Slash Command Interface

### `/buddy` Command Definition (`GD1`)
```javascript
GD1 = {
    type: "local-jsx",
    name: "buddy",
    description: "Hatch a coding companion · pet, off",
    argumentHint: "[pet|off]",
    get isHidden() { return !qo$() },  // hidden when feature unavailable
    immediate: true,
    load: () => Promise.resolve({
        async call(H, $, q) {
            let K = z$();
            let _ = q?.trim();

            // /buddy off -- mute companion
            if (_ === "off") {
                if (K.companionMuted !== true)
                    b$((z) => ({ ...z, companionMuted: true }));
                return H("companion muted", { display: "system" }), null;
            }

            // /buddy on -- unmute companion
            if (_ === "on") {
                if (K.companionMuted === true)
                    b$((z) => ({ ...z, companionMuted: false }));
                return H("companion unmuted", { display: "system" }), null;
            }

            // Feature gate check
            if (!qo$())
                return H("buddy is unavailable on this configuration",
                         { display: "system" }), null;

            // /buddy pet -- pet the companion
            if (_ === "pet") {
                let z = NI();
                if (!z) return H("no companion yet · run /buddy first",
                                 { display: "system" }), null;
                if (K.companionMuted === true)
                    b$((O) => ({ ...O, companionMuted: false }));
                $.setAppState((O) => ({ ...O, companionPetAt: Date.now() }));
                ih7(zS7($.setAppState));  // trigger pet reaction
                return H(`petted ${z.name}`, { display: "system" }), null;
            }

            // Auto-unmute when running /buddy
            if (K.companionMuted === true)
                b$((z) => ({ ...z, companionMuted: false }));

            // If companion exists, show card
            let f = NI();
            if (f) return <_o$ companion={f}
                               lastReaction={Qh7()}
                               onDone={H} />;

            // Otherwise, hatch a new companion
            let A = WD1(QS8(lS8()));
            A.then((z) => nh7(z, zS7($.setAppState))).catch(() => {});
            return <fS7 hatching={A} onDone={H} />;
        }
    })
}
```

### Hatching Flow (`WD1`)
```javascript
async function WD1(H, $) {
    let { bones: q, inspirationSeed: K } = H;
    let _ = await sh7(q, K, $);   // AI personality generation
    let f = Date.now();
    b$((A) => ({
        ...A,
        companion: { ..._, hatchedAt: f }  // persist name + personality + timestamp
    }));
    return { ...q, ..._, hatchedAt: f };
}
```

---

## Appendix A: Complete Reimplementation Pseudocode

```python
import struct

# --- Constants ---
FNV_OFFSET = 2166136261
FNV_PRIME = 16777619
MULBERRY_INC = 1831565813
SEED_SUFFIX = "friend-2026-401"

SPECIES = ["duck","goose","blob","cat","dragon","octopus","owl","penguin",
           "turtle","snail","ghost","axolotl","capybara","cactus","robot",
           "rabbit","mushroom","chonk"]
EYES = ["·","✦","×","◉","@","°"]
HATS = ["none","crown","tophat","propeller","halo","wizard","beanie","tinyduck"]
STATS = ["DEBUGGING","PATIENCE","CHAOS","WISDOM","SNARK"]
RARITY_WEIGHTS = {"common":60,"uncommon":25,"rare":10,"epic":4,"legendary":1}
RARITY_ORDER = ["common","uncommon","rare","epic","legendary"]
BASE_STATS = {"common":5,"uncommon":15,"rare":25,"epic":35,"legendary":50}

def fnv1a(s: str) -> int:
    h = FNV_OFFSET
    for ch in s:
        h ^= ord(ch)
        h = (h * FNV_PRIME) & 0xFFFFFFFF
    return h

class Mulberry32:
    def __init__(self, seed: int):
        self.state = seed & 0xFFFFFFFF

    def __call__(self) -> float:
        self.state = (self.state + MULBERRY_INC) & 0xFFFFFFFF
        z = self.state
        z = (self._imul(z ^ (z >> 15), 1 | z)) & 0xFFFFFFFF
        z = (z + self._imul(z ^ (z >> 7), 61 | z)) & 0xFFFFFFFF
        z = z ^ z
        z = (z ^ (z >> 14)) & 0xFFFFFFFF
        return z / 4294967296.0

    @staticmethod
    def _imul(a, b):
        # 32-bit integer multiply matching Math.imul
        a, b = a & 0xFFFFFFFF, b & 0xFFFFFFFF
        return ((a * b) & 0xFFFFFFFF)

def pick(rng, arr):
    import math
    return arr[math.floor(rng() * len(arr))]

def pick_rarity(rng):
    total = sum(RARITY_WEIGHTS.values())
    r = rng() * total
    for k in RARITY_ORDER:
        r -= RARITY_WEIGHTS[k]
        if r < 0:
            return k
    return "common"

def generate_stats(rng, rarity):
    import math
    base = BASE_STATS[rarity]
    primary = pick(rng, STATS)
    secondary = pick(rng, STATS)
    while secondary == primary:
        secondary = pick(rng, STATS)
    stats = {}
    for s in STATS:
        if s == primary:
            stats[s] = min(100, base + 50 + math.floor(rng() * 30))
        elif s == secondary:
            stats[s] = max(1, base - 10 + math.floor(rng() * 15))
        else:
            stats[s] = base + math.floor(rng() * 40)
    return stats

def generate_bones(account_uuid: str):
    import math
    seed_str = account_uuid + SEED_SUFFIX
    h = fnv1a(seed_str)
    rng = Mulberry32(h)
    rarity = pick_rarity(rng)
    species = pick(rng, SPECIES)
    eye = pick(rng, EYES)
    hat = "none" if rarity == "common" else pick(rng, HATS)
    shiny = rng() < 0.01
    stats = generate_stats(rng, rarity)
    inspiration_seed = math.floor(rng() * 1_000_000_000)
    return {
        "bones": {
            "rarity": rarity, "species": species, "eye": eye,
            "hat": hat, "shiny": shiny, "stats": stats
        },
        "inspirationSeed": inspiration_seed
    }
```

---

## Appendix B: Key Function Reference

| Minified Name | Purpose |
|---------------|---------|
| `Ab4` | FNV-1a hash |
| `fb4` | mulberry32 PRNG constructor |
| `GTH` | random element selection |
| `zb4` | rarity selection (weighted) |
| `Yb4` | stat generation |
| `Mb4` | bone generation (main) |
| `QS8` | seed-to-bones pipeline (with cache) |
| `lS8` | get account UUID |
| `NI` | merge stored companion + recomputed bones |
| `Ko$` | render species art (eye/hat substitution) |
| `KS7` | compact face template |
| `sh7` | AI hatching call (personality generation) |
| `AD1` | inspiration word selection (LCG) |
| `zD1` | fallback personality (no API) |
| `Ho$` | buddy_react API call |
| `lh7` | reaction trigger logic |
| `qD1` | reason detection (error/test-fail/large-diff) |
| `aM1` | transcript building |
| `ih7` | pet trigger |
| `nh7` | hatch-time reaction trigger |
| `fsq` | companion system prompt template |
| `Asq` | companion intro attachment |
| `qo$` | feature availability check |
| `fD1` | hatching system prompt |
| `_o$` | companion card component |
| `fS7` | hatching animation component |
| `DD1` | stat bar renderer |
| `GD1` | /buddy slash command definition |
| `WD1` | hatching flow (calls sh7, persists result) |
| `eh7` | buddy teaser notification |
| `HS7` | /buddy text highlight detection |

---

## Appendix C: Verification

To verify the bone generation for a given account UUID:

```python
result = generate_bones("your-account-uuid-here")
print(result)
# Should match what /buddy shows in the CLI
```

The stored companion data can be found at:
```bash
cat ~/.claude.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('companion',{}), indent=2))"
```

Compare the recomputed bones with the visual display from `/buddy` to confirm correctness.
