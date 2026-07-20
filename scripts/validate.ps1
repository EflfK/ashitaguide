$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitaguiide.lua'
$config = Join-Path $root 'ashitaguiide_config.lua'

if (-not (Test-Path -LiteralPath $addon)) {
    throw "Missing addon file: $addon"
}

if (-not (Test-Path -LiteralPath $config)) {
    throw "Missing config file: $config"
}

$content = Get-Content -LiteralPath $addon -Raw

$required = @(
    "addon.name    = 'ashitaguiide'",
    "ashita.events.register('d3d_present'",
    "ashita.events.register('command'",
    "ashita.events.register('text_in'",
    "pages_of_valor",
    "activation_evidence",
    "capture_pov_transcript",
    "extract_designated_progress",
    "active_regime",
    "AshitaGuiideValor",
    "render_valor_config",
    "guide_hide_frame",
    "guide_show_step_list",
    "valor_hide_frame",
    "guide_is_configurable",
    "BeginTabBar",
    "AshitaGuiideConfig",
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

Write-Host 'ashitaguiide validation passed.'
