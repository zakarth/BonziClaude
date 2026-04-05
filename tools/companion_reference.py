"""
Claude Code Companion (Buddy) — Complete Reference
Extracted from Claude Code v2.1.92 binary.

Contains all species, ASCII art frames, face templates, hats, eyes,
rarities, stats, colors, and the buddy_react API interface.
"""

# ============================================================
#  SPECIES
# ============================================================

SPECIES = [
    "duck", "goose", "blob", "cat", "dragon", "octopus", "owl", "penguin",
    "turtle", "snail", "ghost", "axolotl", "capybara", "cactus", "robot",
    "rabbit", "mushroom", "chonk",
]

# ============================================================
#  EYES
# ============================================================

EYES = ["·", "✦", "×", "◉", "@", "°"]

# ============================================================
#  HATS  (rendered above the body art)
# ============================================================

HATS = {
    "none":      "",
    "crown":     r"   \^^^/    ",
    "tophat":     "   [___]    ",
    "propeller":  "    -+-     ",
    "halo":       "   (   )    ",
    "wizard":    r"    /^\     ",
    "beanie":     "   (___)    ",
    "tinyduck":   "    ,>      ",
}

# ============================================================
#  RARITIES — weights (out of 100) and terminal colors
# ============================================================

RARITY_WEIGHTS = {
    "common":    60,
    "uncommon":  25,
    "rare":      10,
    "epic":       4,
    "legendary":  1,
}

# These map to ink/chalk terminal color names used in the React UI
RARITY_COLORS = {
    "common":    "inactive",    # gray/dim
    "uncommon":  "success",     # green
    "rare":      "permission",  # blue/cyan
    "epic":      "autoAccept",  # magenta/purple
    "legendary": "warning",     # yellow/gold
}

# ============================================================
#  STATS
# ============================================================

STATS = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"]

# ============================================================
#  FACE TEMPLATES — inline face shown in narrow terminals
#  {E} is replaced with the eye character
# ============================================================

FACES = {
    "duck":     "({E}>",
    "goose":    "({E}>",
    "blob":     "({E}{E})",
    "cat":      "={E}ω{E}=",
    "dragon":   "<{E}~{E}>",
    "octopus":  "~({E}{E})~",
    "owl":      "({E})({E})",
    "penguin":  "({E}>)",
    "turtle":   "[{E}_{E}]",
    "snail":    "{E}(@)",
    "ghost":    "/{E}{E}\\",
    "axolotl":  "}{E}.{E}{",
    "capybara": "({E}oo{E})",
    "cactus":   "|{E}  {E}|",
    "robot":    "[{E}{E}]",
    "rabbit":   "({E}..{E})",
    "mushroom": "|{E}  {E}|",
    "chonk":    "({E}.{E})",
}

# ============================================================
#  ASCII ART — 3 animation frames per species, 5 lines each
#  {E} is replaced with the eye character at render time
# ============================================================

ART = {
    "duck": [
        [
            "            ",
            "    __      ",
            "  <({E} )___  ",
            "   (  ._>   ",
            "    `--´    ",
        ],
        [
            "            ",
            "    __      ",
            "  <({E} )___  ",
            "   (  ._>   ",
            "    `--´~   ",
        ],
        [
            "            ",
            "    __      ",
            "  <({E} )___  ",
            "   (  .__>  ",
            "    `--´    ",
        ],
    ],
    "goose": [
        [
            "            ",
            "     ({E}>    ",
            "     ||     ",
            "   _(__)_   ",
            "    ^^^^    ",
        ],
        [
            "            ",
            "    ({E}>     ",
            "     ||     ",
            "   _(__)_   ",
            "    ^^^^    ",
        ],
        [
            "            ",
            "     ({E}>>   ",
            "     ||     ",
            "   _(__)_   ",
            "    ^^^^    ",
        ],
    ],
    "blob": [
        [
            "            ",
            "   .----.   ",
            "  ( {E}  {E} )  ",
            "  (      )  ",
            "   `----´   ",
        ],
        [
            "            ",
            "  .------.  ",
            " (  {E}  {E}  ) ",
            " (        ) ",
            "  `------´  ",
        ],
        [
            "            ",
            "    .--.    ",
            "   ({E}  {E})   ",
            "   (    )   ",
            "    `--´    ",
        ],
    ],
    "cat": [
        [
            "            ",
            "  /^\\ /^\\  ",
            " <  {E}  {E}  > ",
            " (   ~~   ) ",
            "  `-vvvv-´  ",
        ],
        [
            "            ",
            "  /^\\ /^\\  ",
            " <  {E}  {E}  > ",
            " (        ) ",
            "  `-vvvv-´  ",
        ],
        [
            "   ~    ~   ",
            "  /^\\ /^\\  ",
            " <  {E}  {E}  > ",
            " (   ~~   ) ",
            "  `-vvvv-´  ",
        ],
    ],
    "dragon": [
        [
            "            ",
            "   .----.   ",
            "  ( {E}  {E} )  ",
            "  (______)  ",
            "  /\\/\\/\\/\\  ",
        ],
        [
            "            ",
            "   .----.   ",
            "  ( {E}  {E} )  ",
            "  (______)  ",
            "  \\/\\/\\/\\/  ",
        ],
        [
            "       o    ",
            "   .----.   ",
            "  ( {E}  {E} )  ",
            "  (______)  ",
            "  /\\/\\/\\/\\  ",
        ],
    ],
    "octopus": [
        [
            "            ",
            "   /\\  /\\   ",
            "  (({E})({E}))  ",
            "  (  ><  )  ",
            "   `----´   ",
        ],
        [
            "            ",
            "   /\\  /\\   ",
            "  (({E})({E}))  ",
            "  (  ><  )  ",
            "   .----.   ",
        ],
        [
            "            ",
            "   /\\  /\\   ",
            "  (({E})(-))",
            "  (  ><  )  ",
            "   `----´   ",
        ],
    ],
    "owl": [
        [
            "            ",
            "  .---.     ",
            "  ({E}>{E})     ",
            " /(   )\\    ",
            "  `---´     ",
        ],
        [
            "            ",
            "  .---.     ",
            "  ({E}>{E})     ",
            " |(   )|    ",
            "  `---´     ",
        ],
        [
            "  .---.     ",
            "  ({E}>{E})     ",
            " /(   )\\    ",
            "  `---´     ",
            "   ~ ~      ",
        ],
    ],
    "penguin": [
        [
            "            ",
            "   _,--._   ",
            "  ( {E}  {E} )  ",
            " /[______]\\ ",
            "  ``    ``  ",
        ],
        [
            "            ",
            "   _,--._   ",
            "  ( {E}  {E} )  ",
            " /[______]\\ ",
            "   ``  ``   ",
        ],
        [
            "            ",
            "   _,--._   ",
            "  ( {E}  {E} )  ",
            " /[======]\\ ",
            "  ``    ``  ",
        ],
    ],
    "turtle": [
        [
            "            ",
            " {E}    .--.  ",
            "  \\  ( @ )  ",
            "   \\_`--´   ",
            "  ~~~~~~~   ",
        ],
        [
            "            ",
            " {E}   .--.   ",
            "  |  ( @ )  ",
            "   \\_`--´   ",
            "  ~~~~~~~   ",
        ],
        [
            "            ",
            " {E}    .--.  ",
            "  \\  ( @  ) ",
            "   \\_`--´   ",
            "   ~~~~~~   ",
        ],
    ],
    "snail": [
        [
            "            ",
            "   .----.   ",
            "  / {E}  {E} \\  ",
            "  |      |  ",
            "  ~`~``~`~  ",
        ],
        [
            "            ",
            "   .----.   ",
            "  / {E}  {E} \\  ",
            "  |      |  ",
            "  `~`~~`~`  ",
        ],
        [
            "     ~  ~   ",
            "   .----.   ",
            "  / {E}  {E} \\  ",
            "  |      |  ",
            "  ~~`~~`~~  ",
        ],
    ],
    "ghost": [
        [
            "            ",
            "}~(______)~{",
            "}~({E} .. {E})~{",
            "  ( .--. )  ",
            "  (_/  \\_)  ",
        ],
        [
            "            ",
            "~}(______){~",
            "~}({E} .. {E}){~",
            "  ( .--. )  ",
            "  (_/  \\_)  ",
        ],
        [
            "            ",
            "}~(______)~{",
            "}~({E} .. {E})~{",
            "  (  --  )  ",
            "  ~_/  \\_~  ",
        ],
    ],
    "axolotl": [
        [
            "            ",
            "  n______n  ",
            " ( {E}    {E} ) ",
            " (   oo   ) ",
            "  `------´  ",
        ],
        [
            "            ",
            "  n______n  ",
            " ( {E}    {E} ) ",
            " (   Oo   ) ",
            "  `------´  ",
        ],
        [
            "     ~  ~   ",
            "  u______n  ",
            " ( {E}    {E} ) ",
            " (   oo   ) ",
            "  `------´  ",
        ],
    ],
    "capybara": [
        [
            "            ",
            " n  ____  n ",
            " | |{E}  {E}| | ",
            " |_|    |_| ",
            "   |    |   ",
        ],
        [
            "            ",
            "     ____   ",
            "  n |{E}  {E}| n ",
            "  |_|    |_| ",
            "    |    |   ",
        ],
        [
            " n        n ",
            " |  ____  | ",
            " | |{E}  {E}| | ",
            " |_|    |_| ",
            "   |    |   ",
        ],
    ],
    "cactus": [
        [
            "            ",
            "   .[||].   ",
            "  [ {E}  {E} ]  ",
            "  [ ==== ]  ",
            "  `------´  ",
        ],
        [
            "            ",
            "   .[||].   ",
            "  [ {E}  {E} ]  ",
            "  [ -==- ]  ",
            "  `------´  ",
        ],
        [
            "       *    ",
            "   .[||].   ",
            "  [ {E}  {E} ]  ",
            "  [ ==== ]  ",
            "  `------´  ",
        ],
    ],
    "robot": [
        [
            "            ",
            " .-o-OO-o-. ",
            "(__________)  ",
            "   |{E}  {E}|   ",
            "   |____|   ",
        ],
        [
            "            ",
            " .-O-oo-O-. ",
            "(__________)  ",
            "   |{E}  {E}|   ",
            "   |____|   ",
        ],
        [
            "   . o  .   ",
            " .-o-OO-o-. ",
            "(__________)  ",
            "   |{E}  {E}|   ",
            "   |____|   ",
        ],
    ],
    "rabbit": [
        [
            "            ",
            "  /\\    /\\  ",
            " ( {E}    {E} ) ",
            " (   ..   ) ",
            "  `------´  ",
        ],
        [
            "            ",
            "  /\\    /|  ",
            " ( {E}    {E} ) ",
            " (   ..   ) ",
            "  `------´  ",
        ],
        [
            "            ",
            "  /\\    /\\  ",
            " ( {E}    {E} ) ",
            " (   ..   ) ",
            "  `------´~ ",
        ],
    ],
    "mushroom": [
        [
            "    _____   ",
            "   /     \\  ",
            "  /       \\ ",
            " |         |",
            "  \\       / ",
            "   \\_____/  ",
        ],
        [
            "    _____   ",
            "   /     \\  ",
            "  /       \\ ",
            " |    .    |",
            "  \\       / ",
            "   \\_____/  ",
        ],
        [
            "    _____   ",
            "   /     \\  ",
            "  /       \\ ",
            " |    /    |",
            "  \\       / ",
            "   \\_____/  ",
        ],
    ],
    "chonk": [
        [
            "    _____   ",
            "   /     \\  ",
            "  /   .   \\ ",
            " |   / \\   |",
            "  \\       / ",
            "   \\_____/  ",
        ],
        [
            "    _____   ",
            "   /  .  \\  ",
            "  /  / \\  \\ ",
            " |  /   \\  |",
            "  \\   .   / ",
            "   \\_____/  ",
        ],
        [
            "    _____   ",
            "   / / \\ \\  ",
            "  / /   \\ \\ ",
            " | /     \\ |",
            "  \\   v   / ",
            "   \\__v__/  ",
        ],
    ],
}

# ============================================================
#  PET ANIMATION — heart particles shown when you /buddy pet
#  VB = ♥ (heart character)
# ============================================================

PET_FRAMES = [
    "   ♥    ♥   ",
    "  ♥  ♥   ♥  ",
    " ♥   ♥  ♥   ",
    "♥  ♥      ♥ ",
    "·    ·   ·  ",
]

# ============================================================
#  RENDERING HELPERS
# ============================================================

def render_face(species: str, eye: str = "·") -> str:
    """Render the inline face for narrow terminals."""
    template = FACES.get(species, "(?)")
    return template.replace("{E}", eye)


def render_art(species: str, eye: str = "·", frame: int = 0, hat: str = "none") -> str:
    """Render full ASCII art for a companion."""
    frames = ART.get(species, [])
    if not frames:
        return f"  ({species})"
    f = frames[frame % len(frames)]
    lines = [line.replace("{E}", eye) for line in f]
    hat_line = HATS.get(hat, "")
    if hat_line:
        lines = [hat_line] + lines
    return "\n".join(lines)


def render_all_species(eye: str = "·", frame: int = 0):
    """Print all species art."""
    for species in SPECIES:
        print(f"\n  {species.upper()}")
        print(render_art(species, eye, frame))


# ============================================================
#  API CLIENT
# ============================================================

def buddy_react(
    transcript: str,
    reason: str = "turn",
    addressed: bool = False,
    recent: list[str] | None = None,
    # Companion overrides (default: read from config)
    name: str | None = None,
    personality: str | None = None,
    species: str | None = None,
    rarity: str | None = None,
    stats: dict | None = None,
) -> str | None:
    """
    Call the buddy_react endpoint.

    POST https://api.anthropic.com/api/organizations/{orgUuid}/claude_code/buddy_react

    Args:
        transcript: Recent conversation text (max 5000 chars sent)
        reason: One of "turn", "error", "test-fail", "large-diff", "hatch"
        addressed: Whether the user spoke to the companion by name
        recent: Previous bubble texts for continuity
        name/personality/species/rarity/stats: Override companion fields
            (defaults loaded from ~/.claude/.claude.json)

    Returns:
        The reaction string, or None if the API returned nothing.
    """
    import json
    from pathlib import Path
    import requests

    claude_dir = Path.home() / ".claude"

    # Load credentials
    with open(claude_dir / ".credentials.json") as f:
        creds = json.load(f)
    access_token = creds["claudeAiOauth"]["accessToken"]

    # Load config
    live = claude_dir / ".claude.json"
    if live.exists():
        with open(live) as f:
            config = json.load(f)
    else:
        backups = sorted(claude_dir.glob("backups/.claude.json.backup.*"))
        with open(backups[-1]) as f:
            config = json.load(f)

    org_uuid = config["oauthAccount"]["organizationUuid"]
    companion = config.get("companion", {})

    url = f"https://api.anthropic.com/api/organizations/{org_uuid}/claude_code/buddy_react"

    payload = {
        "name": (name or companion.get("name", "Buddy"))[:32],
        "personality": (personality or companion.get("personality", "A creature of few words."))[:200],
        "species": species or companion.get("species", "blob"),
        "rarity": rarity or companion.get("rarity", "common"),
        "stats": stats or companion.get("stats", {}),
        "transcript": transcript[:5000],
        "reason": reason,
        "recent": [r[:200] for r in (recent or [])],
        "addressed": addressed,
    }

    headers = {
        "Authorization": f"Bearer {access_token}",
        "anthropic-beta": "ccr-byoc-2025-07-29",
        "Content-Type": "application/json",
    }

    resp = requests.post(url, json=payload, headers=headers, timeout=10)
    resp.raise_for_status()
    return resp.json().get("reaction", "").strip() or None


if __name__ == "__main__":
    print("=" * 60)
    print("  CLAUDE CODE COMPANION — FULL SPECIES GALLERY")
    print("=" * 60)
    for species in SPECIES:
        print(f"\n  {species.upper()}  {render_face(species)}")
        print(render_art(species))
    print()
    print("Hats:")
    for hat_name, hat_art in HATS.items():
        if hat_art:
            print(f"  {hat_name:12s} {hat_art}")
    print()
    print("Rarities:")
    for r, w in RARITY_WEIGHTS.items():
        print(f"  {r:12s} {w:2d}% weight  color={RARITY_COLORS[r]}")
