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
- per-guide step progress that survives tab closes, config reopens, and game restarts
- separate guide runner and guide configuration windows
- live-polled, AI/MCP-authored temporary guides in the normal guide window
- typed MCP publication of a structured, one-step Auction House sale list
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
- optional destination marker over the Ashita Minimap `square-minimal` theme
- world-space arrow above the current step NPC when rendered
- optional NPC-target auto-advance for find steps
- optional job-and-level auto-advance for leveling steps
- built-in Pages of Valor tracker
- dedicated Pages of Valor window that appears from chat evidence
- built-in brown treasure casket code helper
- dedicated Casket Helper window that appears from live casket chat hints
- movable, display-only native decision-menu companion with guide answer highlighting
- optional legacy chat-frame hiding while the Decision Window is enabled
- separate Guides, Decision Window, AI Guides, Auction Sales, Valor, and Casket tabs in Guide Config
- independent 0-100% background opacity for the Guides, Decision, Valor, and Casket windows
- permanent AshitaChat-style titleless frames, dark borders, and transparent child regions
- compact AshitaChat-style tabs in the Guides window only
- content-sized Guides window with no resize handles or scrollbars
- a hard auto-fit width ceiling plus bounded text wrapping to prevent transient wide-window resizing between steps
- Guides-tab selector for a stationary window corner (`top_left`, `top_right`, `bottom_left`, or `bottom_right`)
- Decision Window selector for the same four anchored auto-expansion directions
- configurable all-steps list in the normal guide window
- balanced navigation layout with configurable map size
- Pages of Valor progress seeding from the current character chat log
- live Pages of Valor updates from incoming chat text and appended log lines
- character-scoped Pages of Valor state that survives game reloads and addon reinstalls

## Decision Window

When the game opens a native NPC choice menu, AshitaGuide displays a compact,
movable copy using the same titleless translucent style as the Guides window.
The cyan `>` follows the native game cursor. If the active guide step's
`answer` matches one of the visible choices, a separate gold `*` marks that
recommended row. Matching ignores case and punctuation and accepts instructions
such as `Select Other settings.`

The window is display-only. It does not select a choice, send input, inject a
packet, or advance the guide. Interaction continues through the normal game
controls.

For the current trial, **Hide native chat frame** is enabled by default in the
Decision Window configuration tab. It restores AshitaChat's original local
UI-only behavior from commit `1195c68`: the two legacy chat windows are pinned
closed each frame, except while the normal chat input is open. This also hides
native NPC and destination menus, so keep the Decision Window enabled while
testing and turn the option off if a menu is not represented correctly. The
same tab also controls the companion background opacity and which corner remains
stationary as differently sized menus expand. The window auto-sizes without
resize handles or scrollbars.

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
on login. Player chat is ignored, including speaker-tagged lines read through
the chat-log fallback, so players quoting hint phrases cannot alter the candidate
list. Live-event and chat-log copies of the same hint are collapsed, and chat-log
timestamps and formatting prefixes are removed before hints are displayed.
Reset is available directly in the Casket Helper window. The Casket tab in
Guide Config controls whether the helper is enabled, its background opacity, and
how long an inactive casket session is kept before new hints start a fresh
session.

## Pages of Valor

The built-in `pages_of_valor` helper is not listed in Guide Config. It watches
for accepted-regime and progress messages like:

```text
You defeated a training regime target. (Progress: 1/6)
```

The addon captures the target list and training area printed before `New
training regime registered!`. That runtime regime is displayed directly, with
one recovery signature for Crawlers' Nest Page 1 when the original transcript
has already left the chat tail. There is no manual page selector. CatsEyeXI
designated target progress updates each captured target row independently.
The dedicated window stays compact: it shows only the zone and remaining kill
counts. Its enabled state, zone display, progress totals, and visibility are
controlled from the Valor tab in Guide Config.
The Guides, Valor, and Casket windows use the same titleless dark frame and
adjustable background opacity as AshitaChat. Only the Guides window renders a
tab strip because it can contain multiple active guides; the single-view Valor
and Casket windows do not render tabs.
The Guides tab also controls whether the all-steps section is shown at the
bottom of the normal guide window. Map size is configurable from 120 to 260
pixels and defaults to 160 pixels. **Show destination on Minimap** overlays the
current step destination on the loaded Ashita Minimap plugin when its active
theme is `square-minimal`. AshitaGuide reads the base theme configuration from
`config/minimap/` and the active position, scale, zoom, and rotation directly
from the loaded plugin; distant destinations are held at the edge of the
visible square until they enter the map view. The marker uses Minimap's live
frame and mask dimensions so it remains attached to the same map location while
the player moves or changes zoom. While a destination is outside the visible
map range, its border marker moves as the player's bearing to it changes.

An accepted training regime or `Progress x/y` line opens the Pages of Valor window
automatically. Completion or cancellation closes it. You can close the window
manually; its background tracker remains active and will reopen it when another
progress line arrives. When the game says the current training regime will begin
anew, every target count resets to zero progress for the new cycle.

## Persistent Configuration

On first load, the bundled `ashitaguide_config.lua` template is copied to:

```text
Ashita/config/addons/ashitaguide/ashitaguide_config.lua
```

Edit that persistent copy when adding or changing guides. The addon writes UI
preferences to `Ashita/config/addons/ashitaguide/settings.lua`, including window
positions and sizes, the Guides and Decision anchor corners, native chat-frame
hiding, visibility, map size, Valor settings, Casket settings, per-window
background opacity, active normal guides, and each guide's last selected step.
A normal guide resumes that step even after its tab is closed and reopened or
the game is restarted.
Replacing or reinstalling the addon directory does not overwrite any of these
persistent files.

The active Pages of Valor target list, progress, and window state are stored in a
character-specific `Ashita/config/addons/ashitaguide/valor_state_<character>.lua`
file. It restores the guide before recent chat is replayed, so the target details
remain available even after the original page-registration messages leave the log
tail.

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
                    title = 'Level Beastmaster to 30',
                    text = 'Reach level 30 as Beastmaster.',
                    minimum_level = 30,
                    required_job = 'BST',
                },
                {
                    title = 'Talk to the NPC',
                    text = 'Speak with Mendi.',
                    zone = 'Lower Jeuno',
                    location = 'H-8',
                    npc = 'Mendi',
                    target_x = -59.961,
                    target_y = -75.649,
                    map_id = 15,
                    advance_on_target = false,
                },
            },
        },
    },
};
```

Keys must be stable and unique across bundled, configured, permanent, and AI
guides. Raw file writers should replace the complete file atomically rather than
append partial Lua. This interface only supplies display data; it does not send
commands or automate gameplay.

`AshitaGuide.Mcp` exposes `publish_temporary_guide` as the preferred typed
interface. It validates and safely renders one structured guide, atomically
upserts it by stable key, and preserves every other temporary guide already in
the file. `temporary_guides_status` lists the currently published keys, titles,
step counts, and file update time. Neither tool accepts raw Lua or a destination
path. If `ai_guides.lua` contains executable or malformed Lua instead of the
documented data-only table, the MCP publisher refuses to change it.

Temporary AI guides survive addon reloads and reinstalls because the file is
outside the addon directory. Clicking the `x` on an AI guide tab removes that
guide from `ai_guides.lua` and closes it. Closing a normal guide tab only stops
that guide, preserving the existing normal-guide behavior.

The **AI Guides** configuration tab lets the player supply or revise the title,
comma-separated categories used by the normal guide filters, and description.
**Make Permanent** retains all steps and navigation data, moves the guide to
`permanent_guides.lua`, and makes it available forever in the normal Guides
picker. Permanent guides are not deleted when their active tabs are closed.

## Auction House Sale Guides

`AshitaGuide.Mcp` exposes a narrowly scoped `publish_auction_sale_guide` tool.
It accepts structured item rows and atomically replaces one fixed publication:

```text
Ashita/config/addons/ashitaguide/auction_sale_guide.lua
```

The addon polls that file once per second and opens the publication in the
normal Guides window. An auction sale guide always has exactly one step and
renders one list. Each row contains:

- exact item name and optional resource id;
- quantity owned;
- listing quantity (`1` for singles or the full stack size);
- suggested gil price for one complete AH listing;
- optional market basis, observation date, and note.

The price is explicitly a suggested **listing price**, not a known current
minimum bid. Singles and stacks are distinct markets in FFXI and must be
published as separate rows when both are relevant.

Closing the auction sale guide tab deletes `auction_sale_guide.lua`. The list
cannot be reopened afterward; the AI must publish a new list. The **Auction
Sales** configuration tab can enable or suppress published lists, hide market
evidence or observation dates, focus the current list, or delete it forever.

This feature is display-only. The MCP server cannot open the Auction House,
move items, submit listings, send game commands, inject packets, or automate
selling. The player performs every Auction House action manually.

### Run the MCP server

Build the server first so package restore/build output cannot interfere with
MCP stdio:

```powershell
dotnet build .\src\AshitaGuide.Mcp\AshitaGuide.Mcp.csproj
```

Configure the client to launch the built DLL:

```json
{
  "mcpServers": {
    "ashitaguide": {
      "command": "dotnet",
      "args": [
        "<repository>\\src\\AshitaGuide.Mcp\\bin\\Debug\\net10.0\\AshitaGuide.Mcp.dll"
      ]
    }
  }
}
```

The default Ashita root is
`C:\Games\CatsEyeXI\catseyexi-client\Ashita`. Set
`ASHITAGUIDE_CONFIG_DIR` to the full persistent config directory or
`ASHITA_ROOT` to another Ashita installation when needed. Neither setting can
be supplied through an MCP tool, and the publisher never accepts a destination
path.

## Config Shape

```lua
return {
    settings = {
        -- Each addon display can use a different background opacity.
        guide_opacity = 92,
        -- window_x/window_y are the screen coordinates of this stationary corner.
        guide_anchor_corner = 'top_left',
        decision_enabled = true,
        decision_anchor_corner = 'top_left',
        decision_window_x = 80,
        decision_window_y = 180,
        decision_opacity = 96,
        minimap_marker_enabled = true,
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
                    map_id = 15,
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
the configured coordinates. When multiple entities share a name such as `???`,
the entity nearest the configured coordinates is used. With fallback
coordinates, live NPC resolution is distance-gated until the player is within
100 yalms. A same-named entity must also be within 25 yalms of those configured
coordinates before it can replace the fallback marker, preventing a distant
duplicate `???` from taking over. Without fallback coordinates, an unresolved
NPC name is checked against the local entity table once every five seconds.
Once found, AshitaGuide caches and cheaply refreshes that entity index every
0.25 seconds while it remains available. The map is drawn entirely by the Lua
addon and does not depend on the Minimap plugin.
Navigation is display-only and never moves or targets the character. The map
section is hidden until the player is in the step's destination zone and a
usable target position is available. Its view continuously adjusts its radius
based on distance, smoothly zooming in as the player approaches while retaining
five yalms of framing space. The active map radius is shown next to the map.

With `minimap_marker_enabled = true`, that same destination is also drawn as a
gold dot over the loaded Ashita Minimap plugin. This overlay currently requires
the `square-minimal` theme so its clipping boundary matches the displayed map.
Set optional `map_id` to the destination's verified live Minimap map/floor id;
the dot is suppressed whenever Minimap is displaying another map in the same
zone. AshitaGuide reads Minimap's live map id and transform but does not modify
Minimap, send commands, or require a custom DLL.
Use `/agguide mapdebug` to print a bounded coordinate snapshot when diagnosing
marker alignment.

Set `advance_on_target = true` on find/select steps to advance once the player
selects that NPC. Leave it false or omit it on talk/interact steps so keeping
the NPC selected does not skip later instructions. NPC destinations remain on
the guide navigation map and Minimap overlay; AshitaGuide intentionally does
not draw world-space markers over NPC models.

Set `advance_on_text` to a specific confirmation phrase to advance when that
phrase appears in a new incoming chat event. Matching ignores case,
punctuation, and repeated whitespace, so typographic quotation marks do not
make a reliable confirmation fail. This is event-driven and does not add a
chat-log polling loop; historical messages are intentionally not replayed.

Set `key_item` or `key_item_id` on a step to mark it done when the player
already owns that key item, including immediately after entering the step.
AshitaGuide also marks it done as soon as the matching `Obtained key item`
message arrives. The completed step remains selected until the player clicks
the normal `>` control.
Prefer `key_item_id` when multiple key items share the same resource name; both
fields may be supplied together to keep the guide readable. Matching
acquisitions are saved per character and step, so revisiting the step still
skips it when a private server tracks temporary quest fragments outside
Ashita's normal key-item ownership flags.

Set `minimum_level` on a step to advance automatically when the active main job
reaches that level. Add `required_job` to restrict completion to one job. Job
abbreviations and full names are accepted, so `BST` and `Beastmaster` are
equivalent. A qualifying level-up or switching to an already-qualified main job
advances the guide; a different job does not satisfy a restricted step.

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

Build and run the publisher self-test:

```powershell
dotnet build .\src\AshitaGuide.Mcp\AshitaGuide.Mcp.csproj
dotnet run --project .\src\AshitaGuide.Mcp\AshitaGuide.Mcp.csproj --no-build -- --self-test
```

For an in-game test, copy the `ashitaguide` folder into the Ashita addons
folder or run `install.ps1`, then load it:

```powershell
.\install.ps1
```

```text
/addon load ashitaguide
```
