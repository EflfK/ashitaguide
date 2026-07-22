-- Bundled template. On first load this file is copied to:
-- Ashita/config/addons/ashitaguide/ashitaguide_config.lua
-- Edit the persistent copy so custom guides survive addon reinstalls.
return {
    settings = {
        visible = true,
        window_x = 420,
        window_y = 160,
        -- window_x/window_y identify this corner of the auto-sized Guides window.
        -- Valid values: top_left, top_right, bottom_left, bottom_right.
        guide_anchor_corner = 'top_left',
        guide_show_step_list = true,
        guide_map_size = 160,
        minimap_marker_enabled = true,
        guide_opacity = 92,
        decision_enabled = true,
        decision_anchor_corner = 'top_left',
        decision_window_x = 80,
        decision_window_y = 180,
        decision_opacity = 96,
        config_visible = true,
        config_window_x = 110,
        config_window_y = 160,
        config_window_width = 300,
        config_window_height = 520,
        valor_enabled = true,
        valor_show_zone = true,
        valor_show_totals = true,
        valor_opacity = 92,
        valor_window_x = 990,
        valor_window_y = 160,
        valor_window_width = 300,
        valor_window_height = 110,
        casket_enabled = true,
        casket_opacity = 92,
        casket_window_x = 990,
        casket_window_y = 290,
        casket_window_width = 430,
        casket_window_height = 360,
        casket_stale_seconds = 210,
        auction_sale_enabled = true,
        auction_sale_show_price_basis = true,
        auction_sale_show_observed_at = true,
        chat_log_seed_lines = 700,
        poll_chat_log = true,
        default_active_guides = { 'lower_jeuno_example' },
    },

    -- Built-ins are added by the addon unless disable_builtins = true.
    -- Add your own guides here. Categories are free-form and become filter
    -- options in the guide picker.
    guides = {
        {
            key = 'lower_jeuno_example',
            name = 'Find Mendi',
            categories = { 'Quest', 'Jeuno', 'Testing' },
            description = 'A short Lower Jeuno guide with live directional navigation.',
            steps = {
                {
                    title = 'Find Mendi',
                    text = 'Go to Mendi in Lower Jeuno.',
                    zone = 'Lower Jeuno',
                    location = 'H-8',
                    npc = 'Mendi',
                    target_x = -59.961,
                    target_y = -75.649,
                    advance_on_target = true,
                },
                {
                    title = 'Talk to Mendi',
                    text = 'Talk to Mendi.',
                    zone = 'Lower Jeuno',
                    location = 'H-8',
                    npc = 'Mendi',
                    target_x = -59.961,
                    target_y = -75.649,
                },
            },
        },
    },
};
