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
- live-polled, AI/MCP-authored temporary guides in the normal guide window
- reinstall-safe AI guide persistence with delete-on-tab-close lifecycle
- in-game conversion of AI guides into permanent, reusable normal guides
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
- separate Guides, AI Guides, Valor, and Casket tabs in Guide Config
- independent 0-100% background opacity for the Guides, Valor, and Casket windows
- permanent AshitaChat-style titleless frames, dark borders, and transparent child regions
- compact AshitaChat-style tabs in the Guides window only
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
its background opacity, and how long an inactive casket session is kept before
new hints start a fresh session.

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
The Guides, Valor, and Casket windows use the same titleless dark frame and
adjustable background opacity as AshitaChat. Only the Guides window renders a
tab strip because it can contain multiple active guides; the single-view Valor
and Casket windows do not render tabs.
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
positions and sizes, visibility, map size, Valor settings,
Casket settings, per-window background opacity, and active normal guides.
Replacing or reinstalling the addon directory does not overwrite any of these
persistent files.

## AI / MCP Guide Contract

An AI or trusted local MCP client publishes temporary guides by replacing:

```text
Ashita/config/addons/ashitaguide/ai_guides.lua
```

The addon checks this file once per second. New and updated entries appear as
tabs in the existing Guides window without an addon reload. The file accepts
the same guide and step fields as the normal config:

```lua
return {
    guides = {
        {
            key = 'ai_current_goal',
            name = 'Current Goal',
            description = 'Optional temporary context.',
            categories = { 'Quest', 'AI' },
            steps = {
                {
                    title = 'Talk to the NPC',
                    text = 'Speak with Mendi.',
                    zone = 'Lower Jeuno',
                    location = 'H-8',
                    npc = 'Mendi',
                    target_x = -59.961,
                    target_y = -75.649,
                    advance_on_target = false,
                },
            },
        },
    },
};
```

Keys must be stable and unique across bundled, configured, permanent, and AI
guides. MCP writers should replace the complete file atomically rather than
append partial Lua. This interface only supplies display data; it does not send
commands or automate gameplay.

Temporary AI guides survive addon reloads and reinstalls because the file is
outside the addon directory. Clicking the `x` on an AI guide tab removes that
guide from `ai_guides.lua` and closes it. Closing a normal guide tab only stops
that guide, preserving the existing normal-guide behavior.

The **AI Guides** configuration tab lets the player supply or revise the title,
comma-separated categories used by the normal guide filters, and description.
**Make Permanent** retains all steps and navigation data, moves the guide to
`permanent_guides.lua`, and makes it available forever in the normal Guides
picker. Permanent guides are not deleted when their active tabs are closed.

## Config Shape

```lua
return {
    settings = {
        -- Each addon display can use a different background opacity.
        guide_opacity = 92,
        valor_opacity = 92,
        casket_opacity = 92,
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
in the step's destination zone and a usable target position is available. Its
view automatically selects a 5, 10, 20, 40, or larger yalm radius based on
distance, visibly zooming in as the player approaches. The active map radius is
shown next to the map.

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
