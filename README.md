# AggroGlow-Nameplate-Threat
See your threat on every enemy nameplate: stable, slipping, or gone.

AggroGlow: Nameplate Threat adds a glow around each engaged enemy's nameplate that shows your threat on it at a glance. It follows you, or your pet when your pet is the tank. It never changes Blizzard's nameplate or health bar; the glow uses the nameplate's own border art, tinted, so it lines up exactly and fits the game's look.

Features
- Three glows:
  - Green (stable): the tank has aggro, safely.
  - Orange (unstable): the tank has aggro, but someone is at or above your threshold (default 80%) of pulling it.
  - Red (no threat): the enemy is engaged with you or your group but isn't on the tank.
- Each glow can be shown or hidden, flashing or steady, with its own strength and color (by default stable is steady, the other two flash).
- Works on every enemy you or your party are fighting, including ones a party member pulled.
- Whose aggro: Auto (your pet when it's out, else you), Me, or My pet.
- Unstable threshold from 50% to 100% of pulling.
- Optional "!" icon and threat % beside the nameplate; the % can also show while aggro is stable (how close the next person is to pulling it).
- Only show in a party or raid (or while your pet tanks).

Settings and commands
- /ag: settings window (whose aggro to show; show, flash, strength and color per glow; flash speed; unstable threshold; display options; previews on your target).
- /ag debug: what threat data the game gives addons right now.
- Esc > Options > AddOns > Aggro Glow.

Requirements
- WoW: Forever (client 16001). No other addons required.
- Enemy nameplates turned on.

Known limits
- When Forever hides threat values, the glow can still tell "tank has it" (green) from "doesn't" (red); unstable needs a client function not yet confirmed on Forever (/ag debug reports it).
- Nameplates in some instances may be off-limits to addons; no glow appears there.

Changelogs
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
