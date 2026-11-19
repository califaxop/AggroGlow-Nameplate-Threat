# AggroGlow: Nameplate Threat

**See who has aggro, right on the enemy's nameplate.**

A clean glow around each enemy's nameplate shows your threat at a glance. Tanks see who holds it; damage dealers and healers see how close they are to pulling it. Built for tanks, damage dealers, healers and pet classes alike.

## Highlights
- **Tank:** one glow while you hold aggro, another (flashing) plus a "!" when it's on someone else; optionally your % too.
- **Not the tank:** safe while the tank has it, close when you near the warning %, on you when you pull it. Plus your threat % in a small box left of the nameplate.
- **Every glow is yours to tune:** color, on/off, flash, strength and flash interval.
- **Pet tanking:** follows your Voidwalker or other pet, and warns when you're catching up.
- **Works in combat:** when the game hides threat in a group, it reads your own threat from the enemy's tooltip (on enemies you have threat on).
- **Threat %:** for when you're not the tank, left of the nameplate, clear of debuff icons and Questie's quest icon (up to 100%). At 100% (it's on you) the "!" takes the number's place.
- **Smart role:** uses your group-finder role; with none set, it acts like solo.

## Quick start
1. Turn on enemy nameplates (default key **V**).
2. Type `/ag` and check **My role** and **Whose aggro to show**.
3. Use the **Preview** buttons on your target to tune the look.

## Commands
| Command | Does |
|---|---|
| `/ag` | Open settings |
| `/ag debug` | Show what threat data the game gives right now |

## Good to know
- In a group the game hides threat values, so your % comes from the enemy's tooltip: it shows on enemies you have threat on.
- Tanks see holding / lost only: the game doesn't let addons see a party member closing in.
- With a pet tanking and threat hidden, "pet has it" vs "doesn't" comes from the game's hidden flag.

## Recent changes
- **3.9.0:** Simpler glows: holding / lost for tanks; safe / close / on you otherwise. Flash interval per glow; % for non-tanks, capped at 100%, now in a small XP Planner-style box left of the nameplate; "!" (a tinted quest icon) replaces the % at 100%, and marks lost aggro for tanks.
- **3.8.1:** Role and pet settings no longer interfere; no group role set acts like solo.
- **3.8.0:** Separate glows for tank and not-the-tank, with a My role setting.
- **3.7.1:** Pet tanking: orange when you're catching up, red when it's on you.
- **3.7.0:** Threat read from tooltips in combat; % placement options.
