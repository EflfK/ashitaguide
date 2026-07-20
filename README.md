# ashitaguide

Experimental Ashita v4 guide helper for manual, configuration-driven quest
walkthroughs.

The addon is display-only. It does not move the player, target NPCs, choose
dialog options, send slash commands, inject packets, click menus, or automate
quest progress. It renders local ImGui guide panels and advances steps when you
use the manual controls or satisfy an explicitly configured display condition.

## Current Features

- persistent guide definitions under `config/addons/ashitaguide/`
- automatically persisted UI settings and window geometry
- separate guide runner and guide configuration windows
- free-form categories with an in-game category filter
- guide name/key/category search
- multiple active guides at once
- tabs for switching between active guides
- browser-style close controls on active guide tabs
- manual `<` and `>` step controls
- single-step guides omit step numbering, the step list, and advancement controls
- pure-Lua navigation map showing only the player and step destination
- world-space arrow above the current step NPC when rendered
- optional NPC-target auto-advance for find steps
- built-in Pages of Valor tracker
- dedicated Pages of Valor window that appears from chat evidence
- built-in brown treasure casket code helper
- dedicated Casket Helper window that appears from live casket chat hints
- separate Guides, Valor, and Casket tabs in Guide Config
- configurable 0-100% background opacity shared by every addon window
- independent frame visibility settings for the Guides, Valor, and Casket windows
- AshitaChat-style transparent layout and compact dark tabs when the guide frame is hidden
- configurable all-steps list in the normal guide window
- balanced navigation layout with configurable map size
- Pages of Valor progress seeding from the current character chat log
- live Pages of Valor updates from incoming chat text and appended log lines

## Casket Helper

The built-in Casket Helper watches live incoming chat for brown treasure casket
lock hints. It opens its own movable window while a casket is active, displays
the full parsed hint list, and renders a 10-99 grid:

- green: next best guess
- yellow: still possible
- dim: eliminated

The helper is display-only. It does not enter numbers, send commands, inject
packets, click menus, or automate casket interaction. Historical chat-log
seeding is ignored for caskets so stale casket hints do not reopen the window
on login. The Casket tab in Guide Config controls whether the helper is enabled,
whether the window frame is hidden, and how long an inactive casket session is
kept before new hints start a fresh session.

## Pages of Valor

The built-in `pages_of_valor` helper is not listed in Guide Config. It watches
for accepted-regime and progress messages like:

```text
You defeated a training regime target. (Progress: 1/6)
```

The addon captures the target list and training area printed before `New
training regime registered!`. That one runtime regime is displayed directly;
there is no saved page catalog or manual page selector. CatsEyeXI designated
target progress updates each captured target row independently.
The dedicated window stays compact: it shows only the zone and remaining kill
counts. Its enabled state, zone display, progress totals, and visibility are
controlled from the Valor tab in Guide Config.
The Guides tab can hide the normal guide window frame, and the Valor tab can
hide the dedicated Valor window frame independently. Frameless windows remove
their background and border; the normal guide also switches to compact dark
tabs so its presentation matches AshitaChat's frameless mode.
The Guides tab also controls whether the all-steps section is shown at the
bottom of the normal guide window. Map size is configurable from 120 to 260
pixels and defaults to 160 pixels.

An accepted training regime or `Progress x/y` line opens the Pages of Valor window
automatically. Completion or cancellation closes it. You can close the window
manually; its background tracker remains active and will reopen it when another
progress line arrives.

## Persistent Configuration

On first load, the bundled `ashitaguide_config.lua` template is copied to:

```text
Ashita/config/addons/ashitaguide/ashitaguide_config.lua
```

Edit that persistent copy when adding or changing guides. The addon writes UI
preferences to `Ashita/config/addons/ashitaguide/settings.lua`, including window
positions and sizes, visibility, frame settings, map size, Valor settings,
Casket settings, shared background opacity, and active normal guides. Replacing
or reinstalling the addon directory does not overwrite either persistent file.

## Config Shape

```lua
return {
    settings = {
        -- 0 is fully transparent; 100 is fully opaque.
        opacity = 92,
        default_active_guides = { 'my_quest' },
    },
    guides = {
        {
            key = 'my_quest',
            name = 'My Quest',
            categories = { 'Quest', 'Jeuno' },
            steps = {
                {
                    text = 'Go to Mendi.',
                    zone = 'Lower Jeuno',
                    location = 'H-8',
                    npc = 'Mendi',
                    target_x = -59.961,
                    target_y = -75.649,
                    advance_on_target = true,
                },
                { text = 'Pick the answer.', answer = 'This is the statement.' },
            },
        },
    },
};
```

When a step has `target_x` and `target_y`, its active guide tab shows a north-up
navigation map. The player remains centered with a live heading marker and the
destination is plotted from its world coordinates. If `npc` is also set and
that entity is available in memory, its live position takes precedence over
the configured coordinates. The map is drawn entirely by the Lua addon and
does not depend on the Minimap plugin. Navigation is display-only and never
moves or targets the character. The map section is hidden until the player is
in the step's destination zone and a usable target position is available.

Any step with `npc` displays a world-space arrow above that NPC while it is
rendered. Set `advance_on_target = true` on find/select steps to advance once
the player selects that NPC. Leave it false or omit it on talk/interact steps
so keeping the NPC selected does not skip later instructions.

## Commands

```text
/agguide show
/agguide hide
/agguide toggle
/agguide config [show | hide | toggle]
/agguide list
/agguide start <guide key, name, or number>
/agguide stop <guide key, name, or number>
/agguide select <active guide key, name, or number>
/agguide next [active guide]
/agguide back [active guide]
/agguide reload
/agguide status
```

`/ashitaguide` is also accepted.

## Testing

Run the local surface validator from this folder:

```powershell
.\scripts\validate.ps1
```

If PowerShell blocks local scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

For an in-game test, copy the `ashitaguide` folder into the Ashita addons
folder and load it:

```text
/addon load ashitaguide
```
