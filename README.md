# AggroGlow: Nameplate Threat

**See who's about to lose aggro, right on the enemy's nameplate.**

A clean glow around each enemy's nameplate shows your threat at a glance: green when it's safe, orange when it's slipping, red when it's gone wrong. Built for tanks, damage dealers, healers and pet classes alike.

## Highlights
- **Three glows:** stable, unstable (flashing), no threat (flashing). Colors, flash and strength are yours to set.
- **Tank or not:** as a tank, green means *you* hold it. As damage or healer, the colors flip: green while it's on someone else, red when you pull it.
- **Pet tanking:** follows your Voidwalker or other pet, and warns when you're catching up.
- **Works in combat:** reads your threat from the enemy's tooltip when the game hides it.
- **Threat %:** optional, on either side of the nameplate, at your chosen distance. Optional "!" warning icon too.
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
- When the game hides threat in combat, "someone is about to take aggro from you" can't be shown; the other glows still work.
- With a pet tanking and threat hidden, "pet has it" vs "doesn't" comes from the game's hidden flag.

## Recent changes
- **3.8.1:** Role and pet settings no longer interfere; no group role set acts like solo.
- **3.8.0:** Separate glows for tank and not-the-tank, with a My role setting.
- **3.7.1:** Pet tanking: orange when you're catching up, red when it's on you.
- **3.7.0:** Threat read from tooltips in combat; % placement options.
