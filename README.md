<h1 align="center">Buy Zone</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=BLEO4hK1Oyg"><img src="https://img.youtube.com/vi/BLEO4hK1Oyg/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin gives full control over buy zones in Counter-Strike 1.6.
Buy zones can be created, removed and toggled on or off during gameplay, with runtime control over team access, radar visibility and activation timing.
Custom setups are saved per map and automatically loaded on every map start.
- Create and remove buy zones during gameplay via an in-game menu
- Configurable per zone: team access, radar visibility, activation chance, activation delay, duration and cooldown
- Team access and radar visibility can each be restricted to Terrorists, CTs, both teams, or disabled
- Independent axis scaling with an Add/Remove mode toggle and factor control for precise box resizing
- Noclip for players while placing buy zones, for easier and more accurate positioning
- Optional toggle to disable default map buy zones in favor of fully custom ones

## 📋 Requirements
- ReGameDLL
- AMX Mod X 1.10+

## 💬 Commands
- `say /bz` - Opens the Buy Zone menu.
- `say_team /bz` - Opens the Buy Zone menu.
- `say /buyzone` - Opens the Buy Zone menu.
- `say_team /buyzone` - Opens the Buy Zone menu.
- `bz_reload` - Reloads the configuration file.
- `buyzone_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# [Main Settings]
# SETTING_DEFAULT_FLAGS           = Default flags (a - Radar, b - Icon, c - Active Delay, d - Active Duration)
# SETTING_DEFAULT_TEAM            = Default team (0 - None, 1 - Terrorists Only, 2 - CT Only, 3 - Both Teams)
# SETTING_DEFAULT_RADAR           = Default radar visibility (0 - Disabled, 1 - Terrorists Only, 2 - CT Only, 3 - Both Teams)
# SETTING_DEFAULT_ACTIVE_CHANCE   = Default probability the zone activates each round (0.0 - 1.0)
# SETTING_DEFAULT_ACTIVE_DELAY    = Default random delay before the zone goes active (min - max)
# SETTING_DEFAULT_ACTIVE_DURATION = Default duration the zone stays active (min - max)
# SETTING_DEFAULT_ACTIVE_COOLDOWN = Default cooldown before the zone can reactivate (min - max)
# SETTING_DEFAULT_ICON            = Default path to the buy zone's icon sprite
# SETTING_DEFAULT_ICON_SCALE      = Default icon scale
# SETTING_DEFAULT_ICON_ALPHA      = Default icon alpha
# Per-zone settings (defined under each [Buy Zone Name] section):
# BUY_FLAGS   = a - Radar, b - Icon, c - Active Delay, d - Active Duration
# BUY_TEAM    = 0 - None, 1 - Terrorists Only, 2 - CT Only, 3 - Both Teams
# BUY_RADAR   = 0 - Disabled, 1 - Terrorists Only, 2 - CT Only, 3 - Both Teams
```

## 🔄 Changelog
```text
* v1.0: Initial release.
* v1.1: Added independent axis scaling, mode toggle (Add/Remove), and factor control for precise box resizing, added noclip for players placing buy zones for easier positioning.
* v1.2: Bug fixes and config improvements.
* v1.3: Added per-Buy Zone configuration.
* v1.4: Added FLAG_ACTIVE_DURATION, improved round-start logic.
```

[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20video-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=BLEO4hK1Oyg)
