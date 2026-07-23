$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitaguide.lua'
$config = Join-Path $root 'ashitaguide_config.lua'

if (-not (Test-Path -LiteralPath $addon)) {
    throw "Missing addon file: $addon"
}

if (-not (Test-Path -LiteralPath $config)) {
    throw "Missing config file: $config"
}

$content = Get-Content -LiteralPath $addon -Raw

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
    "guide_map_size",
    "minimap_marker_enabled",
    "render_minimap_destination_marker",
    "MINIMAP_RUNTIME_SIGNATURE",
    "map_scale_raw",
    "current_map_id",
    "map_id",
    "square-minimal",
    "navigation_context",
    "navigation_target_live_refresh_seconds",
    "navigation_target_miss_retry_seconds",
    "navigation_target_fallback_scan_distance",
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

foreach ($needle in $required) {
    if ($content -notlike "*$needle*") {
        throw "Missing expected surface: $needle"
    }
}

$blocked = @(
    'QueueCommand',
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
    $content -notmatch "navigation_target_fallback_scan_distance = 100\.0") {
    throw 'Navigation target lookup throttles do not match the documented limits.'
}

if ($content -notmatch "(?s)fallback_distance > state\.navigation_target_fallback_scan_distance.+return nil") {
    throw 'Fallback coordinates must distance-gate live NPC entity scans.'
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

if ($content -notmatch "(?s)step\.map_id ~= nil.+minimap\.current_map_id ~= step\.map_id.+Minimap marker hidden") {
    throw 'Minimap markers must be hidden when a step targets another map or floor.'
}

if ($content -notmatch "(?s)local function render_guide_window\(\).+window_no_resize.+window_no_scrollbar.+window_always_auto_resize") {
    throw 'Guides window must auto-size without resize handles or scrollbars.'
}

if ($content -notmatch "(?s)local function set_next_guide_window_position\(width, height\).+SetNextWindowPos\(\{ window_x, window_y \}, IMGUI\.cond_first_use\)") {
    throw 'Guides window must remain draggable after applying its initial configured position.'
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
