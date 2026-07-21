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
    "MAP_TABLE_SIGNATURE",
    "square-minimal",
    "navigation_context",
    "navigation_world_radius",
    "config_dir_path",
    "bootstrap_persistent_config",
    "settings.lua",
    "save_settings_if_needed",
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
    "world_to_screen",
    "truthy",
    "advance_on_target",
    "update_level_step_auto_advance",
    "minimum_level",
    "required_job",
    "GetMainJobLevel",
    "target_x",
    "Progress"
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

if ($content -notmatch "for _, key in ipairs\(close_keys\) do\s+close_guide_tab\(key\)") {
    throw 'Guide tab close controls do not use the lifecycle-aware close handler.'
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

if ($content -notmatch "(?s)local function render_guide_window\(\).+window_no_resize.+window_no_scrollbar.+window_always_auto_resize") {
    throw 'Guides window must auto-size without resize handles or scrollbars.'
}

if ($content -notmatch "PushTextWrapPos\(math\.max\(cursor_x \+ 1, GUIDE_TEXT_WRAP_POS_X\)\)") {
    throw 'Guide text must use a stable maximum wrap width during auto-resize.'
}

if ($content -notmatch "SetNextWindowSizeConstraints\(\{ 0, 0 \}, \{ GUIDE_WINDOW_MAX_WIDTH, 10000 \}\)") {
    throw 'Guides window must enforce its auto-fit width ceiling before Begin.'
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
