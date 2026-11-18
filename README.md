# AggroGlow-Nameplate-Threat
See your threat on every enemy nameplate: stable, slipping, or gone.

AggroGlow: Nameplate Threat adds a glow around each engaged enemy's nameplate that shows your threat on it at a glance. It follows you, or your pet when your pet is the tank. It never changes Blizzard's nameplate or health bar; the glow uses the nameplate's own border art, tinted, so it lines up exactly and fits the game's look.

Features
- Three glows:
  - Green (stable): the tank has aggro, safely.
  - Orange (unstable): the tank has aggro but someone is at or above your warning threshold (default 80%) of pulling it, or the tank is about to pull it.
  - Red (no threat): the enemy is engaged with you or your group but isn't on the tank.
- Each glow can be shown or hidden, flashing or steady, with its own strength and color (by default stable is steady, the other two flash).
- Works on every enemy you or your party are fighting, including ones a party member pulled.
- Whose aggro: Auto (your pet when it's out and you're solo or in a group with no role set, else you), Me, or My pet.
- My role: Auto (your group role; the tank when solo), Tank, or Not the tank. When you're not the tank, the glows show your own threat the other way round: green while it's on someone else, orange when you're close to pulling it, red when it's on you. Each mode has its own glow settings.
- Unstable threshold from 50% to 100% of pulling.
- Optional "!" icon and threat % beside the nameplate, on the side you choose, each at an adjustable distance; the % can also show while aggro is stable (how close the next person is to pulling it).
- Only show in a party or raid (or while your pet tanks).

Settings and commands
- /ag: settings window (whose aggro to show; show, flash, strength and color per glow; flash speed; unstable threshold; display options; previews on your target).
- /ag debug: what threat data the game gives addons right now.
- Esc > Options > AddOns > Aggro Glow.

Requirements
- WoW: Forever (client 16001). No other addons required.
- Enemy nameplates turned on.

Known limits
- When Forever hides threat values in combat, your own threat is read from each enemy's tooltip: have aggro, about to pull, and no aggro all work, with the %. "Someone is about to take it from you" needs the hidden values, so it only shows when the game gives them. With your pet as the tank, your own tooltip threat shows when you're catching up (orange) or have pulled it (red); "pet has it" (green) comes from the hidden values.
- Nameplates in some instances may be off-limits to addons; no glow appears there.

Changelogs
- 3.8.1: "Whose aggro" and "My role" no longer get in each other's way: on Auto your pet is followed when you're solo or in a group with no role set (your spec doesn't override it), and as the group's tank the glows follow you. "Only in a party" and /ag debug use the same rules.
- 3.8.0: Separate glows for when you're the tank and when you're not: as a damage dealer or healer the glows show your own threat the other way round (green while it's on someone else, orange when you're close to pulling it, red when it's on you). My role: Auto (your group role, tank when solo), Tank or Not the tank. Each mode has its own show / flash / strength / colors.
- 3.7.1: Pet tanking: orange when you're catching up on your pet's threat now works in combat too (from your tooltip's threat line), and an enemy on you shows red even while your pet is winning it back.
- 3.7.0: Threat % and glows now work when the game hides threat values in combat: read from the threat line in each enemy's tooltip. The orange glow also warns when you're about to pull an enemy. Choose which side of the nameplate the % sits on, and set how far from the nameplate the % and the "!" sit.
- 3.6.0: Settings window restyled to match XP Planner and Spell Glow (FlareUI's look when installed).
- 3.5.0: Cleaner settings window; choose which glows flash, each with its own strength; threat % can also show while aggro is stable.
- 3.4.1: Logo in the AddOns list.
- 3.4.0: Pet tanking: Whose aggro to show (Auto / Me / My pet).
- 3.3.0: Unstable is based on how close your group is to pulling (threshold, default 80%).
- 3.2.0: Three states (stable, unstable, no threat) on every engaged enemy; Only in a party option.
- 3.1.1: Fixed restricted-region error; glow attaches to the nameplate border directly.
- 3.1.0: Glow uses the nameplate's own border art.
- 3.0.0: Threat list removed; steady green and flashing glows.
- 2.1.0: Settings window (/ag).
- 2.0.0: Rebuilt on the nameplate; Blizzard's health bar untouched.
- 1.0.0: First release.
