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
    "navigation_context",
    "navigation_world_radius",
    "config_dir_path",
    "bootstrap_persistent_config",
    "settings.lua",
    "save_settings_if_needed",
    "capture_window_geometry",
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
    "BeginTabBar",
    "AshitaGuideConfig",
    "tab_open",
    "AddTriangleFilled",
    "world_to_screen",
    "truthy",
    "advance_on_target",
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

if ($content -notmatch "guide\.origin ~= 'ai'") {
    throw 'Temporary AI guides are not separated from the normal guide picker.'
}

if ($content -notmatch "local sub_active = truthy\(safe_read\(function \(\) return target:GetIsSubTargetActive\(\); end, false\)\)") {
    throw 'Target selection must normalize AshitaCore numeric boolean values.'
}

if ($content -notmatch "local function navigation_world_radius\(distance\)\s+return math\.max\(5, distance \+ 5\);\s+end") {
    throw 'Navigation map must zoom smoothly with a five-yalm framing margin.'
}

if ($content -notmatch "Map radius: %.1f yalms") {
    throw 'Navigation map must display its active zoom radius.'
}

Write-Host 'ashitaguide validation passed.'
