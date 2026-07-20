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
    "guide_hide_frame",
    "frameless_tab",
    "pop_window_style",
    "guide_show_step_list",
    "guide_map_size",
    "navigation_context",
    "config_dir_path",
    "bootstrap_persistent_config",
    "settings.lua",
    "save_settings_if_needed",
    "capture_window_geometry",
    "valor_hide_frame",
    "casket_enabled",
    "casket_hide_frame",
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
    "BeginTabBar",
    "AshitaGuideConfig",
    "tab_open",
    "AddTriangleFilled",
    "world_to_screen",
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

Write-Host 'ashitaguide validation passed.'
