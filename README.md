# BonziClaude

**A cross-platform desktop companion powered by Claude Code's hidden buddy_react API endpoint.**

BonziClaude is a reverse-engineered reimplementation of Claude Code's `/buddy` feature as a standalone desktop application. It uses an undocumented free inference endpoint on Anthropic's API to power an ASCII art companion that lives on your desktop, reacts to your activity, and occasionally offers sarcastic commentary on your life choices.

Think [BonziBuddy](https://en.wikipedia.org/wiki/BonziBuddy) (1999), but instead of adware, it's powered by Claude. And instead of a purple gorilla, you get one of 18 ASCII creatures with deterministic gacha mechanics.

![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20Windows%20x64%20%7C%20Windows%20x86-green)
![Language](https://img.shields.io/badge/built%20with-Free%20Pascal%20%2F%20Lazarus-blue)
![License](https://img.shields.io/badge/license-MIT-orange)

---

## Table of Contents

- [How It Started](#how-it-started)
- [The Discovery](#the-discovery)
- [The buddy_react API](#the-buddy_react-api)
- [The Companion System](#the-companion-system)
- [BonziClaude Features](#bonziclaude-features)
- [Building](#building)
- [Usage](#usage)
- [Configuration](#configuration)
- [Privacy](#privacy)
- [Complete Forensic Reference](#complete-forensic-reference)

---

## How It Started

On April 1st, 2026, Anthropic added a hidden feature to Claude Code v2.1.88: the `/buddy` command. It hatches a small ASCII creature that watches you code and occasionally makes snarky comments in a speech bubble. The changelog entry was one line:

> `/buddy` is here for April 1st -- hatch a small creature that watches you code

Buddy includes the following:
- 18 species of ASCII creatures
- Deterministic gacha mechanics (rarity, stats, shiny variants)
- AI-generated personalities
- A dedicated server-side API endpoint for generating reactions
- Blink animations, pet interactions, and hat accessories

This project started as a reverse engineering exercise to understand how the system works, and evolved into a full standalone desktop application.

## BLUF
BonziClaude utilizes the buddy API endpoints to decouple the buddy from Claude Code and instead let you run it right in your desktop. You can change every feature of it, but notably, you can also change the way it responds and performs activities. Because the endpoint (for now) is unmetered, you get free Sonnet 3.5 access for a personal character and you can customize its behavior. This only includes about 100 output tokens, but that's enough for some small tasks.  

To maintain access, BonziClaude will attempt to use your Claude Code login if active, or allow you to give it its own oAuth token by logging in yourself. 

## Desktop Behavior
There have been some notable changes to the desktop behavior vs Claude Code 
- By default won't send all your sensitive data to a strange endpoint 
- Since you likely won't be coding while fiddling around on your personal computer, you can just chat with it 
- You can drag and drop files onto your buddy and let him nom on them
- In "Personalized" mode it will comment on your activity -- this mode is not enabled by default since it will send data to Anthropic servers.
- You can customize, re-hatch, or change any aspect of how the buddy interacts with Anthropic
- Maintains a small chat history 

### The Endpoint

The key discovery was the `buddy_react` API endpoint:

```
POST https://api.anthropic.com/api/organizations/{orgUuid}/claude_code/buddy_react
```

This endpoint:
- **Runs Claude 3.5 Sonnet** -- see [Model Identification](#model-identification) below
- Accepts a companion's personality as a system prompt
- Takes up to 5KB of transcript context
- Returns a ~350 character reaction
- Is authenticated via OAuth bearer token (same as Claude Code sessions)
- Has **no visible token metering** -- reactions don't count against usage quotas
- Is separate from the `/v1/messages` API

### Server-Enforced Limits

Through systematic testing, the following was determined:

| Field | Max Size | Server Response on Exceed |
|---|---|---|
| `name` | 32 chars | HTTP 400 |
| `personality` | 200 chars | HTTP 400 |
| `transcript` | 5000 chars | HTTP 400 |
| `recent` entries | 3 max | HTTP 400 |
| `recent` entry length | 200 chars each | HTTP 400 |
| Output | ~350 chars | Truncated |

---

## The buddy_react API

### Request Format

```json
POST /api/organizations/{orgUuid}/claude_code/buddy_react
Authorization: Bearer {oauth_access_token}
anthropic-beta: ccr-byoc-2025-07-29
Content-Type: application/json

{
    "name": "Trellis",
    "personality": "A meditative rabbit who spots bugs with preternatural clarity...",
    "species": "rabbit",
    "rarity": "common",
    "stats": {"DEBUGGING": 50, "PATIENCE": 50, "CHAOS": 50, "WISDOM": 50, "SNARK": 50},
    "transcript": "User's recent activity or chat message",
    "reason": "turn",
    "recent": ["previous reaction 1", "previous reaction 2"],
    "addressed": true
}
```

### Response

```json
{
    "reaction": "*ears twitch*\n\nOff-by-one error hiding in plain sight, naturally."
}
```

### Trigger Reasons

| Reason | When |
|---|---|
| `turn` | After each assistant response / periodic |
| `error` | When an error is detected in output |
| `test-fail` | When test failures are detected |
| `large-diff` | When a large code diff is produced |
| `hatch` | First appearance / hatching |
| `pet` | When the user pets the companion |

### Model Identification

Through systematic reasoning tests, it was determined that the buddy_react endpoint runs **Claude 3.5 Sonnet** -- significantly more capable than the Haiku model we initially assumed. The smoking gun was through a prompt it was able to self-identify as Claude 3.5 Sonnet, practically confirming it. Variations of prompts can also elicit some non-buddy like responses-- experiment at your own risk!

This means the buddy_react endpoint provides free access to a Sonnet-class model with a 200-char system prompt and ~350-char output per call. The model is the same one that powers Claude's mid-tier API offering.

### Key Insight: The Personality IS the System Prompt

The `personality` field (200 chars max) is sent to the server as the system prompt for reaction generation. You can put anything in it:

```python
buddy_react(personality="You are a security auditor. Identify vulnerabilities.", ...)
# Returns: "SQL injection nightmare. User input flows straight into the query."

buddy_react(personality="You write git commit messages. Output ONLY the commit message.", ...)
# Returns: "Fix JWT algorithm and add token expiry check"
```

This makes it a general-purpose ~350-char inference endpoint with a custom system prompt.

---

## The Companion System

### Seed-Based Determinism

Every companion's "bones" (species, eye, hat, rarity, stats) are deterministically generated from a seed:

```
accountUuid + "friend-2026-401"
        |
        v
    FNV-1a hash (32-bit)
        |
        v
    mulberry32 PRNG
        |
        v
    Bones: { rarity, species, eye, hat, shiny, stats }
```

The companion object stored in `.claude.json` only contains `{name, personality, hatchedAt}`. Everything else is recomputed from the seed every time. Stats do NOT change over time within the same Claude Code version.

### FNV-1a Hash

```javascript
function fnv1a(s) {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return h >>> 0;
}
```

### mulberry32 PRNG

```javascript
function mulberry32(seed) {
    let s = seed >>> 0;
    return function() {
        s |= 0;
        s = s + 1831565813 | 0;
        let q = Math.imul(s ^ s >>> 15, 1 | s);
        q = q + Math.imul(q ^ q >>> 7, 61 | q) ^ q;
        return ((q ^ q >>> 14) >>> 0) / 4294967296;
    };
}
```

### Species (18)

| # | Species | Distinctive Art |
|---|---|---|
| 1 | Duck | `<({E} )___` |
| 2 | Goose | `({E}>` with `_(__)_` |
| 3 | Blob | `.----.` round body |
| 4 | Cat | `/\_/\` ears, `omega` mouth, `(")_(")` feet |
| 5 | Dragon | `/^\  /^\` horns, `` `-vvvv-' `` scales |
| 6 | Octopus | `.----.` head, `/\/\/\/\` tentacles |
| 7 | Owl | `(({E})({E}))` big eyes, `><` beak |
| 8 | Penguin | `.---.` head, `/(   )\` body |
| 9 | Turtle | `_,--._` shell, `/[______]\` body |
| 10 | Snail | `{E}    .--.` antenna, `( @ )` shell |
| 11 | Ghost | `.----.` head, `~\`~\`\`~\`~` trail |
| 12 | Axolotl | `}~(______)~{` gills |
| 13 | Capybara | `n______n` ears, `(   oo   )` nose |
| 14 | Cactus | `n  ____  n` arms in pot |
| 15 | Robot | `.[||].` antenna, `[ ==== ]` body |
| 16 | Rabbit | `(\__/)` ears, `=(  ..  )=` whiskers |
| 17 | Mushroom | `.-o-OO-o-.` cap, `(__________)` stem |
| 18 | Chonk | `/\    /\` ears, `(   ..   )` round body |

### Eyes (6)

`*` `+` `x` `@` `o` (Unicode: middle dot, four-pointed star, multiplication sign, bullseye, at sign, degree)

### Hats (8)

| Hat | Art | Availability |
|---|---|---|
| none | (blank) | Common only |
| crown | `\^^^/` | Uncommon+ |
| tophat | `[___]` | Uncommon+ |
| propeller | `-+-` | Uncommon+ |
| halo | `(   )` | Uncommon+ |
| wizard | `/^\` | Uncommon+ |
| beanie | `(___)` | Uncommon+ |
| tinyduck | `,>` | Uncommon+ |

### Rarity

| Rarity | Weight | Stars | Color | Stat Base | Hat? |
|---|---|---|---|---|---|
| Common | 60% | * | Grey #737373 | 5 | Never |
| Uncommon | 25% | ** | Green #16a34a | 15 | Random |
| Rare | 10% | *** | Blue #2563eb | 25 | Random |
| Epic | 4% | **** | Purple #8b5cf6 | 35 | Random |
| Legendary | 1% | ***** | Gold #eab308 | 50 | Random |

### Stats Generation (Yb4 algorithm)

Each companion has 5 stats: DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK.

```
Base value from rarity (5/15/25/35/50)
Pick random PRIMARY stat   -> min(100, base + 50 + rand(0-29))   [HIGH]
Pick random SECONDARY stat -> max(1, base - 10 + rand(0-14))     [LOW]
All others                 -> base + rand(0-39)                   [MODERATE]
```

Stats influence the AI's reaction tone (high SNARK = more sarcastic, high PATIENCE = more forgiving).

### Hatching (Personality Generation)

When a companion is first created, Claude Code calls the API with this system prompt:

> You generate coding companions -- small creatures that live in a developer's terminal and occasionally comment on their work.
>
> Given a rarity, species, stats, and a handful of inspiration words, invent:
> - A name: ONE word, max 12 characters. Memorable, slightly absurd.
> - A one-sentence personality (specific, funny, a quirk that affects how they'd comment on code)
>
> Higher rarity = weirder, more specific, more memorable. A legendary should be genuinely strange.

The user message includes the species, rarity, stats, and 4 random words from a pool of 146 inspiration words (thunder, biscuit, void, accordion, moss, velvet, rust, pickle, crumb, whisper...).

### Animation

The animation sequence cycles through 15 ticks:

```
[0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0]
```

- `0, 1, 2` = normal art frames (idle, alternate, special)
- `-1` = blink (frame 0 with eyes replaced by `-`)

Each tick is 500ms in Claude Code, 650ms in BonziClaude.

### OAuth Authentication

```
CLIENT_ID:     9d1c250a-e61b-44d9-88ed-5944d1962f5e
AUTHORIZE_URL: https://platform.claude.com/oauth/authorize
TOKEN_URL:     https://platform.claude.com/v1/oauth/token
PKCE:          S256 with base64url(32 random bytes) as code_verifier
SCOPES:        user:profile user:inference user:sessions:claude_code
               user:mcp_servers user:file_upload
```

---

## BonziClaude Features

### Core
- Floating desktop companion with ASCII art and animation
- Speech bubble with reactions from the buddy_react API
- Text input for direct conversation
- Pet button with heart animation
- File drag-and-drop (reads last 5KB, buddy reacts to contents)
- Right-click context menu

### Companion Management
- **Import from Claude Code** -- reads `~/.claude/.claude.json` for existing companion
- **Hatch New Buddy** -- full gacha: rolls rarity, species, eye, hat, stats, generates name + personality via API
- **Export to Claude Code** -- writes companion back to Claude Code's config
- **Full customization** -- species carousel, eye picker, hat picker, rarity selector, stat sliders, editable personality (system prompt)

### Privacy Modes (3-level slider)
- **Chat Only** -- no automatic data sent; buddy only speaks when you type
- **Standard** -- sends time of day, day of week, session duration (no PII)
- **Personalized** -- additionally sends username and process names (opt-in)

### Platform Support
Built with Lazarus/Free Pascal from a single unified codebase:

| Platform | Widgetset | Binary |
|---|---|---|
| Linux x86_64* | GTK2 | `BonziClaude` (28MB) |
| Windows x64 | Win32 | `BonziClaude.exe` (26MB) |
| Windows x86 | Win32 | `BonziClaude.exe` (21MB) |

The Linux one will work in WSL with graphics enabled

### UI
- Black terminal aesthetic with rarity-colored borders/text
- Blink animation matching Claude Code's 15-tick sequence
- System tray icon with show/hide toggle
- Always-on-top mode (true BonziBuddy experience)
- Configurable speech bubble position (above/left/right)
- Chat history viewer
- DPI-aware with ClearType on Windows

---

## Building

### Requirements
- [Free Pascal Compiler](https://www.freepascal.org/) 3.2.2+
- [Lazarus IDE](https://www.lazarus-ide.org/) 3.0+ (for `lazbuild` CLI)
- OpenSSL 1.1 or 3.x (runtime dependency)

### Linux

```bash
sudo apt install fpc lazarus
cd BonziClaude
lazbuild BonziClaude.lpi
./BonziClaude
```

### Windows x64

```cmd
C:\lazarus\lazbuild.exe --ws=win32 BonziClaude.lpi
```

Requires `libssl-3-x64.dll` and `libcrypto-3-x64.dll` alongside the executable (available from Git for Windows: `C:\Program Files\Git\mingw64\bin\`).

### Windows x86

```cmd
C:\lazarus32\lazbuild.exe --ws=win32 BonziClaude.lpi
```

---

## Usage

### First Run

1. Launch BonziClaude
2. If you have Claude Code installed, it auto-imports your credentials and companion
3. If not, right-click > Configure > Login to Claude (opens browser for OAuth)
4. Your companion appears and greets you

### Chat Commands

Type in the input box at the bottom:

| Command | Action |
|---|---|
| (any text) | Send to buddy for reaction |
| `exit` / `quit` | Close the app |
| `hide` | Minimize to system tray |

### Right-Click Menu

- **Configure** -- open companion customization
- **Read File** -- pick a file for the buddy to react to
- **History** -- view all past reactions
- **Speech Bubble** -- position (Above/Left/Right)
- **Always on Top** -- toggle
- **Minimize** -- hide to system tray
- **Quit** -- exit

---

## Configuration

### Config File

Stored at:
- **Linux**: `~/.config/BonziClaude/buddy_config.json`
- **Windows**: `%APPDATA%\BonziClaude\buddy_config.json`

### Credential Sources (in priority order)

1. BonziClaude's own stored credentials
2. Claude Code's `~/.claude/.credentials.json`
3. Manual OAuth login via the config dialog

Tokens are refreshed automatically. On 401 errors, BonziClaude re-reads from Claude Code's live credentials (which rotate in the background).

---

## Privacy

BonziClaude communicates with Anthropic's API. Here's exactly what is sent in each mode:

### Data Sent Per API Call

Every `buddy_react` call sends this payload (maximum sizes):

| Field | Max Size | Description |
|---|---|---|
| `name` | 32 chars | Companion name |
| `personality` | 200 chars | System prompt (server rejects 201+) |
| `species` | 8 chars | Species identifier |
| `rarity` | 9 chars | Rarity tier |
| `stats` | ~80 chars | JSON: {DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK} |
| `transcript` | 5,000 chars | **Main context -- varies by privacy mode** |
| `reason` | 10 chars | Trigger type (turn, error, hatch, pet) |
| `recent` | 600 chars | Last 3 bubble reactions (200 chars each) |
| `addressed` | 4 chars | Boolean: was companion addressed by name |

**Maximum total payload: ~6KB per call.** Typical call: ~340 bytes.

The personality limit is exactly **200 Unicode characters** (not bytes, not tokens). A personality with 200 emoji characters (800 bytes UTF-8) passes; 201 ASCII characters fails.

### Chat Only (no automatic sending)
Only when you explicitly type a message or drop a file:
- Companion name, personality (system prompt), species, rarity, stats
- Your message text or file contents (last 5KB)
- Last 3 bubble reactions (for conversational continuity)

### Standard (default)
Additionally, every 10 minutes (transcript field contains):
- Current time of day (morning/afternoon/evening)
- Day of week
- How long the session has been running
- ~100 chars of context per ambient call

**No personal data, no usernames, no file contents, no process information.**

### Personalized (opt-in)
Additionally (appended to transcript):
- Your system username
- Running process names and memory usage
- ~500-1000 chars of additional context per ambient call
- Time of day 

This is similar to the telemetry Claude Code itself sends during normal operation

### What is NOT sent (in any mode)
- File contents (unless you explicitly drop a file on the companion)
- Window titles or URLs
- Clipboard contents
- Keystrokes
- Screenshots

---

## Complete Forensic Reference

The full reverse-engineering documentation is available in [BUDDY_SYSTEM_FORENSICS.md](BUDDY_SYSTEM_FORENSICS.md) (1,586 lines). It contains:

1. Complete seed-to-bones generation pipeline with code
2. All 18 species ASCII art (3 animation frames each, verified against binary)
3. Hat art for all 8 accessories
4. Face templates for compact display
5. Stats generation algorithm with exact ranges per rarity
6. Hatching system prompt and inspiration word pool (146 words)
7. Name generation fallback pool
8. buddy_react API request/response format
9. Reaction trigger logic (error detection, test failure regex)
10. Animation sequence and timing
11. Egg hatching animation (11 frames)
12. Pet heart particle animation
13. OAuth flow (PKCE, endpoints, scopes)
14. Companion storage format
15. Feature gating mechanism

This document is thorough enough to fully reimplement the Claude Code buddy system from scratch.

---

## Acknowledgments

- **Anthropic** for building Claude Code and the delightful buddy system
- **The BonziBuddy legacy** (1999-2004) for inspiring a generation of desktop companions (and teaching us about adware)
- **Lazarus/Free Pascal** for making true cross-platform native development possible from a single codebase

---

## Disclaimer

BonziClaude is an independent project created through reverse engineering of publicly available binaries. It is not affiliated with, endorsed by, or supported by Anthropic. The buddy_react API endpoint is undocumented and may change or be removed at any time. Use at your own risk.

Unlike its namesake, BonziClaude contains no adware, spyware, or malware. It's just a rabbit. On your desktop. Judging your code.

---

## License

MIT
