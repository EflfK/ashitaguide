$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitaguide.lua'
$config = Join-Path $root 'ashitaguide_config.lua'
$alarm = Join-Path $root 'sounds\claim-window-alert.wav'

if (-not (Test-Path -LiteralPath $addon)) {
    throw "Missing addon file: $addon"
}

if (-not (Test-Path -LiteralPath $config)) {
    throw "Missing config file: $config"
}

if (-not (Test-Path -LiteralPath $alarm)) {
    throw "Missing custom NM timer alarm: $alarm"
}

$alarmBytes = [System.IO.File]::ReadAllBytes($alarm)
if (($alarmBytes.Length -lt 44) -or
        ([System.Text.Encoding]::ASCII.GetString($alarmBytes, 0, 4) -ne 'RIFF') -or
        ([System.Text.Encoding]::ASCII.GetString($alarmBytes, 8, 4) -ne 'WAVE')) {
    throw 'Custom NM timer alarm must be a valid RIFF/WAVE file.'
}

$content = Get-Content -LiteralPath $addon -Raw

function Get-NmHuntBlock([string] $name) {
    $escapedName = [regex]::Escape($name)
    $match = [regex]::Match(
        $content,
        "(?ms)^    \{\r?\n        name = '$escapedName'.*?^    \},")
    if (-not $match.Success) {
        throw "Missing NM Hunt catalog entry: $name"
    }
    return $match.Value
}

function Assert-NmHuntContains([string] $name, [string[]] $patterns) {
    $block = Get-NmHuntBlock $name
    foreach ($pattern in $patterns) {
        if ($block -notmatch $pattern) {
            throw "The $name NM Hunt entry is missing required data matching: $pattern"
        }
    }
}

function Assert-NmHuntHasNoFixedNmTimer([string] $name) {
    $block = Get-NmHuntBlock $name
    if ($block -match '\bnm_seconds\s*=') {
        throw "The $name NM Hunt entry must not present a fixed NM timer for a random window or group spawn."
    }
}

$required = @(
    "addon.name    = 'ashitaguide'",
    "ashita.events.register('d3d_present'",
    "ashita.events.register('command'",
    "ashita.events.register('text_in'",
    "pages_of_valor",
    "activation_evidence",
    "capture_pov_transcript",
    "extract_designated_progress",
    "active_regime",
    "AshitaGuideValor",
    "render_valor_config",
    "display_bg",
    "push_display_window_style",
    "push_config_window_style",
    "pop_window_style",
    "guide_show_step_list",
    "guide_tabs_bottom",
    "guide_map_size",
    "minimap_marker_enabled",
    "render_minimap_destination_marker",
    "MINIMAP_RUNTIME_SIGNATURE",
    "map_scale_raw",
    "current_map_id",
    "map_id",
    "navigation_context",
    "minimap_handoff_context",
    "destination_zone_id",
    "player_zone_id",
    "navigation_target_live_refresh_seconds",
    "navigation_target_miss_retry_seconds",
    "navigation_target_fallback_scan_distance",
    "navigation_target_fallback_match_distance",
    "navigation_target_matches_fallback",
    "read_navigation_target_at_index",
    "navigation_world_radius",
    "config_dir_path",
    "bootstrap_persistent_config",
    "settings.lua",
    "save_settings_if_needed",
    "guide_steps",
    "lua_number_map",
    "valor_state.lua",
    "state.save_pov_state_if_needed",
    "state.load_persisted_pov_state",
    "state.restore_persisted_pov_state_if_needed",
    "current training regime will begin anew",
    "falls to the ground",
    "infer_pov_runtime_page",
    "target_matches_defeated",
    "crawlers_nest_page_1",
    "capture_window_geometry",
    "guide_anchor_corner",
    "render_guide_anchor_selector",
    "Anchor corner##ashitaguide_anchor_corner",
    "capture_guide_window_anchor",
    "window_always_auto_resize",
    "window_no_scroll_with_mouse",
    "GUIDE_WINDOW_MAX_WIDTH",
    "SetNextWindowSizeConstraints",
    "casket_enabled",
    "casket_stale_seconds",
    "guide_opacity",
    "valor_opacity",
    "casket_opacity",
    "process_casket_text",
    "AshitaGuideCasket",
    "render_casket_config",
    "render_casket_window",
    "casket_parse_message",
    "casket_normalize_message",
    "casket_is_player_chat",
    "PLAYER_CHAT_MODES",
    "one%s+of%s+the%s+two%s+digits",
    "guide_is_configurable",
    "ai_guides.lua",
    "permanent_guides.lua",
    "poll_ai_guides_file",
    "delete_ai_guide",
    "close_guide_tab",
    "make_ai_guide_permanent",
    "render_ai_guide_config",
    "AI Guides##ashitaguide_config_ai_guides",
    "auction_sale_guide.lua",
    "auction_sale_list",
    "poll_auction_sale_guide_file",
    "delete_auction_sale_guide",
    "render_auction_sale_config",
    "render_auction_sale_items",
    "Auction Sales##ashitaguide_config_auction_sales",
    "BeginTabBar",
    "Tabs on bottom##ashitaguide_guide_tabs_bottom",
    "AshitaGuideConfig",
    "tab_open",
    "AddTriangleFilled",
    "truthy",
    "advance_on_target",
    "advance_on_text",
    "key_item_step_completions",
    "persist_key_item_step_completion",
    "key_item_step_is_persisted",
    "update_key_item_step_completion",
    "DONE - click > to continue",
    "update_level_step_auto_advance",
    "minimum_level",
    "required_job",
    "GetMainJobLevel",
    "target_x",
    "state.normalize_destinations",
    "step.destinations",
    "filter_scan",
    "state.normalize_filter_scan",
    "state.render_filter_scan_button",
    "Filter Widescan:",
    "respawn_target_index",
    "respawn_target_server_id",
    "respawn_replacement_index",
    "respawn_seconds",
    "respawn_timer_expirations",
    "state.update_respawn_timers",
    "state.process_respawn_text",
    "state.render_respawn_timer",
    "state.update_nm_hunt_placeholder_timers",
    "state.process_nm_hunt_placeholder_text",
    "state.start_nm_hunt_placeholder_timer",
    "state.nm_hunt_tracked_entities",
    "state.global_nm_respawn_timers",
    "state.render_global_nm_respawn_timers",
    "state.play_nm_hunt_alarm",
    "PlaySoundA",
    "claim-window-alert.wav",
    "0x00020003",
    "SystemNotification",
    "Expected respawn in %02d:%02d",
    "Progress",
    "ReadProcessMemory",
    "guarded_read_bytes",
    "function decision.active_state",
    "function decision.read_menu",
    "function decision.update",
    "function decision.render",
    "function decision.recommended_index",
    "function decision.capture_anchor",
    "function decision.render_config",
    "Decision Window##ashitaguide_config_decision",
    "decision_anchor_corner",
    "decision_window_x",
    "decision_window_y",
    "decision_opacity",
    "decision_hide_native_chat",
    "function decision.find_legacy_chat_windows",
    "function decision.pin_legacy_chat_window",
    "function decision.pin_legacy_chat_closed",
    "A1????????C64059018B0D????????C6415901C20800"
)

if ($content.Contains('MessageBeep(0x30)')) {
    throw 'NM hunt alarms must not use the Windows Exclamation sound associated with consent/admin prompts.'
}

foreach ($needle in $required) {
    if ($content -notlike "*$needle*") {
        throw "Missing expected surface: $needle"
    }
}

$blocked = @(
    'InjectPacket',
    'SendPacket',
    'SetTarget',
    '/target',
    '/targetnpc',
    '/attack',
    '/follow',
    '/item',
    '/ma ',
    '/magic',
    '/ja ',
    '/jobability',
    '/trade'
)

foreach ($needle in $blocked) {
    if ($content -like "*$needle*") {
        throw "Read-only boundary violation candidate: $needle"
    }
}

$memoryWrites = [regex]::Matches($content, 'ashita\.memory\.write_[A-Za-z0-9_]+')
if ($memoryWrites.Count -ne 1 -or $memoryWrites[0].Value -ne 'ashita.memory.write_uint32') {
    throw 'Only the single legacy chat-window visibility write is allowed.'
}

if ($content -notmatch 'ashita\.memory\.write_uint32\(window \+ 0x34, 0x00\)') {
    throw 'Legacy chat hiding must only close the known local chat-window field.'
}

if ($content -match 'render_npc_world_marker|world_to_screen|ashitaguide_npc_world_marker') {
    throw 'NPC destinations must not render through-walls world-space markers.'
}

if ($content -notmatch "for _, key in ipairs\(close_keys\) do\s+close_guide_tab\(key\)") {
    throw 'Guide tab close controls do not use the lifecycle-aware close handler.'
}

$queueCommands = [regex]::Matches($content, 'QueueCommand')
if ($queueCommands.Count -ne 3 -or
    $content -notmatch "QueueCommand\(-1, '/filterscan ' \.\. step\.filter_scan\)" -or
    $content -notmatch "QueueCommand\(-1, '/filterscan ' \.\. hunt\.filter_scan\)" -or
    $content -notmatch "QueueCommand\(-1, '/renamer merge ' \.\. list_name\)") {
    throw 'Only the attended local Filterscan and Renamer buttons may queue commands.'
}

if ($content -notmatch "string\.format\('ashitaguide_nm_%d', math\.floor\(mob_id\)\)" -or
    $content -notmatch "state\.nm_hunt_placeholder_display_name\(index, original_name\)" -or
    $content -notmatch "path_join\(addons_root, 'renamer'\)") {
    throw 'NM Hunt Renamer lists must use bounded names and the local Renamer config folder.'
}

if ($content -notmatch "return string\.format\('PH %03X - %s', index, original_name\):sub\(1, 27\)" -or
    $content -notmatch 'expected_server_id == nil' -or
    ([regex]::Matches($content, 'state\.placeholder_name_matches\(')).Count -ne 2) {
    throw 'Placeholder timers must accept bounded Renamer labels while retaining exact server-ID identity.'
}

if ($content -notmatch [regex]::Escape('filter:match("^[%w%s,_''%-]+$")')) {
    throw 'Filterscan values must remain restricted to safe local filter characters.'
}

if ($content -notmatch "GetHPPercent\(index\)" -or
    $content -notmatch "tracker\.last_hp > 0" -or
    $content -notmatch "clock - tracker\.targeted_at <= 15") {
    throw 'Respawn timers must require an exact observed HP transition or a recent exact target before defeat text can start them.'
}

if ($content -notmatch "index = 0x14A, server_id = 17199434, name = 'Damselfly'" -or
    $content -notmatch "index = 0x1C9, server_id = 17199561, name = 'Sand Bat'" -or
    $content -notmatch "index = 0x1CA, server_id = 17199562, name = 'Sand Bat'" -or
    $content -notmatch "index = 0x1CB, server_id = 17199563, name = 'Sand Bat'" -or
    $content -notmatch "index = 0x17B, server_id = 17215867, name = 'Rock Lizard'" -or
    $content -notmatch "index = 0x18F, server_id = 17215887, name = 'Rock Lizard'" -or
    $content -notmatch "timer_kind = 'ph17b'" -or
    $content -notmatch "timer_kind = 'ph18f'") {
    throw 'Current lottery NM hunts must declare their exact placeholders for generic automatic timers.'
}

Assert-NmHuntContains 'Valkurm Emperor' @(
    "mob_id = 17199438",
    "zone_id = 103",
    "index = 0x14E, server_id = 17199438, name = 'Valkurm Emperor'",
    "index = 0x14A, server_id = 17199434, name = 'Damselfly'",
    "placeholder_seconds = 300",
    "nm_seconds = 3600"
)

$lizzyBlock = Get-NmHuntBlock 'Leaping Lizzy'
foreach ($pattern in @(
        "mob_id = 17215868",
        "zone_id = 107",
        "index = 0x17B, server_id = 17215867, name = 'Rock Lizard'",
        "index = 0x18F, server_id = 17215887, name = 'Rock Lizard'",
        "kind = 'ph17b'.+seconds = 315",
        "kind = 'ph18f'.+seconds = 315")) {
    if ($lizzyBlock -notmatch $pattern) {
        throw "The Leaping Lizzy NM Hunt entry is missing corrected 5:15 data matching: $pattern"
    }
}
if ($lizzyBlock -match 'seconds = 330') {
    throw 'Leaping Lizzy placeholder timers must use the verified 5:15 reference, not 5:30.'
}

Assert-NmHuntContains 'Ose' @(
    'mob_id = 17649822', 'zone_id = 213',
    "index = 0x09E, server_id = 17649822, name = 'Ose'",
    "index = 0x095, server_id = 17649813, name = 'Torama'",
    "index = 0x096, server_id = 17649814, name = 'Torama'",
    "index = 0x097, server_id = 17649815, name = 'Torama'",
    "index = 0x098, server_id = 17649816, name = 'Torama'",
    "index = 0x09B, server_id = 17649819, name = 'Torama'",
    "index = 0x09C, server_id = 17649820, name = 'Torama'",
    "index = 0x09F, server_id = 17649823, name = 'Torama'",
    "index = 0x0A0, server_id = 17649824, name = 'Torama'"
)
$oseBlock = Get-NmHuntBlock 'Ose'
foreach ($timerKind in @('ph095', 'ph096', 'ph097', 'ph098', 'ph09b', 'ph09c', 'ph09f', 'ph0a0')) {
    $pattern = "kind = '$timerKind'.*seconds = 960"
    if ($oseBlock -notmatch $pattern) {
        throw "The Ose NM Hunt entry is missing its verified 16-minute timer matching: $pattern"
    }
}
if ($oseBlock -match 'seconds = 300') {
    throw 'Ose placeholder timers must use the verified 16-minute CatsEyeXI mob-group respawn, not five minutes.'
}

Assert-NmHuntContains 'Sewer Syrup' @(
    'mob_id = 17461307', 'zone_id = 167',
    "index = 0x03B, server_id = 17461307, name = 'Sewer Syrup'",
    "index = 0x039, server_id = 17461305, name = 'Mousse'",
    "index = 0x03A, server_id = 17461306, name = 'Mousse'"
)

Assert-NmHuntContains 'Argus' @(
    'mob_id = 17588674', 'zone_id = 198',
    "index = 0x1C2, server_id = 17588674, name = 'Argus'",
    "index = 0x1CD, server_id = 17588685, name = 'Leech King'"
)
Assert-NmHuntHasNoFixedNmTimer 'Argus'

Assert-NmHuntContains 'Bloodtear Baldurf' @(
    'mob_id = 17195318', 'zone_id = 102',
    "index = 0x136, server_id = 17195318, name = 'Bloodtear Baldurf'",
    "index = 0x135, server_id = 17195317, name = 'Lumbering Lambert'",
    "index = 0x087, server_id = 17195143, name = 'Battering Ram'",
    "index = 0x134, server_id = 17195316, name = 'Battering Ram'"
)
Assert-NmHuntHasNoFixedNmTimer 'Bloodtear Baldurf'

$carmineBlock = Get-NmHuntBlock 'Carmine Dobsonfly'
foreach ($pattern in @(
        'mob_id = 16900230', 'zone_id = 30',
        "index = 0x086, server_id = 16900230, name = 'Carmine Dobsonfly'",
        "index = 0x087, server_id = 16900231, name = 'Carmine Dobsonfly'",
        "index = 0x088, server_id = 16900232, name = 'Carmine Dobsonfly'",
        "index = 0x089, server_id = 16900233, name = 'Carmine Dobsonfly'",
        "index = 0x08A, server_id = 16900234, name = 'Carmine Dobsonfly'",
        "index = 0x08B, server_id = 16900235, name = 'Carmine Dobsonfly'",
        "index = 0x08C, server_id = 16900236, name = 'Carmine Dobsonfly'",
        "index = 0x08D, server_id = 16900237, name = 'Carmine Dobsonfly'",
        "index = 0x08E, server_id = 16900238, name = 'Carmine Dobsonfly'",
        "index = 0x08F, server_id = 16900239, name = 'Carmine Dobsonfly'")) {
    if ($carmineBlock -notmatch $pattern) {
        throw "The Carmine Dobsonfly NM Hunt entry is missing verified group data matching: $pattern"
    }
}
if ($carmineBlock -notmatch "spawn_type = '[^']*[Tt]imed[^']*'" -or
        $carmineBlock -match '\bplaceholders\s*=' -or
        $carmineBlock -match '\bnm_seconds\s*=') {
    throw 'Carmine Dobsonfly must be a ten-member group/random-window hunt without placeholder or fixed NM timers.'
}

Assert-NmHuntContains 'Jaggedy-Eared Jack' @(
    'mob_id = 17187111', 'zone_id = 100',
    "index = 0x127, server_id = 17187111, name = 'Jaggedy-Eared Jack'",
    "index = 0x126, server_id = 17187110, name = 'Forest Hare'"
)
Assert-NmHuntHasNoFixedNmTimer 'Jaggedy-Eared Jack'

Assert-NmHuntContains 'Capricious Cassie' @(
    'mob_id = 17613129', 'zone_id = 204',
    "index = 0x049, server_id = 17613129, name = 'Capricious Cassie'"
)
Assert-NmHuntHasNoFixedNmTimer 'Capricious Cassie'

Assert-NmHuntContains 'Serket' @(
    'mob_id = 17596720', 'zone_id = 200',
    "index = 0x030, server_id = 17596720, name = 'Serket'"
)
Assert-NmHuntHasNoFixedNmTimer 'Serket'

Assert-NmHuntContains 'Amemet' @(
    'mob_id = 17490016', 'zone_id = 174',
    "index = 0x060, server_id = 17490016, name = 'Amemet'",
    "index = 0x00C, server_id = 17489932, name = 'Sand Lizard'",
    "index = 0x00D, server_id = 17489933, name = 'Sand Lizard'",
    "index = 0x00E, server_id = 17489934, name = 'Sand Lizard'",
    "index = 0x04A, server_id = 17489994, name = 'Sand Lizard'",
    "index = 0x050, server_id = 17490000, name = 'Sand Lizard'",
    "index = 0x051, server_id = 17490001, name = 'Sand Lizard'",
    "index = 0x052, server_id = 17490002, name = 'Sand Lizard'",
    "index = 0x053, server_id = 17490003, name = 'Sand Lizard'",
    "index = 0x054, server_id = 17490004, name = 'Sand Lizard'",
    "index = 0x055, server_id = 17490005, name = 'Sand Lizard'",
    "index = 0x058, server_id = 17490008, name = 'Sand Lizard'",
    "index = 0x059, server_id = 17490009, name = 'Sand Lizard'",
    "index = 0x05A, server_id = 17490010, name = 'Sand Lizard'"
)

$arthroBlock = Get-NmHuntBlock 'King Arthro'
foreach ($pattern in @(
        'mob_id = 17203216', 'zone_id = 104',
        "index = 0x010, server_id = 17203216, name = 'King Arthro'",
        "index = 0x006, server_id = 17203206, name = 'Knight Crab'",
        "index = 0x007, server_id = 17203207, name = 'Knight Crab'",
        "index = 0x008, server_id = 17203208, name = 'Knight Crab'",
        "index = 0x009, server_id = 17203209, name = 'Knight Crab'",
        "index = 0x00A, server_id = 17203210, name = 'Knight Crab'",
        "index = 0x00B, server_id = 17203211, name = 'Knight Crab'",
        "index = 0x00C, server_id = 17203212, name = 'Knight Crab'",
        "index = 0x00D, server_id = 17203213, name = 'Knight Crab'",
        "index = 0x00E, server_id = 17203214, name = 'Knight Crab'",
        "index = 0x00F, server_id = 17203215, name = 'Knight Crab'")) {
    if ($arthroBlock -notmatch $pattern) {
        throw "The King Arthro NM Hunt entry is missing verified group data matching: $pattern"
    }
}
if ($arthroBlock -match '\b(?:nm_seconds|placeholder_seconds|timers)\s*=') {
    throw 'King Arthro must not expose ordinary placeholder timers or a fixed group/NM timer.'
}

foreach ($zoneId in @(30, 100, 102, 103, 104, 107, 167, 174, 198, 200, 204, 213)) {
    if ($content -notmatch "(?s)state\.NM_HUNTS_BY_ZONE = \{.+\[$zoneId\] = state\.[A-Z0-9_]+_NM_HUNTS") {
        throw "The NM Hunt catalog must register zone $zoneId in NM_HUNTS_BY_ZONE."
    }
}

if ($content -notmatch "(?s)state\.update_nm_hunt_placeholder_timers = function.+placeholder\.index.+placeholder\.server_id.+placeholder\.name.+tracker\.last_hp > 0" -or
    $content -notmatch "(?s)state\.process_nm_hunt_placeholder_text = function.+clock - tracker\.targeted_at <= 15.+best\.placeholder") {
    throw 'NM hunt placeholder timers must use generic exact-index HP and recent-target defeat-text detection.'
}

if ($content -notmatch "respawn_target_server_id = 17199434" -or
    $content -notmatch "respawn_target_index = 0x14A" -or
    $content -notmatch "respawn_seconds = 300") {
    throw 'The Valkurm Emperor guide must track the verified 14A placeholder with a five-minute timer.'
}
if ($content -notmatch "index = 0x14E, server_id = 17199438, name = 'Valkurm Emperor'" -or
    $content -notmatch "(?s)state\.global_nm_respawn_timers = function.+nm_hunt_timer_token\(hunt, 'nm'\).+expiration ~= nil" -or
    $content -notmatch "NM RESPAWN WINDOWS" -or
    $content -notmatch "catalog == nil and #global_nm_timers == 0") {
    throw 'Global NM respawn tracking must detect exact NM deaths and remain visible across zones.'
}
if ($content -notmatch "(?s)state\.render_global_nm_respawn_timers = function.+render_nm_hunt_timer_line\(hunt, 'nm', label\)") {
    throw 'The global respawn list must render NM timers only.'
}
if ($content -notmatch "target_x = -228\.957" -or
    $content -notmatch "target_y = -101\.226" -or
    $content -notmatch "marker_style = 'damselfly'" -or
    $content -notmatch "path_enabled = false") {
    throw 'The Valkurm Emperor guide must show one damselfly marker at the verified 14A anchor without pathing.'
}
if ($content -notmatch "tab_row_width \+ 3 \+ tab_group_width <= GUIDE_TEXT_WRAP_POS_X") {
    throw 'Guide tabs must wrap within the existing guide window width.'
}

if ($content -notmatch 'local function text_colored_wrapped\(color, text, wrap_position\)' -or
    $content -notmatch 'text_colored_wrapped\(COLORS\.muted, hunt\.details, width - 12\)') {
    throw 'The NM Hunt window must use its own text-wrap boundary.'
}

if ($content -notmatch "capture_window_geometry\(\s*'nm_hunt_window_x'" -or
    $content -notmatch "SetNextWindowSizeConstraints\(\{ 320, 240 \}, \{ 700, 900 \}\)" -or
    $content -match 'Show all on minimap##nm_hunt_all' -or
    $content -notmatch 'MAP   TRACK' -or
    $content -notmatch 'nm_hunt_map_' -or
    $content -notmatch 'nm_hunt_track_' -or
    $content -notmatch 'nm_hunt_toggle_list' -or
    $content -notmatch 'state\.render_nm_hunt_details\(hunt, width\)' -or
    $content -match 'Scan filters Widescan; Rename PHs labels') {
    throw 'The NM Hunt window must remain movable and resizable, with collapsible per-NM map and tracking controls.'
}

if ($content -notmatch "(?s)previous == nil and guide\.type ~= 'pages_of_valor'.+state\.settings\.guide_steps\[guide\.key\]") {
    throw 'Normal guides do not restore their persisted step when reopened.'
}

if ($content -notmatch "(?s)local function next_step\(run\).+state\.settings\.guide_steps\[run\.key\] = run\.step_index") {
    throw 'Forward guide navigation does not persist the selected step.'
}

if ($content -notmatch "(?s)local function previous_step\(run\).+state\.settings\.guide_steps\[run\.key\] = run\.step_index") {
    throw 'Backward guide navigation does not persist the selected step.'
}

if ($content -notmatch "(?s)local function handle_pov_text\(run, text\).+if \(state\.is_training_repeat\(text\)\) then.+pov\.progress = 0.+for _, target in ipairs\(pov\.runtime_page\.targets or \{\}\) do target\.progress = 0; end.+if \(is_training_accept\(text\)\) then") {
    throw 'Pages of Valor repeat handling must reset progress before the restart message can be treated as acceptance.'
}

if (-not $content.Contains("name:match('[sxz]es$')") -or
    -not $content.Contains("name:match('ches$')") -or
    -not $content.Contains("name:match('shes$')") -or
    -not $content.Contains("name:sub(-1) == 's'")) {
    throw 'Pages of Valor target matching must preserve singular names that merely end in e before plural s.'
}

if (-not $content.Contains('state.target_matches_defeated = function (target_name, defeated_name)') -or
    -not $content.Contains("normalized_target:match('^members? of the (.-) family$')") -or
    -not $content.Contains('word:sub(1, #family) == family')) {
    throw 'Pages of Valor target matching must recognize family objectives from defeated member names.'
}

if ($content -match 'local function target_matches_defeated') {
    throw 'Pages of Valor target matching must not consume another top-level Lua local.'
}

if ($content -notmatch "guide\.origin == 'ai'\) then\s+return delete_ai_guide\(key\)") {
    throw 'AI guide tabs are not wired to persistent deletion.'
}

if ($content -notmatch "guide\.origin == 'auction_sale'\) then\s+return delete_auction_sale_guide\(key\)") {
    throw 'Auction sale guide tabs are not wired to permanent deletion.'
}

if ($content -notmatch "poll_ai_guides_file\(\);\s+poll_auction_sale_guide_file\(\);") {
    throw 'Auction sale guide publication is not polled with AI guide data.'
}

$mcpProject = Join-Path $root 'src\AshitaGuide.Mcp\AshitaGuide.Mcp.csproj'
$mcpTools = Join-Path $root 'src\AshitaGuide.Mcp\AuctionSaleGuideTools.cs'
$mcpStorage = Join-Path $root 'src\AshitaGuide.Mcp\AuctionSaleGuideStorage.cs'
$temporaryTools = Join-Path $root 'src\AshitaGuide.Mcp\TemporaryGuideTools.cs'
$temporaryStorage = Join-Path $root 'src\AshitaGuide.Mcp\TemporaryGuideStorage.cs'
foreach ($path in @($mcpProject, $mcpTools, $mcpStorage, $temporaryTools, $temporaryStorage)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing AshitaGuide MCP surface: $path"
    }
}

$toolsContent = Get-Content -LiteralPath $mcpTools -Raw
$storageContent = Get-Content -LiteralPath $mcpStorage -Raw
if ($toolsContent -notlike '*publish_auction_sale_guide*') {
    throw 'AshitaGuide MCP publish tool is missing.'
}
if ($storageContent -notlike '*File.Move(tempPath, targetPath, true)*') {
    throw 'AshitaGuide MCP publication must replace the fixed file atomically.'
}
if ($storageContent -match 'QueueCommand|InjectPacket|SendPacket|SetTarget') {
    throw 'AshitaGuide MCP crossed the display-only safety boundary.'
}

$temporaryToolsContent = Get-Content -LiteralPath $temporaryTools -Raw
$temporaryStorageContent = Get-Content -LiteralPath $temporaryStorage -Raw
if ($temporaryToolsContent -notlike '*publish_temporary_guide*' -or
    $temporaryToolsContent -notlike '*temporary_guides_status*') {
    throw 'AshitaGuide generic temporary guide MCP tools are missing.'
}
if ($temporaryStorageContent -notlike '*File.Move(tempPath, path, true)*') {
    throw 'Temporary guide MCP publication must replace the fixed file atomically.'
}
if ($temporaryStorageContent -match 'QueueCommand|InjectPacket|SendPacket|SetTarget') {
    throw 'Temporary guide MCP crossed the display-only safety boundary.'
}

if ($content -notmatch "guide\.origin ~= 'ai'") {
    throw 'Temporary AI guides are not separated from the normal guide picker.'
}

if ($content -notmatch "local sub_active = truthy\(safe_read\(function \(\) return target:GetIsSubTargetActive\(\); end, false\)\)") {
    throw 'Target selection must normalize AshitaCore numeric boolean values.'
}

if ($content -notmatch "local function navigation_world_radius\(distance\)\s+return math\.max\(5, distance \+ 5\);\s+end") {
    throw 'Navigation map must zoom smoothly with a five-yalm framing margin.'
}

if ($content -notmatch "navigation_target_live_refresh_seconds = 0\.25" -or
    $content -notmatch "navigation_target_miss_retry_seconds = 5\.0" -or
    $content -notmatch "navigation_target_fallback_scan_distance = 100\.0" -or
    $content -notmatch "navigation_target_fallback_match_distance = 25\.0") {
    throw 'Navigation target lookup throttles do not match the documented limits.'
}

if ($content -notmatch "(?s)fallback_distance > state\.navigation_target_fallback_scan_distance.+return nil") {
    throw 'Fallback coordinates must distance-gate live NPC entity scans.'
}

if ($content -notmatch "(?s)state\.navigation_target_matches_fallback.+maximum \* maximum.+state\.navigation_target_matches_fallback\(refreshed, fallback_x, fallback_y\).+state\.navigation_target_matches_fallback\(candidate, fallback_x, fallback_y\)") {
    throw 'Live NPC candidates and cached targets must stay near configured fallback coordinates.'
}

if ($content -notmatch "(?s)cached\.index.+state\.read_navigation_target_at_index\(entity, cached\.index, lookup, now\)") {
    throw 'Resolved NPC navigation targets must refresh through their cached entity index.'
}

if ($content -notmatch "(?s)candidate_distance_squared.+best_distance_squared.+result = candidate") {
    throw 'Duplicate NPC names must resolve to the entity nearest configured fallback coordinates.'
}

if ($content -notmatch "now - cached\.checked_at < state\.navigation_target_miss_retry_seconds") {
    throw 'Unresolved NPC navigation targets must use the miss retry throttle.'
}

if ($content -notmatch "minimap\.mask_width \* minimap\.zoom\s+/ 100 \* minimap\.scale_x" -or
    $content -notmatch "minimap\.mask_height \* minimap\.zoom\s+/ 100 \* minimap\.scale_y") {
    throw 'Minimap navigation scaling must match the plugin live map transform.'
}

if ($content -notmatch "theme:match\('\^square'\)") {
    throw 'Minimap destination overlays must support calibrated square-derived themes.'
}

if ($content -notmatch "(?s)navigation\.target_map_id ~= nil.+minimap\.current_map_id ~= navigation\.target_map_id.+Minimap marker hidden") {
    throw 'Minimap markers must be hidden when a step targets another map or floor.'
}

if ($content -notmatch "(?s)for _, destination in ipairs\(step\.destinations or \{\}\) do.+destination_marker_x.+destination_marker_y.+AddCircleFilled") {
    throw 'Additional step destinations must render together on the Minimap.'
}

if ($content -notmatch "(?s)local function render_navigation_map\(step, navigation\).+furthest_destination_distance.+navigation_destination_screen_x.+navigation_destination_screen_y.+Markers: %d") {
    throw 'Additional step destinations must render together on the guide Navigation map.'
}

if ($content -notmatch "(?s)local function navigation_context\(step\).+primary_destination.+step\.destinations\[1\].+target_map_id") {
    throw 'Destination-only steps must use their first destination as the navigation anchor.'
}

if ($content -notmatch "(?s)local function render_guide_window\(\).+window_no_resize.+window_no_scrollbar.+window_always_auto_resize") {
    throw 'Guides window must auto-size without resize handles or scrollbars.'
}

if ($content -notmatch "(?s)local function set_next_guide_window_position\(width, height\).+SetNextWindowPos\(\{ window_x, window_y \}, IMGUI\.cond_appearing\)") {
    throw 'Guides window must reapply its configured position when it appears and remain draggable afterward.'
}

if ($content -notmatch "PushTextWrapPos\(math\.max\(cursor_x \+ 1, GUIDE_TEXT_WRAP_POS_X\)\)") {
    throw 'Guide text must use a stable maximum wrap width during auto-resize.'
}

if ($content -notmatch "SetNextWindowSizeConstraints\(\{ 0, 0 \}, \{ GUIDE_WINDOW_MAX_WIDTH, 10000 \}\)") {
    throw 'Guides window must enforce its auto-fit width ceiling before Begin.'
}

if ($content -notmatch "(?s)function decision\.render\(\).+window_no_resize.+window_no_scrollbar.+window_no_scroll_with_mouse.+window_always_auto_resize.+window_no_saved_settings") {
    throw 'Decision window must auto-size from its configured anchor without scrollbars.'
}

if ($content -notmatch "(?s)function decision\.render\(\).+SetNextWindowPos\(\{ window_x, window_y \}, IMGUI\.cond_first_use\)") {
    throw 'Decision window must remain draggable after applying its initial configured position.'
}

if ($content -notmatch "(?s)function decision\.capture_anchor\(expected_x, expected_y\).+decision\.top_left\(width, height\)") {
    throw 'Decision window must preserve its configured corner while its content size changes.'
}

if ($content -match "capture_window_geometry\('window_x', 'window_y', 'window_width', 'window_height'") {
    throw 'Guides window must not persist a user-resized size.'
}

if ($content -notmatch "Map radius: %.1f yalms") {
    throw 'Navigation map must display its active zoom radius.'
}

if ($content -notmatch "(?s)PLAYER_CHAT_MODES\[normalized_mode\].+PLAYER_CHAT_MODES\[normalized_alternate_mode\]") {
    throw 'Casket player-chat filtering must check original and modified chat modes.'
}

if ($content -notmatch "(?s)local prefix = clean_message\(text\):sub\(1, 128\).+prefix:find\('<\[\^<>\]\+>%s'\)") {
    throw 'Casket player-chat filtering must reject speaker-tagged chat-log lines.'
}

if ($content -notmatch "(?s)local function casket_normalize_message\(message\).+you have a hunch.+%\[%d%d:%d%d:%d%d%\].+local function casket_parse_message\(message\).+casket_normalize_message\(message\)") {
    throw 'Casket messages must remove chat-log prefixes before parsing and display.'
}

if ($content -notmatch "(?s)last_clue_signature == clue_signature.+last_clue_observed_at.+<= 2.+last_clue_signature = clue_signature") {
    throw 'Casket hints must collapse duplicate live-event and chat-log observations.'
}

$configStart = $content.IndexOf('local function render_casket_config()')
$windowStart = $content.IndexOf('local function render_casket_window()')
$configSection = $content.Substring($configStart, $windowStart - $configStart)
$windowSection = $content.Substring($windowStart)
if ($configSection -like '*ashitaguide_casket_reset*') {
    throw 'Casket reset must not be rendered in Guide Config.'
}
if ($windowSection -notlike '*ashitaguide_casket_reset*') {
    throw 'Casket reset must be rendered in the Casket Helper window.'
}

Write-Host 'ashitaguide validation passed.'
