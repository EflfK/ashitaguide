addon.name    = 'ashitaguide';
addon.author  = 'EflfK';
addon.version = '0.20.5';
addon.desc    = 'Manual configuration-driven quest and page guide helper for Ashita.';

require('common');

local chat  = require('chat');
local imgui = require('imgui');
local d3d8  = require('d3d8');
local decision = { ffi = require('ffi') };
local d3d8_device = d3d8.get_device();

pcall(decision.ffi.cdef, 'void* __stdcall GetCurrentProcess(void);');
pcall(decision.ffi.cdef, 'int __stdcall ReadProcessMemory(void*, const void*, void*, unsigned long, unsigned long*);');

decision.process_handle = decision.ffi.C.GetCurrentProcess();

function decision.guarded_read_bytes(address, size)
    address = tonumber(address) or 0;
    size = tonumber(size) or 0;
    if (address <= 0 or size <= 0 or size > 4096) then
        return nil;
    end

    local buffer = decision.ffi.new('uint8_t[?]', size);
    local bytes_read = decision.ffi.new('unsigned long[1]', 0);
    local ok, result = pcall(function ()
        return decision.ffi.C.ReadProcessMemory(
            decision.process_handle,
            decision.ffi.cast('const void*', address),
            buffer,
            size,
            bytes_read);
    end);
    if (not ok or result == 0 or tonumber(bytes_read[0]) ~= size) then
        return nil;
    end

    return buffer;
end

function decision.read_uint8(address)
    local bytes = decision.guarded_read_bytes(address, 1);
    return bytes ~= nil and tonumber(bytes[0]) or nil;
end

function decision.read_uint16(address)
    local bytes = decision.guarded_read_bytes(address, 2);
    if (bytes == nil) then
        return nil;
    end
    return tonumber(bytes[0]) + (tonumber(bytes[1]) * 0x100);
end

function decision.read_uint32(address)
    local bytes = decision.guarded_read_bytes(address, 4);
    if (bytes == nil) then
        return nil;
    end
    return tonumber(bytes[0])
        + (tonumber(bytes[1]) * 0x100)
        + (tonumber(bytes[2]) * 0x10000)
        + (tonumber(bytes[3]) * 0x1000000);
end

function decision.read_string(address, size)
    local bytes = decision.guarded_read_bytes(address, size);
    if (bytes == nil) then
        return nil;
    end

    local characters = {};
    for index = 0, size - 1 do
        local value = tonumber(bytes[index]);
        if (value == 0) then
            break;
        end
        characters[#characters + 1] = string.char(value);
    end
    return table.concat(characters);
end

function decision.menu_uint8(address)
    return decision.read_uint8(address) or 0;
end

function decision.menu_uint16(address)
    return decision.read_uint16(address) or 0;
end

function decision.menu_uint32(address)
    return decision.read_uint32(address) or 0;
end

function decision.menu_string(address, size)
    return decision.read_string(address, size) or '';
end

local function imgui_const(name)
    return rawget(_G, name) or 0;
end

local IMGUI = {
    col_window_bg = imgui_const('ImGuiCol_WindowBg'),
    col_child_bg = imgui_const('ImGuiCol_ChildBg'),
    col_border = imgui_const('ImGuiCol_Border'),
    col_button = imgui_const('ImGuiCol_Button'),
    col_button_hovered = imgui_const('ImGuiCol_ButtonHovered'),
    col_button_active = imgui_const('ImGuiCol_ButtonActive'),
    col_text = imgui_const('ImGuiCol_Text'),
    col_header = imgui_const('ImGuiCol_Header'),
    col_header_hovered = imgui_const('ImGuiCol_HeaderHovered'),
    col_header_active = imgui_const('ImGuiCol_HeaderActive'),
    style_window_padding = imgui_const('ImGuiStyleVar_WindowPadding'),
    style_window_border_size = imgui_const('ImGuiStyleVar_WindowBorderSize'),
    style_frame_padding = imgui_const('ImGuiStyleVar_FramePadding'),
    cond_first_use = imgui_const('ImGuiCond_FirstUseEver'),
    window_no_collapse = imgui_const('ImGuiWindowFlags_NoCollapse'),
    window_no_title_bar = imgui_const('ImGuiWindowFlags_NoTitleBar'),
    window_no_resize = imgui_const('ImGuiWindowFlags_NoResize'),
    window_no_move = imgui_const('ImGuiWindowFlags_NoMove'),
    window_no_scrollbar = imgui_const('ImGuiWindowFlags_NoScrollbar'),
    window_no_scroll_with_mouse = imgui_const('ImGuiWindowFlags_NoScrollWithMouse'),
    window_always_auto_resize = imgui_const('ImGuiWindowFlags_AlwaysAutoResize'),
    window_no_saved_settings = imgui_const('ImGuiWindowFlags_NoSavedSettings'),
    window_no_inputs = imgui_const('ImGuiWindowFlags_NoInputs'),
    window_no_background = imgui_const('ImGuiWindowFlags_NoBackground'),
    draw_corner_all = imgui_const('ImDrawCornerFlags_All'),
};

local COLORS = {
    panel_bg = { 0.030, 0.034, 0.040, 0.92 },
    child_bg = { 0.015, 0.018, 0.022, 0.72 },
    border = { 0.28, 0.32, 0.36, 0.88 },
    display_bg = { 0.000, 0.000, 0.000, 0.74 },
    display_child_bg = { 0.000, 0.000, 0.000, 0.00 },
    display_border = { 0.28, 0.28, 0.30, 0.78 },
    header = { 0.92, 0.82, 0.52, 1.00 },
    accent = { 0.42, 0.82, 0.68, 1.00 },
    muted = { 0.62, 0.65, 0.70, 1.00 },
    warning = { 1.00, 0.66, 0.36, 1.00 },
    error = { 1.00, 0.38, 0.34, 1.00 },
    decision_selected = { 0.45, 0.92, 1.00, 1.00 },
    decision_recommended = { 1.00, 0.78, 0.30, 1.00 },
    decision_normal = { 0.91, 0.93, 0.97, 1.00 },
    casket_best = { 0.18, 0.86, 0.34, 0.94 },
    casket_best_hover = { 0.28, 0.96, 0.44, 1.00 },
    casket_possible = { 0.92, 0.74, 0.18, 0.88 },
    casket_possible_hover = { 1.00, 0.84, 0.26, 0.96 },
    casket_impossible = { 0.07, 0.07, 0.07, 0.26 },
    casket_impossible_hover = { 0.10, 0.10, 0.10, 0.34 },
    casket_dark_text = { 0.02, 0.02, 0.02, 1.00 },
    tab = { 0.015, 0.015, 0.018, 0.86 },
    tab_hover = { 0.095, 0.095, 0.105, 0.92 },
    tab_active = { 0.165, 0.165, 0.180, 0.98 },
    tab_text = { 0.78, 0.78, 0.82, 1.00 },
    tab_text_active = { 0.98, 0.98, 1.00, 1.00 },
};

local GUIDE_ANCHOR_CORNERS = {
    { key = 'top_left', label = 'Top left' },
    { key = 'top_right', label = 'Top right' },
    { key = 'bottom_left', label = 'Bottom left' },
    { key = 'bottom_right', label = 'Bottom right' },
};

local GUIDE_WINDOW_MAX_WIDTH = 560;
local GUIDE_TEXT_WRAP_POS_X = GUIDE_WINDOW_MAX_WIDTH - 12;

local DEFAULT_SETTINGS = {
    visible = true,
    window_x = 420,
    window_y = 160,
    guide_anchor_corner = 'top_left',
    guide_show_step_list = true,
    guide_map_size = 160,
    minimap_marker_enabled = true,
    guide_opacity = 92,
    decision_enabled = true,
    decision_hide_native_chat = true,
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
    default_active_guides = {},
    guide_steps = {},
};

local JOB_NAMES = {
    [1] = 'WAR',
    [2] = 'MNK',
    [3] = 'WHM',
    [4] = 'BLM',
    [5] = 'RDM',
    [6] = 'THF',
    [7] = 'PLD',
    [8] = 'DRK',
    [9] = 'BST',
    [10] = 'BRD',
    [11] = 'RNG',
    [12] = 'SAM',
    [13] = 'NIN',
    [14] = 'DRG',
    [15] = 'SMN',
    [16] = 'BLU',
    [17] = 'COR',
    [18] = 'PUP',
    [19] = 'DNC',
    [20] = 'SCH',
    [21] = 'GEO',
    [22] = 'RUN',
};

local JOB_ALIASES = {
    WARRIOR = 'WAR', MONK = 'MNK', WHITEMAGE = 'WHM', BLACKMAGE = 'BLM',
    REDMAGE = 'RDM', THIEF = 'THF', PALADIN = 'PLD', DARKKNIGHT = 'DRK',
    BEASTMASTER = 'BST', BARD = 'BRD', RANGER = 'RNG', SAMURAI = 'SAM',
    NINJA = 'NIN', DRAGOON = 'DRG', SUMMONER = 'SMN', BLUEMAGE = 'BLU',
    CORSAIR = 'COR', PUPPETMASTER = 'PUP', DANCER = 'DNC', SCHOLAR = 'SCH',
    GEOMANCER = 'GEO', RUNEFENCER = 'RUN',
};

local commands = {
    ['/agguide'] = true,
    ['/ashitaguide'] = true,
};

local PLAYER_CHAT_MODES = {
    [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true,
    [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true,
    [14] = true, [205] = true, [210] = true, [212] = true, [213] = true,
    [214] = true, [217] = true, [220] = true, [222] = true,
};

local state = {
    visible = T{ true },
    config_visible = T{ true },
    valor_visible = T{ false },
    valor_enabled = T{ true },
    valor_show_zone = T{ true },
    valor_show_totals = T{ true },
    casket_visible = T{ false },
    casket_enabled = T{ true },
    guide_show_step_list = T{ true },
    guide_map_size = T{ 160 },
    minimap_marker_enabled = T{ true },
    guide_opacity = T{ 92 },
    decision_enabled = T{ true },
    decision_hide_native_chat = T{ true },
    decision_opacity = T{ 96 },
    valor_opacity = T{ 92 },
    casket_opacity = T{ 92 },
    casket_stale_seconds = T{ 210 },
    settings = DEFAULT_SETTINGS,
    config_error = nil,
    guides = {},
    guide_by_key = {},
    categories = {},
    selected_guide_key = nil,
    selected_active_key = nil,
    category_filter = 'all',
    search_buffer = T{ '' },
    active = {},
    active_order = {},
    observed_log_path = nil,
    observed_log_position = 0,
    observed_log_last_check = 0,
    observed_text_events = 0,
    observed_log_events = 0,
    navigation_targets = {},
    navigation_target_live_refresh_seconds = 0.25,
    navigation_target_miss_retry_seconds = 5.0,
    navigation_target_fallback_scan_distance = 100.0,
    minimap = {
        settings = nil,
        settings_checked_at = 0,
        runtime_pointer_address = 0,
        reported_scale_zone = nil,
        reported_marker_step = nil,
    },
    pov_run = nil,
    pov_active = false,
    pov_recovery_pages = {
        {
            key = 'crawlers_nest_page_1',
            name = "Crawlers' Nest Page 1",
            number = 1,
            zone = "Crawlers' Nest",
            notes = 'Target level range: 40-44',
            targets = {
                { name = 'Worker Crawler', count = 3 },
                { name = 'Death Jacket', count = 3 },
            },
        },
    },
    casket = nil,
    settings_observed_text = nil,
    settings_saved_text = nil,
    settings_pending_at = 0,
    settings_last_poll = 0,
    settings_save_error = nil,
    pov_state_observed_text = nil,
    pov_state_saved_text = nil,
    pov_state_pending_at = 0,
    pov_state_last_poll = 0,
    pov_state_save_error = nil,
    pov_state_restore_pending = true,
    ai_guides = {},
    permanent_guides = {},
    ai_selected_key = nil,
    ai_editor_key = nil,
    ai_name_buffer = T{ '' },
    ai_categories_buffer = T{ '' },
    ai_description_buffer = T{ '' },
    ai_storage_error = nil,
    ai_observed_text = nil,
    ai_last_poll = 0,
    auction_sale_enabled = T{ true },
    auction_sale_show_price_basis = T{ true },
    auction_sale_show_observed_at = T{ true },
    auction_sale_guide = nil,
    auction_sale_storage_error = nil,
    auction_sale_observed_text = nil,
    auction_sale_last_poll = 0,
    decision_menu = nil,
    decision_menu_candidate = 0,
    decision_menu_stable_frames = 0,
    decision_menu_open = T{ true },
    decision_window_width = nil,
    decision_window_height = nil,
    native_chat_pointer_error = nil,
    native_chat_win_ptr1 = nil,
    native_chat_win_ptr2 = nil,
    guide_window_width = nil,
    guide_window_height = nil,
};

local function trim_string(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '');
end

local function clean_message(value)
    local text = tostring(value or ''):gsub('\r', ' '):gsub('\n', ' '):gsub('%z', '');
    text = text:gsub('.', function (character)
        local byte = character:byte();
        if (byte ~= nil and byte < 32 and byte ~= 9) then
            return '';
        end
        return character;
    end);
    return trim_string(text);
end

local function lower_string(value)
    return clean_message(value):lower();
end

local function path_join(left, right)
    left = tostring(left or '');
    right = tostring(right or '');
    if (left == '') then
        return right;
    end
    local last = left:sub(#left);
    if (last == '\\' or last == '/') then
        return left .. right;
    end
    return left .. '\\' .. right;
end

local function normalize_key(value, fallback)
    local text = trim_string(value);
    if (text == '') then
        text = trim_string(fallback);
    end
    text = text:lower():gsub('%s+', '_'):gsub('[^%w_%-%:]', '');
    if (text == '') then
        return 'guide';
    end
    return text;
end

local function bounded_number(value, default, min, max)
    local numeric = tonumber(value);
    if (numeric == nil) then
        numeric = default;
    end
    numeric = math.floor(numeric);
    if (numeric < min) then
        return min;
    end
    if (numeric > max) then
        return max;
    end
    return numeric;
end

local function bounded_boolean(value, default)
    if (type(value) == 'boolean') then
        return value;
    end
    return default;
end

local function normalize_guide_anchor_corner(value)
    local corner = trim_string(value):lower():gsub('[%s%-]+', '_');
    if (corner == 'top_left'
        or corner == 'top_right'
        or corner == 'bottom_left'
        or corner == 'bottom_right') then
        return corner;
    end
    return DEFAULT_SETTINGS.guide_anchor_corner;
end

local function guide_anchor_corner_label(value)
    local corner = normalize_guide_anchor_corner(value);
    for _, option in ipairs(GUIDE_ANCHOR_CORNERS) do
        if (option.key == corner) then
            return option.label;
        end
    end
    return GUIDE_ANCHOR_CORNERS[1].label;
end

local function set_guide_anchor_corner(value)
    local old_corner = normalize_guide_anchor_corner(state.settings.guide_anchor_corner);
    local new_corner = normalize_guide_anchor_corner(value);
    if (old_corner == new_corner) then
        return;
    end

    local width = tonumber(state.guide_window_width) or 0;
    local height = tonumber(state.guide_window_height) or 0;
    local top_left_x = state.settings.window_x
        - ((old_corner == 'top_right' or old_corner == 'bottom_right') and width or 0);
    local top_left_y = state.settings.window_y
        - ((old_corner == 'bottom_left' or old_corner == 'bottom_right') and height or 0);

    state.settings.guide_anchor_corner = new_corner;
    state.settings.window_x = bounded_number(
        top_left_x + ((new_corner == 'top_right' or new_corner == 'bottom_right') and width or 0),
        state.settings.window_x,
        0,
        10000);
    state.settings.window_y = bounded_number(
        top_left_y + ((new_corner == 'bottom_left' or new_corner == 'bottom_right') and height or 0),
        state.settings.window_y,
        0,
        10000);
end

function decision.normalize_anchor(value)
    local corner = trim_string(value):lower():gsub('[%s%-]+', '_');
    if (corner == 'top_left'
        or corner == 'top_right'
        or corner == 'bottom_left'
        or corner == 'bottom_right') then
        return corner;
    end
    return DEFAULT_SETTINGS.decision_anchor_corner;
end

function decision.anchor_label(value)
    local corner = decision.normalize_anchor(value);
    for _, option in ipairs(GUIDE_ANCHOR_CORNERS) do
        if (option.key == corner) then
            return option.label;
        end
    end
    return GUIDE_ANCHOR_CORNERS[1].label;
end

function decision.set_anchor(value)
    local old_corner = decision.normalize_anchor(state.settings.decision_anchor_corner);
    local new_corner = decision.normalize_anchor(value);
    if (old_corner == new_corner) then
        return;
    end

    local width = tonumber(state.decision_window_width) or 0;
    local height = tonumber(state.decision_window_height) or 0;
    local top_left_x = state.settings.decision_window_x
        - ((old_corner == 'top_right' or old_corner == 'bottom_right') and width or 0);
    local top_left_y = state.settings.decision_window_y
        - ((old_corner == 'bottom_left' or old_corner == 'bottom_right') and height or 0);

    state.settings.decision_anchor_corner = new_corner;
    state.settings.decision_window_x = bounded_number(
        top_left_x + ((new_corner == 'top_right' or new_corner == 'bottom_right') and width or 0),
        state.settings.decision_window_x,
        0,
        10000);
    state.settings.decision_window_y = bounded_number(
        top_left_y + ((new_corner == 'bottom_left' or new_corner == 'bottom_right') and height or 0),
        state.settings.decision_window_y,
        0,
        10000);
end

local function truthy(value)
    return value == true or value == 1;
end

local function copy_array(values)
    local output = {};
    if (type(values) ~= 'table') then
        return output;
    end
    for _, value in ipairs(values) do
        table.insert(output, value);
    end
    return output;
end

local function copy_step_map(values)
    local output = {};
    if (type(values) ~= 'table') then
        return output;
    end
    for key, value in pairs(values) do
        if (type(key) == 'string' and trim_string(key) ~= '' and tonumber(value) ~= nil) then
            output[key] = bounded_number(value, 1, 1, 100000);
        end
    end
    return output;
end

local function log_info(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function log_warn(message)
    print(chat.header(addon.name):append(chat.warning(message)));
end

local function text_wrapped(text)
    text = tostring(text or '');
    if (type(imgui.PushTextWrapPos) == 'function' and type(imgui.PopTextWrapPos) == 'function') then
        local cursor_x = type(imgui.GetCursorPosX) == 'function'
            and (tonumber(imgui.GetCursorPosX()) or 0)
            or 0;
        imgui.PushTextWrapPos(math.max(cursor_x + 1, GUIDE_TEXT_WRAP_POS_X));
        imgui.Text(text);
        imgui.PopTextWrapPos();
        return;
    end
    if (type(imgui.TextWrapped) == 'function') then
        imgui.TextWrapped(text);
    else
        imgui.Text(text);
    end
end

local function text_colored_wrapped(color, text)
    if (type(imgui.PushTextWrapPos) == 'function' and type(imgui.PopTextWrapPos) == 'function') then
        local cursor_x = type(imgui.GetCursorPosX) == 'function'
            and (tonumber(imgui.GetCursorPosX()) or 0)
            or 0;
        imgui.PushTextWrapPos(math.max(cursor_x + 1, GUIDE_TEXT_WRAP_POS_X));
        imgui.TextColored(color, tostring(text or ''));
        imgui.PopTextWrapPos();
        return;
    end
    imgui.TextColored(color, tostring(text or ''));
end

local function centered_text_colored(color, value)
    local text = clean_message(value);
    if (type(imgui.GetWindowWidth) == 'function'
        and type(imgui.CalcTextSize) == 'function'
        and type(imgui.SetCursorPosX) == 'function') then
        local width = tonumber(imgui.GetWindowWidth()) or 0;
        local text_width = tonumber(imgui.CalcTextSize(text)) or 0;
        imgui.SetCursorPosX(math.max(8, (width - text_width) / 2));
    end
    imgui.TextColored(color, text);
end

local function begin_child(id, size, border)
    if (type(imgui.BeginChild) ~= 'function' or type(imgui.EndChild) ~= 'function') then
        return false, true;
    end
    local ok, result = pcall(imgui.BeginChild, id, size, border);
    if (not ok) then
        return false, true;
    end
    return true, result ~= false;
end

local function safe_read(callback, default)
    local ok, result = pcall(callback);
    if (ok) then
        return result;
    end
    return default;
end

state.current_character_name = function ()
    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    local party = memory ~= nil and safe_read(function () return memory:GetParty(); end, nil) or nil;
    local character = party ~= nil and clean_message(safe_read(function () return party:GetMemberName(0); end, '')) or '';
    return character ~= '' and character or nil;
end

state.current_zone_name = function ()
    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    local party = memory ~= nil and safe_read(function () return memory:GetParty(); end, nil) or nil;
    local zone_id = party ~= nil and tonumber(safe_read(function () return party:GetMemberZone(0); end, nil)) or nil;
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    local zone = resources ~= nil and zone_id ~= nil
        and clean_message(safe_read(function () return resources:GetString('zones.names', zone_id); end, ''))
        or '';
    return zone ~= '' and zone or nil;
end

local function current_chat_log_path()
    local character = state.current_character_name();
    if (character == nil) then return nil; end

    local install_path = clean_message(safe_read(function () return AshitaCore:GetInstallPath(); end, ''));
    if (install_path == '') then
        return nil;
    end

    return string.format('%schatlogs\\%s_%s.log', install_path, character, os.date('%Y.%m.%d'));
end

local function builtin_guides()
    return {
        {
            key = 'pages_of_valor',
            name = 'Pages of Valor',
            type = 'pages_of_valor',
            categories = { 'Built-in', 'Leveling', 'Pages of Valor' },
            steps = {
                {
                    text = 'Complete the active training regime.',
                },
            },
        },
    };
end

local function normalize_categories(source)
    local output = {};
    local seen = {};
    if (type(source) == 'table') then
        for _, value in ipairs(source) do
            local label = trim_string(value);
            local key = label:lower();
            if (label ~= '' and seen[key] ~= true) then
                seen[key] = true;
                table.insert(output, label);
            end
        end
    end
    if (#output == 0) then
        table.insert(output, 'Uncategorized');
    end
    return output;
end

local function normalize_required_job(value)
    local numeric = tonumber(value);
    if (numeric ~= nil and JOB_NAMES[math.floor(numeric)] ~= nil) then
        return JOB_NAMES[math.floor(numeric)];
    end

    local job = trim_string(value):upper():gsub('[^%w]', '');
    if (job == '') then
        return '';
    end
    return JOB_ALIASES[job] or job;
end

local function normalize_sale_items(source)
    local output = {};
    if (type(source) ~= 'table') then
        return output;
    end

    for _, item in ipairs(source) do
        if (type(item) == 'table') then
            local name = trim_string(item.name);
            local quantity_owned = bounded_number(item.quantity_owned, 1, 1, 9999);
            local listing_quantity = bounded_number(item.listing_quantity, 1, 1, 9999);
            local suggested_price_gil = bounded_number(item.suggested_price_gil, 1, 1, 999999999);
            if (name ~= '') then
                table.insert(output, {
                    name = name,
                    item_id = tonumber(item.item_id),
                    quantity_owned = quantity_owned,
                    listing_quantity = listing_quantity,
                    suggested_price_gil = suggested_price_gil,
                    price_basis = trim_string(item.price_basis),
                    observed_at = trim_string(item.observed_at),
                    note = trim_string(item.note),
                });
            end
        end
    end
    return output;
end

local function normalize_step(source, index)
    if (type(source) == 'string') then
        source = { text = source };
    end
    source = type(source) == 'table' and source or {};

    local title = trim_string(source.title);
    local text = trim_string(source.text or source.instruction or source.action);
    if (text == '') then
        text = string.format('Step %d', index);
    end

    local minimum_level = tonumber(source.minimum_level or source.min_level);
    if (minimum_level ~= nil) then
        minimum_level = bounded_number(minimum_level, 1, 1, 99);
    end

    return {
        title = title,
        text = text,
        zone = trim_string(source.zone),
        location = trim_string(source.location or source.position or source.coords),
        npc = trim_string(source.npc),
        answer = trim_string(source.answer or source.response),
        note = trim_string(source.note or source.notes),
        target_x = tonumber(source.target_x or source.x),
        target_y = tonumber(source.target_y or source.y),
        minimum_level = minimum_level,
        required_job = normalize_required_job(source.required_job or source.job),
        advance_on_target = bounded_boolean(
            source.advance_on_target or source.auto_advance_on_target,
            false),
        advance_on_text = trim_string(source.advance_on_text),
        sale_items = normalize_sale_items(source.sale_items or source.items),
    };
end

function decision.is_pointer(value)
    return value >= 0x00010000 and value < 0x80000000;
end

function decision.active_state()
    local pointer_manager = AshitaCore:GetPointerManager();
    if (pointer_manager == nil) then
        return '', 0;
    end

    local root = tonumber(pointer_manager:Get('menu')) or 0;
    if (root == 0) then
        return '', 0;
    end

    local holder = decision.menu_uint32(root);
    local object = holder ~= 0 and decision.menu_uint32(holder) or 0;
    if (object == 0) then
        return '', 0;
    end

    local header = decision.menu_uint32(object + 0x04);
    if (header == 0) then
        return '', object;
    end

    local name = decision.menu_string(header + 0x46, 16)
        :gsub('\x00', '')
        :gsub('^%s+', '')
        :gsub('%s+$', '');
    return name, object;
end

function decision.decode_text(pointer, byte_count)
    if (pointer == 0) then
        return '';
    end

    local characters = {};
    local started = false;
    local zero_count = 0;
    local first_character = true;
    for offset = 0, byte_count - 2, 2 do
        local value = decision.menu_uint16(pointer + offset);
        if (value >= 32 and value <= 126) then
            local character = string.char(value);
            local previous = characters[#characters];
            local shifted_uppercase = value >= 0x21 and value <= 0x3A
                and value ~= 0x27
                and value ~= 0x2D
                and (first_character
                    or (value == 0x2F and previous == "'")
                    or (value == 0x2C and previous == ' '));
            if (shifted_uppercase) then
                character = string.char(value + 0x20);
            end
            characters[#characters + 1] = character;
            started = true;
            zero_count = 0;
            first_character = false;
        elseif (value == 0) then
            zero_count = zero_count + 1;
            if (started and zero_count >= 4) then
                break;
            end
            if (started and characters[#characters] ~= ' ') then
                characters[#characters + 1] = ' ';
            end
        elseif (started and value > 0 and value < 0x20) then
            local character = string.char(value + 0x20);
            characters[#characters + 1] = character;
            zero_count = 0;
            if (character == '.' or character == '?' or character == '!') then
                break;
            end
        end
    end

    return trim_string(table.concat(characters):gsub('%s+', ' '));
end

function decision.read_menu()
    local name, object = decision.active_state();
    if (object == 0 or name:lower():find('query', 1, true) == nil) then
        return nil;
    end

    local menu_data = decision.menu_uint32(object + 0x0C);
    if (menu_data == 0) then
        return nil;
    end

    local total = decision.menu_uint32(menu_data + 0x24);
    if (total < 1 or total > 64) then
        return nil;
    end

    local choices = {};
    local node = decision.menu_uint32(menu_data + 0x14);
    local visited = {};
    for index = 1, total do
        if (not decision.is_pointer(node) or visited[node] == true) then
            break;
        end
        visited[node] = true;
        local content = decision.menu_uint32(node + 0x10);
        local text = decision.decode_text(content, 256);
        choices[#choices + 1] = text ~= '' and text or string.format('Choice %d', index);
        node = decision.menu_uint32(node + 0x00);
    end
    if (#choices == 0) then
        return nil;
    end

    local final_name, final_object = decision.active_state();
    if (final_object ~= object or final_name:lower():find('query', 1, true) == nil) then
        return nil;
    end

    local selected = decision.menu_uint8(menu_data + 0x30) + 1;
    return {
        object = object,
        menu_data = menu_data,
        prompt = decision.decode_text(menu_data + 0x30, 256),
        choices = choices,
        selected = math.max(1, math.min(#choices, selected)),
    };
end

function decision.update()
    if (state.decision_enabled[1] ~= true) then
        state.decision_menu = nil;
        state.decision_menu_candidate = 0;
        state.decision_menu_stable_frames = 0;
        return;
    end

    local name, object = decision.active_state();
    if (object == 0 or name:lower():find('query', 1, true) == nil) then
        state.decision_menu = nil;
        state.decision_menu_candidate = 0;
        state.decision_menu_stable_frames = 0;
        return;
    end

    local current = state.decision_menu;
    if (current == nil or current.object ~= object) then
        if (state.decision_menu_candidate ~= object) then
            state.decision_menu_candidate = object;
            state.decision_menu_stable_frames = 1;
            return;
        end

        state.decision_menu_stable_frames = state.decision_menu_stable_frames + 1;
        if (state.decision_menu_stable_frames < 45) then
            return;
        end

        local captured = decision.read_menu();
        state.decision_menu_candidate = 0;
        state.decision_menu_stable_frames = 0;
        if (captured ~= nil) then
            state.decision_menu = captured;
            state.decision_menu_open[1] = true;
        end
        return;
    end

    local menu_data = decision.menu_uint32(object + 0x0C);
    if (menu_data == 0 or menu_data ~= current.menu_data) then
        state.decision_menu = nil;
        state.decision_menu_candidate = object;
        state.decision_menu_stable_frames = 1;
        return;
    end

    local selected = decision.menu_uint8(menu_data + 0x30) + 1;
    if (selected >= 1 and selected <= #current.choices) then
        current.selected = selected;
    end
end

function decision.find_legacy_chat_windows()
    state.native_chat_pointer_error = nil;
    state.native_chat_win_ptr1 = nil;
    state.native_chat_win_ptr2 = nil;

    local pattern = ashita.memory.find(
        'FFXiMain.dll',
        0,
        'A1????????C64059018B0D????????C6415901C20800',
        0,
        0);
    if (pattern == nil or pattern == 0) then
        state.native_chat_pointer_error = 'legacy chat window pattern not found';
        return false;
    end

    state.native_chat_win_ptr1 = ashita.memory.read_uint32(pattern + 0x01);
    state.native_chat_win_ptr2 = ashita.memory.read_uint32(pattern + 0x0B);

    if ((state.native_chat_win_ptr1 == nil or state.native_chat_win_ptr1 == 0)
        and (state.native_chat_win_ptr2 == nil or state.native_chat_win_ptr2 == 0)) then
        state.native_chat_pointer_error = 'legacy chat window pointers were empty';
        return false;
    end

    return true;
end

function decision.pin_legacy_chat_window(pointer_address)
    if (pointer_address == nil or pointer_address == 0) then
        return false;
    end

    local window = ashita.memory.read_uint32(pointer_address);
    if (window == nil or window == 0) then
        return false;
    end

    ashita.memory.unprotect(window + 0x34, 4);
    ashita.memory.write_uint32(window + 0x34, 0x00);
    return true;
end

function decision.pin_legacy_chat_closed()
    if (state.decision_enabled[1] ~= true or state.decision_hide_native_chat[1] ~= true) then
        return;
    end

    if (AshitaCore:GetChatManager():IsInputOpen() ~= 0x00) then
        return;
    end

    if (state.native_chat_win_ptr1 == nil
        and state.native_chat_win_ptr2 == nil
        and not decision.find_legacy_chat_windows()) then
        return;
    end

    decision.pin_legacy_chat_window(state.native_chat_win_ptr1);
    decision.pin_legacy_chat_window(state.native_chat_win_ptr2);
end

local function normalize_guide(source, index, origin)
    source = type(source) == 'table' and source or {};
    local name = trim_string(source.name or source.label);
    if (name == '') then
        name = string.format('Guide %d', index);
    end
    local key = normalize_key(source.key, name);

    local steps = {};
    if (type(source.steps) == 'table') then
        for step_index, step in ipairs(source.steps) do
            table.insert(steps, normalize_step(step, step_index));
        end
    end
    if (#steps == 0) then
        table.insert(steps, normalize_step({ text = 'No steps configured yet.' }, 1));
    end

    local guide = {
        key = key,
        name = name,
        type = trim_string(source.type) ~= '' and trim_string(source.type) or 'manual',
        description = trim_string(source.description),
        categories = normalize_categories(source.categories),
        steps = steps,
        origin = origin or 'config',
    };

    return guide;
end

local function normalize_settings(source)
    source = type(source) == 'table' and source or {};
    local legacy_opacity = bounded_number(source.opacity, DEFAULT_SETTINGS.guide_opacity, 0, 100);
    return {
        visible = bounded_boolean(source.visible, DEFAULT_SETTINGS.visible),
        window_x = bounded_number(source.window_x, DEFAULT_SETTINGS.window_x, 0, 10000),
        window_y = bounded_number(source.window_y, DEFAULT_SETTINGS.window_y, 0, 10000),
        guide_anchor_corner = normalize_guide_anchor_corner(source.guide_anchor_corner),
        guide_show_step_list = bounded_boolean(source.guide_show_step_list, DEFAULT_SETTINGS.guide_show_step_list),
        guide_map_size = bounded_number(source.guide_map_size, DEFAULT_SETTINGS.guide_map_size, 120, 260),
        minimap_marker_enabled = bounded_boolean(
            source.minimap_marker_enabled,
            DEFAULT_SETTINGS.minimap_marker_enabled),
        guide_opacity = bounded_number(source.guide_opacity, legacy_opacity, 0, 100),
        decision_enabled = bounded_boolean(source.decision_enabled, DEFAULT_SETTINGS.decision_enabled),
        decision_hide_native_chat = bounded_boolean(
            source.decision_hide_native_chat,
            DEFAULT_SETTINGS.decision_hide_native_chat),
        decision_anchor_corner = decision.normalize_anchor(source.decision_anchor_corner),
        decision_window_x = bounded_number(
            source.decision_window_x,
            DEFAULT_SETTINGS.decision_window_x,
            0,
            10000),
        decision_window_y = bounded_number(
            source.decision_window_y,
            DEFAULT_SETTINGS.decision_window_y,
            0,
            10000),
        decision_opacity = bounded_number(
            source.decision_opacity,
            DEFAULT_SETTINGS.decision_opacity,
            0,
            100),
        config_visible = bounded_boolean(source.config_visible, DEFAULT_SETTINGS.config_visible),
        config_window_x = bounded_number(source.config_window_x, DEFAULT_SETTINGS.config_window_x, 0, 10000),
        config_window_y = bounded_number(source.config_window_y, DEFAULT_SETTINGS.config_window_y, 0, 10000),
        config_window_width = bounded_number(source.config_window_width, DEFAULT_SETTINGS.config_window_width, 260, 600),
        config_window_height = bounded_number(source.config_window_height, DEFAULT_SETTINGS.config_window_height, 320, 1000),
        valor_enabled = bounded_boolean(source.valor_enabled, DEFAULT_SETTINGS.valor_enabled),
        valor_show_zone = bounded_boolean(source.valor_show_zone, DEFAULT_SETTINGS.valor_show_zone),
        valor_show_totals = bounded_boolean(source.valor_show_totals, DEFAULT_SETTINGS.valor_show_totals),
        valor_opacity = bounded_number(source.valor_opacity, legacy_opacity, 0, 100),
        valor_window_x = bounded_number(source.valor_window_x, DEFAULT_SETTINGS.valor_window_x, 0, 10000),
        valor_window_y = bounded_number(source.valor_window_y, DEFAULT_SETTINGS.valor_window_y, 0, 10000),
        valor_window_width = bounded_number(source.valor_window_width, DEFAULT_SETTINGS.valor_window_width, 220, 600),
        valor_window_height = bounded_number(source.valor_window_height, DEFAULT_SETTINGS.valor_window_height, 80, 400),
        casket_enabled = bounded_boolean(source.casket_enabled, DEFAULT_SETTINGS.casket_enabled),
        casket_opacity = bounded_number(source.casket_opacity, legacy_opacity, 0, 100),
        casket_window_x = bounded_number(source.casket_window_x, DEFAULT_SETTINGS.casket_window_x, 0, 10000),
        casket_window_y = bounded_number(source.casket_window_y, DEFAULT_SETTINGS.casket_window_y, 0, 10000),
        casket_window_width = bounded_number(source.casket_window_width, DEFAULT_SETTINGS.casket_window_width, 430, 900),
        casket_window_height = bounded_number(source.casket_window_height, DEFAULT_SETTINGS.casket_window_height, 280, 800),
        casket_stale_seconds = bounded_number(source.casket_stale_seconds, DEFAULT_SETTINGS.casket_stale_seconds, 0, 900),
        auction_sale_enabled = bounded_boolean(source.auction_sale_enabled, DEFAULT_SETTINGS.auction_sale_enabled),
        auction_sale_show_price_basis = bounded_boolean(
            source.auction_sale_show_price_basis,
            DEFAULT_SETTINGS.auction_sale_show_price_basis),
        auction_sale_show_observed_at = bounded_boolean(
            source.auction_sale_show_observed_at,
            DEFAULT_SETTINGS.auction_sale_show_observed_at),
        chat_log_seed_lines = bounded_number(source.chat_log_seed_lines, DEFAULT_SETTINGS.chat_log_seed_lines, 0, 5000),
        poll_chat_log = bounded_boolean(source.poll_chat_log, DEFAULT_SETTINGS.poll_chat_log),
        default_active_guides = copy_array(source.default_active_guides or DEFAULT_SETTINGS.default_active_guides),
        guide_steps = copy_step_map(source.guide_steps or DEFAULT_SETTINGS.guide_steps),
    };
end

local function guide_is_configurable(guide)
    return guide ~= nil
        and guide.type ~= 'pages_of_valor'
        and guide.origin ~= 'ai'
        and guide.origin ~= 'auction_sale';
end

local function category_catalog(guides)
    local output = { { key = 'all', label = 'All Categories' } };
    local seen = { all = true };
    for _, guide in ipairs(guides) do
        if (guide_is_configurable(guide)) then
            for _, label in ipairs(guide.categories) do
                local key = normalize_key(label, label);
                if (seen[key] ~= true) then
                    seen[key] = true;
                    table.insert(output, { key = key, label = label });
                end
            end
        end
    end
    return output;
end

local function page_total(page)
    if (page == nil) then
        return 0;
    end
    if (tonumber(page.total) ~= nil and page.total > 0) then
        return page.total;
    end
    local total = 0;
    for _, target in ipairs(page.targets or {}) do
        total = total + (tonumber(target.count) or 0);
    end
    return total;
end

local function new_pov_state()
    return {
        zone = nil,
        progress = 0,
        total = 0,
        completed = false,
        completion_count = 0,
        cycle = 1,
        last_defeated_name = nil,
        last_defeated_time = 0,
        runtime_page = nil,
        pending = {
            capturing = false,
            targets = {},
            target_by_name = {},
            zone = '',
            level_range = '',
        },
    };
end

local function casket_all_candidates()
    local values = {};
    for value = 10, 99 do
        table.insert(values, value);
    end
    return values;
end

local function new_casket_state()
    return {
        active = false,
        candidates = casket_all_candidates(),
        clues = {},
        started_at = 0,
        updated_at = 0,
        last_event = nil,
        last_result = nil,
        last_clue_signature = nil,
        last_clue_observed_at = 0,
    };
end

local function reset_casket_state(now)
    state.casket = new_casket_state();
    state.casket.active = true;
    state.casket.started_at = now or os.clock();
    state.casket.updated_at = now or os.clock();
    state.casket.last_event = nil;
    state.casket.last_result = nil;
    return state.casket;
end

local function casket_copy_candidates(candidates)
    local copy = {};
    for _, value in ipairs(candidates or {}) do
        table.insert(copy, value);
    end
    table.sort(copy);
    return copy;
end

local function casket_tens(value)
    return math.floor(value / 10);
end

local function casket_ones(value)
    return value % 10;
end

local function casket_extract_digits(text)
    local digits = {};
    local seen = {};
    for number in tostring(text or ''):gmatch('%f[%d](%d)%f[%D]') do
        local digit = tonumber(number);
        if (digit ~= nil and digit >= 0 and digit <= 9 and seen[digit] ~= true) then
            table.insert(digits, digit);
            seen[digit] = true;
        end
    end
    table.sort(digits);
    return digits;
end

local function casket_digit_set(digits)
    local set = {};
    for _, digit in ipairs(digits or {}) do
        set[digit] = true;
    end
    return set;
end

local function casket_parse_position_digit_event(lower, original)
    local position = nil;
    local phrase = nil;
    local first_start, first_end = lower:find('first%s+digit');
    local second_start, second_end = lower:find('second%s+digit');

    if (first_start ~= nil and (second_start == nil or first_start < second_start)) then
        position = 'first';
        phrase = lower:sub(first_end + 1);
    elseif (second_start ~= nil) then
        position = 'second';
        phrase = lower:sub(second_end + 1);
    else
        return nil;
    end

    if (phrase:find('even', 1, true) ~= nil) then
        return { kind = 'digit_parity', position = position, parity = 0, message = original };
    end
    if (phrase:find('odd', 1, true) ~= nil) then
        return { kind = 'digit_parity', position = position, parity = 1, message = original };
    end

    local digits = casket_extract_digits(phrase);
    if (#digits > 0) then
        return { kind = 'digit_set', position = position, digits = digits, message = original };
    end

    return nil;
end

local function casket_parse_any_digit_event(lower, original)
    local patterns = {
        'one%s+of%s+the%s+two%s+digits%s+is%s+an%s+(%d)',
        'one%s+of%s+the%s+two%s+digits%s+is%s+a%s+(%d)',
        'one%s+of%s+the%s+two%s+digits%s+is%s+(%d)',
        'one%s+of%s+the%s+digits%s+is%s+an%s+(%d)',
        'one%s+of%s+the%s+digits%s+is%s+a%s+(%d)',
        'one%s+of%s+the%s+digits%s+is%s+(%d)',
        'one%s+digit%s+is%s+an%s+(%d)',
        'one%s+digit%s+is%s+a%s+(%d)',
        'one%s+digit%s+is%s+(%d)',
        'either%s+digit%s+is%s+an%s+(%d)',
        'either%s+digit%s+is%s+a%s+(%d)',
        'either%s+digit%s+is%s+(%d)',
    };

    for _, pattern in ipairs(patterns) do
        local digit = tonumber(lower:match(pattern));
        if (digit ~= nil and digit >= 0 and digit <= 9) then
            return { kind = 'any_digit', digit = digit, message = original };
        end
    end

    return nil;
end

local function casket_parse_range_event(lower, original)
    local low, high = lower:match('(%d+)%s*<%s*x%s*<%s*(%d+)');
    if (low == nil or high == nil) then
        low, high = lower:match('greater%s+than%s+(%d+).-less%s+than%s+(%d+)');
    end
    if (low == nil or high == nil) then
        low, high = lower:match('more%s+than%s+(%d+).-less%s+than%s+(%d+)');
    end
    if (low == nil or high == nil) then
        low, high = lower:match('between%s+(%d+)%s+and%s+(%d+)');
    end

    low = tonumber(low);
    high = tonumber(high);
    if (low == nil or high == nil) then
        return nil;
    end
    if (low > high) then
        low, high = high, low;
    end

    if (low == 10 and high == 99
        and (lower:find('two-digit', 1, true) ~= nil
            or lower:find('between 10 and 99', 1, true) ~= nil)) then
        return { kind = 'session', message = original };
    end

    return { kind = 'range', low = low, high = high, message = original };
end

local function casket_normalize_message(message)
    local text = clean_message(message);
    local lower = text:lower();
    local starts = {
        'you have a hunch',
        'it appears that you can enter',
        'you succeeded in opening the lock',
        'succeeded in opening the lock',
        'you failed to open the lock',
        'failed to open the lock',
        'you open the treasure casket',
        'the treasure casket opens',
        'the treasure casket disappears',
        'the lock breaks',
        'the chest is locked',
        'chest is locked',
        'the casket is locked',
        'casket is locked',
    };
    local first = nil;
    for _, phrase in ipairs(starts) do
        local position = lower:find(phrase, 1, true);
        if (position ~= nil and (first == nil or position < first)) then
            first = position;
        end
    end
    if (first ~= nil) then
        return trim_string(text:sub(first));
    end

    -- Chat-log copies carry timestamps and can contain a printable byte left
    -- behind by Ashita formatting. Remove all leading timestamp wrappers.
    local previous = nil;
    while (text ~= previous) do
        previous = text;
        text = trim_string(text:gsub('^.-%[%d%d:%d%d:%d%d%]%s*', '', 1));
    end
    return text;
end

local function casket_parse_message(message)
    local original = casket_normalize_message(message);
    if (original == '') then
        return nil;
    end

    local lower = original:lower();
    if (lower:find('succeeded in opening the lock', 1, true) ~= nil
        or lower:find('you open the treasure casket', 1, true) ~= nil
        or lower:find('the treasure casket opens', 1, true) ~= nil) then
        return { kind = 'opened', message = original };
    end

    if (lower:find('failed to open the lock', 1, true) ~= nil
        or lower:find('the lock breaks', 1, true) ~= nil
        or lower:find('the treasure casket disappears', 1, true) ~= nil) then
        return { kind = 'finished', message = original };
    end

    local event = casket_parse_range_event(lower, original);
    if (event ~= nil) then
        return event;
    end

    local value = tonumber(
        lower:match('combination%s+is%s+greater%s+than%s+(%d+)')
            or lower:match('greater%s+than%s+(%d+)')
            or lower:match('more%s+than%s+(%d+)'));
    if (value ~= nil) then
        return { kind = 'greater', value = value, message = original };
    end

    value = tonumber(
        lower:match('combination%s+is%s+less%s+than%s+(%d+)')
            or lower:match('less%s+than%s+(%d+)'));
    if (value ~= nil) then
        return { kind = 'less', value = value, message = original };
    end

    event = casket_parse_position_digit_event(lower, original) or casket_parse_any_digit_event(lower, original);
    if (event ~= nil) then
        return event;
    end

    if (lower:find('chest is locked', 1, true) ~= nil
        or lower:find('casket is locked', 1, true) ~= nil
        or lower:find('two-digit combination between 10 and 99', 1, true) ~= nil) then
        return { kind = 'session', message = original };
    end

    return nil;
end

local function casket_is_player_chat(text, mode, alternate_mode)
    local normalized_mode = bit.band(tonumber(mode) or 0, 0x000000FF);
    local normalized_alternate_mode = bit.band(tonumber(alternate_mode) or 0, 0x000000FF);
    if (PLAYER_CHAT_MODES[normalized_mode] == true
        or PLAYER_CHAT_MODES[normalized_alternate_mode] == true) then
        return true;
    end

    -- Polled chat-log lines do not include event metadata, but player messages
    -- retain their early <Name> speaker tag after timestamps/channel markers.
    local prefix = clean_message(text):sub(1, 128);
    return prefix:find('<[^<>]+>%s') ~= nil;
end

local function casket_apply_event(casket, event)
    local filtered = {};
    local set = event.kind == 'digit_set' and casket_digit_set(event.digits) or nil;

    for _, candidate in ipairs(casket_copy_candidates(casket.candidates)) do
        local keep = true;
        if (event.kind == 'range') then
            keep = candidate > event.low and candidate < event.high;
        elseif (event.kind == 'greater') then
            keep = candidate > event.value;
        elseif (event.kind == 'less') then
            keep = candidate < event.value;
        elseif (event.kind == 'digit_parity') then
            local digit = event.position == 'first' and casket_tens(candidate) or casket_ones(candidate);
            keep = (digit % 2) == event.parity;
        elseif (event.kind == 'digit_set') then
            local digit = event.position == 'first' and casket_tens(candidate) or casket_ones(candidate);
            keep = set[digit] == true;
        elseif (event.kind == 'any_digit') then
            keep = casket_tens(candidate) == event.digit or casket_ones(candidate) == event.digit;
        end

        if (keep) then
            table.insert(filtered, candidate);
        end
    end

    casket.candidates = filtered;
end

local function casket_analyze(casket)
    local candidates = casket_copy_candidates(casket ~= nil and casket.candidates or {});
    local count = #candidates;
    if (count == 0) then
        return { count = 0, best = nil, less_count = 0, greater_count = 0, worst_after_miss = 0 };
    end

    local best_index = math.max(1, math.floor((count + 1) / 2));
    local best = candidates[best_index];
    local less_count = 0;
    local greater_count = 0;
    for _, candidate in ipairs(candidates) do
        if (candidate < best) then
            less_count = less_count + 1;
        elseif (candidate > best) then
            greater_count = greater_count + 1;
        end
    end

    return {
        count = count,
        best = best,
        less_count = less_count,
        greater_count = greater_count,
        worst_after_miss = math.max(less_count, greater_count),
    };
end

local function casket_is_stale(casket, now)
    if (casket == nil or casket.active ~= true) then
        return true;
    end
    local stale_seconds = tonumber(state.casket_stale_seconds[1]) or DEFAULT_SETTINGS.casket_stale_seconds;
    if (stale_seconds <= 0) then
        return false;
    end
    return ((now or os.clock()) - (tonumber(casket.updated_at) or 0)) > stale_seconds;
end

local function process_casket_text(text, source, mode, alternate_mode)
    if (state.casket_enabled[1] ~= true or source == 'seed') then
        return false;
    end

    if (casket_is_player_chat(text, mode, alternate_mode)) then
        return false;
    end

    state.casket = state.casket or new_casket_state();

    local event = casket_parse_message(text);
    if (event == nil) then
        return false;
    end

    local now = os.clock();
    if (event.kind == 'session') then
        if (casket_is_stale(state.casket, now)) then
            reset_casket_state(now);
        end
        state.casket.active = true;
        state.casket.updated_at = now;
        state.casket.last_event = event;
        state.casket_visible[1] = true;
        return true;
    end

    if (event.kind == 'opened' or event.kind == 'finished') then
        state.casket.active = false;
        state.casket.updated_at = now;
        state.casket.last_event = event;
        state.casket.last_result = event.kind;
        state.casket_visible[1] = false;
        return true;
    end

    if (casket_is_stale(state.casket, now)) then
        reset_casket_state(now);
    end

    local observed_at = os.time();
    local clue_signature = event.kind .. ':' .. event.message:lower();
    if (state.casket.last_clue_signature == clue_signature
        and observed_at - (tonumber(state.casket.last_clue_observed_at) or 0) <= 2) then
        return true;
    end

    casket_apply_event(state.casket, event);
    state.casket.active = true;
    state.casket.updated_at = now;
    state.casket.last_event = event;
    state.casket.last_clue_signature = clue_signature;
    state.casket.last_clue_observed_at = observed_at;
    table.insert(state.casket.clues, event);
    state.casket_visible[1] = true;
    return true;
end

local function create_run(guide, previous)
    local run = previous or {};
    run.key = guide.key;
    run.guide = guide;
    run.tab_open = run.tab_open or T{ true };
    run.tab_open[1] = true;
    if (previous == nil and guide.type ~= 'pages_of_valor') then
        run.step_index = state.settings.guide_steps[guide.key];
    end
    run.step_index = bounded_number(run.step_index, 1, 1, #guide.steps);
    if (guide.type ~= 'pages_of_valor') then
        state.settings.guide_steps[guide.key] = run.step_index;
    end
    if (guide.type == 'pages_of_valor') then
        run.pov = run.pov or new_pov_state();
    else
        run.pov = nil;
    end
    return run;
end

local function active_index(key)
    for index, active_key in ipairs(state.active_order) do
        if (active_key == key) then
            return index;
        end
    end
    return nil;
end

local function start_guide(guide, previous)
    if (guide == nil) then
        return nil;
    end
    if (guide.type == 'pages_of_valor') then
        return state.pov_run;
    end
    if (state.active[guide.key] ~= nil) then
        state.selected_active_key = guide.key;
        return state.active[guide.key];
    end
    local run = create_run(guide, previous);
    state.active[guide.key] = run;
    table.insert(state.active_order, guide.key);
    state.selected_active_key = guide.key;
    return run;
end

local function stop_guide(key)
    if (state.active[key] == nil) then
        return;
    end
    state.active[key] = nil;
    local index = active_index(key);
    if (index ~= nil) then
        table.remove(state.active_order, index);
    end
    if (state.selected_active_key == key) then
        state.selected_active_key = state.active_order[1];
    end
end

local function find_guide(value)
    local text = trim_string(value);
    if (text == '') then
        return nil;
    end

    local index = tonumber(text);
    if (index ~= nil and state.guides[math.floor(index)] ~= nil) then
        return state.guides[math.floor(index)];
    end

    local key = normalize_key(text, text);
    if (state.guide_by_key[key] ~= nil) then
        return state.guide_by_key[key];
    end

    local lower = text:lower();
    for _, guide in ipairs(state.guides) do
        if (guide.name:lower() == lower) then
            return guide;
        end
    end

    return nil;
end

local function current_run(value)
    local guide = find_guide(value);
    if (guide ~= nil and state.active[guide.key] ~= nil) then
        return state.active[guide.key];
    end
    if (trim_string(value) ~= '') then
        return nil;
    end
    if (state.selected_active_key ~= nil) then
        return state.active[state.selected_active_key];
    end
    return state.active[state.active_order[1]];
end

local function next_step(run)
    if (run == nil) then
        return;
    end
    run.step_index = math.min(#run.guide.steps, (tonumber(run.step_index) or 1) + 1);
    if (run.guide.type ~= 'pages_of_valor') then
        state.settings.guide_steps[run.key] = run.step_index;
    end
end

local function previous_step(run)
    if (run == nil) then
        return;
    end
    run.step_index = math.max(1, (tonumber(run.step_index) or 1) - 1);
    if (run.guide.type ~= 'pages_of_valor') then
        state.settings.guide_steps[run.key] = run.step_index;
    end
end

local function ashita_install_path()
    local install_path = clean_message(safe_read(function () return AshitaCore:GetInstallPath(); end, ''));
    return install_path ~= '' and install_path or nil;
end

local function config_dir_path()
    local install_path = ashita_install_path();
    if (install_path == nil) then
        return nil;
    end
    return path_join(path_join(path_join(install_path, 'config'), 'addons'), addon.name);
end

local function bundled_config_file_path()
    return path_join(addon.path or '', 'ashitaguide_config.lua');
end

local function config_file_path()
    local dir = config_dir_path();
    return dir ~= nil and path_join(dir, 'ashitaguide_config.lua') or bundled_config_file_path();
end

local function settings_file_path()
    local dir = config_dir_path();
    return dir ~= nil and path_join(dir, 'settings.lua') or nil;
end

state.pov_state_file_path = function ()
    local dir = config_dir_path();
    local character = state.current_character_name();
    if (dir == nil or character == nil) then return nil; end
    local character_key = character:lower():gsub('[^%a%d_-]', '_');
    return path_join(dir, string.format('valor_state_%s.lua', character_key));
end

local function ai_guides_file_path()
    local dir = config_dir_path();
    return dir ~= nil and path_join(dir, 'ai_guides.lua') or nil;
end

local function permanent_guides_file_path()
    local dir = config_dir_path();
    return dir ~= nil and path_join(dir, 'permanent_guides.lua') or nil;
end

local function auction_sale_guide_file_path()
    local dir = config_dir_path();
    return dir ~= nil and path_join(dir, 'auction_sale_guide.lua') or nil;
end

local function file_exists(path)
    if (path == nil or path == '') then
        return false;
    end
    local file = io.open(path, 'rb');
    if (file == nil) then
        return false;
    end
    file:close();
    return true;
end

local function read_text_file(path)
    local file, error_message = io.open(path, 'rb');
    if (file == nil) then
        return nil, error_message;
    end
    local contents = file:read('*a');
    file:close();
    return contents, nil;
end

local function parse_ini(contents)
    local result = {};
    local section = '';
    for line in tostring(contents or ''):gmatch('[^\r\n]+') do
        local clean = trim_string(line:gsub('[;#].*$', ''));
        local next_section = clean:match('^%[([^%]]+)%]$');
        if (next_section ~= nil) then
            section = trim_string(next_section):lower();
        else
            local key, value = clean:match('^([^=]+)=(.*)$');
            if (key ~= nil) then
                result[section .. '.' .. trim_string(key):lower()] = trim_string(value);
            end
        end
    end
    return result;
end

local function minimap_file_path(...)
    local install_path = ashita_install_path();
    if (install_path == nil) then
        return nil;
    end
    local path = path_join(path_join(install_path, 'config'), 'minimap');
    for _, part in ipairs({ ... }) do
        path = path_join(path, part);
    end
    return path;
end

local function minimap_plugin_loaded()
    local manager = safe_read(function () return AshitaCore:GetPluginManager(); end, nil);
    if (manager == nil) then
        return false;
    end
    return truthy(safe_read(function () return manager:IsLoaded('Minimap'); end, false))
        or truthy(safe_read(function () return manager:IsLoaded('minimap'); end, false));
end

-- Minimap keeps command and mouse-wheel changes in its live plugin object.  Its
-- ini file is only a persisted fallback, so reading only that file makes an
-- overlay lag behind zoom, rotation, movement, and scale changes.
local MINIMAP_RUNTIME_SIGNATURE =
    'A1????????F30F104044C3CCCCCCCCCCA1????????F30F10402C';

local function initialize_minimap_runtime()
    if (state.minimap.runtime_pointer_address ~= 0) then
        return;
    end
    local signature = tonumber(safe_read(function ()
        return ashita.memory.find('Minimap.dll', 0, MINIMAP_RUNTIME_SIGNATURE, 0, 0);
    end, 0)) or 0;
    if (signature ~= 0) then
        state.minimap.runtime_pointer_address = tonumber(safe_read(function ()
            return ashita.memory.read_uint32(signature + 0x01);
        end, 0)) or 0;
    end
end

local function apply_live_minimap_settings(settings)
    initialize_minimap_runtime();
    local pointer_address = state.minimap.runtime_pointer_address;
    if (pointer_address == 0) then
        return settings;
    end
    local runtime = tonumber(safe_read(function ()
        return ashita.memory.read_uint32(pointer_address);
    end, 0)) or 0;
    if (runtime == 0) then
        return settings;
    end

    local x = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0x28);
    end, nil));
    local y = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0x2C);
    end, nil));
    local scale_x = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0x30);
    end, nil));
    local scale_y = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0x34);
    end, nil));
    local zoom = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0x44);
    end, nil));
    local rotate_map = tonumber(safe_read(function ()
        return ashita.memory.read_uint8(runtime + 0x4C);
    end, nil));
    local rotate_frame = tonumber(safe_read(function ()
        return ashita.memory.read_uint8(runtime + 0x4D);
    end, nil));
    local frame_width = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0xA4);
    end, nil));
    local frame_height = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0xA8);
    end, nil));
    local mask_width = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0xB0);
    end, nil));
    local mask_height = tonumber(safe_read(function ()
        return ashita.memory.read_float(runtime + 0xB4);
    end, nil));
    local map_info = tonumber(safe_read(function ()
        return ashita.memory.read_uint32(runtime + 0x14);
    end, 0)) or 0;
    local map_scale_raw = map_info ~= 0 and tonumber(safe_read(function ()
        return ashita.memory.read_uint8(map_info + 0x05);
    end, nil)) or nil;

    if (x ~= nil and math.abs(x) < 100000) then settings.x = x; end
    if (y ~= nil and math.abs(y) < 100000) then settings.y = y; end
    if (scale_x ~= nil and scale_x > 0 and scale_x < 100) then settings.scale_x = scale_x; end
    if (scale_y ~= nil and scale_y > 0 and scale_y < 100) then settings.scale_y = scale_y; end
    if (zoom ~= nil and zoom >= 0.1 and zoom <= 2.0) then settings.zoom = zoom; end
    if (rotate_map == 0 or rotate_map == 1) then settings.rotate_map = rotate_map == 1; end
    if (rotate_frame == 0 or rotate_frame == 1) then settings.rotate_frame = rotate_frame == 1; end
    if (frame_width ~= nil and frame_width > 0.01 and frame_width < 10000) then settings.frame_width = frame_width; end
    if (frame_height ~= nil and frame_height > 0.01 and frame_height < 10000) then settings.frame_height = frame_height; end
    if (mask_width ~= nil and mask_width > 0.01 and mask_width < 10000) then settings.mask_width = mask_width; end
    if (mask_height ~= nil and mask_height > 0.01 and mask_height < 10000) then settings.mask_height = mask_height; end
    if (map_scale_raw ~= nil and map_scale_raw > 0) then settings.map_scale_raw = map_scale_raw; end
    settings.runtime_address = runtime;
    return settings;
end

local function load_minimap_settings()
    local now = os.clock();
    if (state.minimap.settings ~= nil and now - state.minimap.settings_checked_at < 1.0) then
        return apply_live_minimap_settings(state.minimap.settings);
    end
    state.minimap.settings_checked_at = now;

    local settings_path = minimap_file_path('minimap.ini');
    local settings_text = settings_path ~= nil and read_text_file(settings_path) or nil;
    if (settings_text == nil) then
        state.minimap.settings = nil;
        return nil;
    end

    local values = parse_ini(settings_text);
    local theme = lower_string(values['theme.name']);
    if (theme ~= 'square-minimal') then
        state.minimap.settings = nil;
        return nil;
    end

    local theme_path = minimap_file_path('themes', theme, 'theme.ini');
    local theme_text = theme_path ~= nil and read_text_file(theme_path) or nil;
    local theme_values = parse_ini(theme_text or '');
    state.minimap.settings = {
        x = tonumber(values['main.x']) or 0,
        y = tonumber(values['main.y']) or 0,
        scale_x = tonumber(values['main.scale_x']) or 1,
        scale_y = tonumber(values['main.scale_y']) or 1,
        zoom = tonumber(values['main.zoom']) or 1,
        rotate_map = truthy(tonumber(values['main.rotate_map']) or 0),
        frame_width = tonumber(theme_values['frame.w']) or 248,
        frame_height = tonumber(theme_values['frame.h']) or 248,
        mask_width = tonumber(theme_values['mask.w']) or 210,
        mask_height = tonumber(theme_values['mask.h']) or 210,
    };
    return apply_live_minimap_settings(state.minimap.settings);
end

local function write_text_file(path, contents)
    local file, error_message = io.open(path, 'wb');
    if (file == nil) then
        return false, error_message;
    end
    local ok, write_error = file:write(contents);
    file:close();
    if (not ok) then
        return false, write_error;
    end
    return true, nil;
end

local function ensure_config_dir()
    local install_path = ashita_install_path();
    if (install_path == nil) then
        return false, 'Ashita install path is unavailable.';
    end
    if (ashita == nil or ashita.fs == nil) then
        return false, 'Ashita filesystem helpers are unavailable.';
    end

    local config_root = path_join(install_path, 'config');
    local addons_root = path_join(config_root, 'addons');
    local addon_root = path_join(addons_root, addon.name);
    if (not ashita.fs.exists(config_root)) then
        ashita.fs.create_dir(config_root);
    end
    if (not ashita.fs.exists(addons_root)) then
        ashita.fs.create_dir(addons_root);
    end
    if (not ashita.fs.exists(addon_root)) then
        ashita.fs.create_dir(addon_root);
    end
    return true, addon_root;
end

local function bootstrap_persistent_config()
    local persistent_path = config_file_path();
    if (persistent_path == bundled_config_file_path() or file_exists(persistent_path)) then
        return persistent_path, nil;
    end

    local dir_ok, dir_or_error = ensure_config_dir();
    if (not dir_ok) then
        return bundled_config_file_path(), tostring(dir_or_error);
    end
    persistent_path = path_join(dir_or_error, 'ashitaguide_config.lua');
    local contents, read_error = read_text_file(bundled_config_file_path());
    if (contents == nil) then
        return bundled_config_file_path(), tostring(read_error or 'bundled config could not be read');
    end
    local write_ok, write_error = write_text_file(persistent_path, contents);
    if (not write_ok) then
        return bundled_config_file_path(), tostring(write_error or 'persistent config could not be created');
    end
    return persistent_path, nil;
end

local function load_raw_config()
    local path, bootstrap_error = bootstrap_persistent_config();
    local chunk, load_error = loadfile(path);
    if (chunk == nil) then
        return {}, tostring(load_error or 'config not found');
    end

    local ok, config = pcall(chunk);
    if (not ok or type(config) ~= 'table') then
        return {}, tostring(config or 'config did not return a table');
    end

    return config, bootstrap_error;
end

local function load_persisted_settings()
    local path = settings_file_path();
    if (not file_exists(path)) then
        return {}, nil;
    end
    local chunk, load_error = loadfile(path);
    if (chunk == nil) then
        return {}, tostring(load_error or 'settings could not be loaded');
    end
    local ok, values = pcall(chunk);
    if (not ok or type(values) ~= 'table') then
        return {}, tostring(values or 'settings did not return a table');
    end
    return values, nil;
end

local function load_persisted_guides(path, label)
    if (not file_exists(path)) then
        return {}, nil, '';
    end
    local contents = read_text_file(path);
    local chunk, load_error = loadfile(path);
    if (chunk == nil) then
        return {}, string.format('%s could not be loaded: %s', label, tostring(load_error or 'unknown error')), contents;
    end
    local ok, values = pcall(chunk);
    if (not ok or type(values) ~= 'table') then
        return {}, string.format('%s did not return a table: %s', label, tostring(values or 'unknown error')), contents;
    end
    if (type(values.guides) == 'table') then
        values = values.guides;
    end
    return values, nil, contents;
end

local function load_persisted_auction_sale()
    local path = auction_sale_guide_file_path();
    if (not file_exists(path)) then
        return nil, nil, '';
    end
    local contents = read_text_file(path) or '';
    local chunk, load_error = loadfile(path);
    if (chunk == nil) then
        return nil, string.format(
            'auction_sale_guide.lua could not be loaded: %s',
            tostring(load_error or 'unknown error')),
            contents;
    end
    local ok, values = pcall(chunk);
    if (not ok or type(values) ~= 'table') then
        return nil, string.format(
            'auction_sale_guide.lua did not return a table: %s',
            tostring(values or 'unknown error')),
            contents;
    end
    local source = type(values.guide) == 'table' and values.guide or values;
    if (type(source) ~= 'table') then
        return nil, 'auction_sale_guide.lua did not contain a guide.', contents;
    end
    return source, nil, contents;
end

local function lua_quoted(value)
    return string.format('%q', tostring(value or ''));
end

state.normalize_pov_runtime_page = function (source)
    if (type(source) ~= 'table') then return nil; end
    local targets = {};
    for _, candidate in ipairs(type(source.targets) == 'table' and source.targets or {}) do
        if (type(candidate) == 'table') then
            local name = trim_string(candidate.name);
            local count = bounded_number(candidate.count, 0, 0, 1000);
            if (name ~= '' and count > 0) then
                table.insert(targets, {
                    name = name,
                    count = count,
                    progress = bounded_number(candidate.progress, 0, 0, count),
                });
            end
        end
    end
    if (#targets == 0) then return nil; end
    return {
        key = trim_string(source.key) ~= '' and trim_string(source.key) or 'active_regime',
        name = trim_string(source.name) ~= '' and trim_string(source.name) or 'Active training regime',
        number = tonumber(source.number),
        zone = trim_string(source.zone),
        notes = trim_string(source.notes),
        targets = targets,
    };
end

state.load_persisted_pov_state = function ()
    local path = state.pov_state_file_path();
    if (not file_exists(path)) then return nil, nil; end
    local chunk, load_error = loadfile(path);
    if (chunk == nil) then
        return nil, tostring(load_error or 'valor_state.lua could not be loaded');
    end
    local ok, values = pcall(chunk);
    if (not ok or type(values) ~= 'table') then
        return nil, tostring(values or 'valor_state.lua did not return a table');
    end
    local character = state.current_character_name();
    if (character == nil or trim_string(values.character):lower() ~= character:lower()) then
        return nil, nil;
    end

    local source = type(values.pov) == 'table' and values.pov or {};
    local pov = new_pov_state();
    pov.zone = trim_string(source.zone);
    pov.progress = bounded_number(source.progress, 0, 0, 100000);
    pov.total = bounded_number(source.total, 0, 0, 100000);
    pov.completed = source.completed == true;
    pov.completion_count = bounded_number(source.completion_count, 0, 0, 100000);
    pov.cycle = bounded_number(source.cycle, 1, 1, 100000);
    pov.runtime_page = state.normalize_pov_runtime_page(source.runtime_page);
    if (pov.runtime_page ~= nil) then
        pov.total = page_total(pov.runtime_page);
        local aggregate = 0;
        for _, target in ipairs(pov.runtime_page.targets) do
            aggregate = aggregate + target.progress;
        end
        pov.progress = aggregate;
    end
    return {
        active = values.active == true,
        visible = values.visible ~= false,
        pov = pov,
    }, nil;
end

state.pov_state_text = function ()
    local character = state.current_character_name();
    if (character == nil) then return nil; end
    local pov = state.pov_run ~= nil and state.pov_run.pov or new_pov_state();
    local lines = {
        '-- Persistent Pages of Valor state. This file survives addon reinstalls.',
        'return {',
        string.format('    character = %s,', lua_quoted(character)),
        string.format('    active = %s,', state.pov_active == true and 'true' or 'false'),
        string.format('    visible = %s,', state.valor_visible[1] == true and 'true' or 'false'),
        '    pov = {',
        string.format('        zone = %s,', lua_quoted(pov.zone)),
        string.format('        progress = %d,', bounded_number(pov.progress, 0, 0, 100000)),
        string.format('        total = %d,', bounded_number(pov.total, 0, 0, 100000)),
        string.format('        completed = %s,', pov.completed == true and 'true' or 'false'),
        string.format('        completion_count = %d,', bounded_number(pov.completion_count, 0, 0, 100000)),
        string.format('        cycle = %d,', bounded_number(pov.cycle, 1, 1, 100000)),
    };
    local page = pov.runtime_page;
    if (page ~= nil) then
        table.insert(lines, '        runtime_page = {');
        table.insert(lines, string.format('            key = %s,', lua_quoted(page.key)));
        table.insert(lines, string.format('            name = %s,', lua_quoted(page.name)));
        if (tonumber(page.number) ~= nil) then
            table.insert(lines, string.format('            number = %d,', math.floor(page.number)));
        end
        table.insert(lines, string.format('            zone = %s,', lua_quoted(page.zone)));
        table.insert(lines, string.format('            notes = %s,', lua_quoted(page.notes)));
        table.insert(lines, '            targets = {');
        for _, target in ipairs(page.targets or {}) do
            table.insert(lines, string.format(
                '                { name = %s, count = %d, progress = %d },',
                lua_quoted(target.name),
                bounded_number(target.count, 0, 0, 1000),
                bounded_number(target.progress, 0, 0, 1000)));
        end
        table.insert(lines, '            },');
        table.insert(lines, '        },');
    end
    table.insert(lines, '    },');
    table.insert(lines, '};');
    table.insert(lines, '');
    return table.concat(lines, '\n');
end

state.save_pov_state_if_needed = function (force)
    local now = os.clock();
    if (not force and now - state.pov_state_last_poll < 0.25) then return; end
    state.pov_state_last_poll = now;
    local current_text = state.pov_state_text();
    if (current_text == nil) then return; end
    if (current_text ~= state.pov_state_observed_text) then
        state.pov_state_observed_text = current_text;
        state.pov_state_pending_at = now;
    end
    if (not force and (current_text == state.pov_state_saved_text or now - state.pov_state_pending_at < 0.75)) then
        return;
    end
    local dir_ok, dir_or_error = ensure_config_dir();
    if (not dir_ok) then
        state.pov_state_save_error = tostring(dir_or_error or 'persistent Valor state directory is unavailable');
        return;
    end
    local path = state.pov_state_file_path();
    if (path == nil) then return; end
    local write_ok, write_error = write_text_file(path, current_text);
    if (not write_ok) then
        local message = tostring(write_error or 'Valor state file could not be written');
        if (state.pov_state_save_error ~= message) then log_warn('Valor state save failed: ' .. message); end
        state.pov_state_save_error = message;
        return;
    end
    state.pov_state_saved_text = current_text;
    state.pov_state_save_error = nil;
end

local function guide_storage_text(guides)
    local lines = {
        '-- Persistent AshitaGuide data. This file survives addon reinstalls.',
        'return {',
        '    guides = {',
    };
    for _, guide in ipairs(guides or {}) do
        table.insert(lines, '        {');
        table.insert(lines, string.format('            key = %s,', lua_quoted(guide.key)));
        table.insert(lines, string.format('            name = %s,', lua_quoted(guide.name)));
        table.insert(lines, string.format('            type = %s,', lua_quoted(guide.type)));
        table.insert(lines, string.format('            description = %s,', lua_quoted(guide.description)));
        table.insert(lines, '            categories = {');
        for _, category in ipairs(guide.categories or {}) do
            table.insert(lines, string.format('                %s,', lua_quoted(category)));
        end
        table.insert(lines, '            },');
        table.insert(lines, '            steps = {');
        for _, step in ipairs(guide.steps or {}) do
            table.insert(lines, '                {');
            table.insert(lines, string.format('                    title = %s,', lua_quoted(step.title)));
            table.insert(lines, string.format('                    text = %s,', lua_quoted(step.text)));
            table.insert(lines, string.format('                    zone = %s,', lua_quoted(step.zone)));
            table.insert(lines, string.format('                    location = %s,', lua_quoted(step.location)));
            table.insert(lines, string.format('                    npc = %s,', lua_quoted(step.npc)));
            table.insert(lines, string.format('                    answer = %s,', lua_quoted(step.answer)));
            table.insert(lines, string.format('                    note = %s,', lua_quoted(step.note)));
            if (step.target_x ~= nil) then
                table.insert(lines, string.format('                    target_x = %.6f,', step.target_x));
            end
            if (step.target_y ~= nil) then
                table.insert(lines, string.format('                    target_y = %.6f,', step.target_y));
            end
            if (step.minimum_level ~= nil) then
                table.insert(lines, string.format('                    minimum_level = %d,', step.minimum_level));
            end
            if (step.required_job ~= '') then
                table.insert(lines, string.format('                    required_job = %s,', lua_quoted(step.required_job)));
            end
            table.insert(lines, string.format('                    advance_on_target = %s,', step.advance_on_target == true and 'true' or 'false'));
            if (step.advance_on_text ~= '') then
                table.insert(lines, string.format('                    advance_on_text = %s,', lua_quoted(step.advance_on_text)));
            end
            if (type(step.sale_items) == 'table' and #step.sale_items > 0) then
                table.insert(lines, '                    sale_items = {');
                for _, item in ipairs(step.sale_items) do
                    table.insert(lines, '                        {');
                    table.insert(lines, string.format('                            name = %s,', lua_quoted(item.name)));
                    if (item.item_id ~= nil) then
                        table.insert(lines, string.format('                            item_id = %d,', item.item_id));
                    end
                    table.insert(lines, string.format('                            quantity_owned = %d,', item.quantity_owned));
                    table.insert(lines, string.format('                            listing_quantity = %d,', item.listing_quantity));
                    table.insert(lines, string.format('                            suggested_price_gil = %d,', item.suggested_price_gil));
                    table.insert(lines, string.format('                            price_basis = %s,', lua_quoted(item.price_basis)));
                    table.insert(lines, string.format('                            observed_at = %s,', lua_quoted(item.observed_at)));
                    table.insert(lines, string.format('                            note = %s,', lua_quoted(item.note)));
                    table.insert(lines, '                        },');
                end
                table.insert(lines, '                    },');
            end
            table.insert(lines, '                },');
        end
        table.insert(lines, '            },');
        table.insert(lines, '        },');
    end
    table.insert(lines, '    },');
    table.insert(lines, '};');
    table.insert(lines, '');
    return table.concat(lines, '\n');
end

local function save_guide_storage(path, guides)
    local dir_ok, dir_or_error = ensure_config_dir();
    if (not dir_ok) then
        return false, tostring(dir_or_error or 'persistent guide directory is unavailable');
    end
    local target = path or path_join(dir_or_error, 'unknown_guides.lua');
    return write_text_file(target, guide_storage_text(guides));
end

local function merge_tables(base, overrides)
    local output = {};
    for key, value in pairs(type(base) == 'table' and base or {}) do
        output[key] = value;
    end
    for key, value in pairs(type(overrides) == 'table' and overrides or {}) do
        output[key] = value;
    end
    return output;
end

local function load_config()
    local previous_active = state.active or {};
    local previous_order = state.active_order or {};
    local previous_selected_active = state.selected_active_key;
    local previous_selected_guide = state.selected_guide_key;
    local previous_pov_run = state.pov_run;

    local config, config_error = load_raw_config();
    local persisted_settings, settings_error = load_persisted_settings();
    local permanent_sources, permanent_error = load_persisted_guides(
        permanent_guides_file_path(), 'permanent_guides.lua');
    local ai_sources, ai_error, ai_text = load_persisted_guides(ai_guides_file_path(), 'ai_guides.lua');
    local auction_sale_source, auction_sale_error, auction_sale_text = load_persisted_auction_sale();
    local persisted_pov_state, pov_state_error = state.load_persisted_pov_state();
    state.pov_state_restore_pending = state.current_character_name() == nil;
    state.config_error = config_error or settings_error or permanent_error or ai_error or auction_sale_error or pov_state_error;
    state.settings = normalize_settings(merge_tables(config.settings, persisted_settings));
    state.visible[1] = state.settings.visible;
    state.config_visible[1] = state.settings.config_visible;
    state.valor_enabled[1] = state.settings.valor_enabled;
    state.valor_show_zone[1] = state.settings.valor_show_zone;
    state.valor_show_totals[1] = state.settings.valor_show_totals;
    state.casket_enabled[1] = state.settings.casket_enabled;
    state.guide_show_step_list[1] = state.settings.guide_show_step_list;
    state.guide_map_size[1] = state.settings.guide_map_size;
    state.minimap_marker_enabled[1] = state.settings.minimap_marker_enabled;
    state.guide_opacity[1] = state.settings.guide_opacity;
    state.decision_enabled[1] = state.settings.decision_enabled;
    state.decision_hide_native_chat[1] = state.settings.decision_hide_native_chat;
    state.decision_opacity[1] = state.settings.decision_opacity;
    state.valor_opacity[1] = state.settings.valor_opacity;
    state.casket_opacity[1] = state.settings.casket_opacity;
    state.casket_stale_seconds[1] = state.settings.casket_stale_seconds;
    state.auction_sale_enabled[1] = state.settings.auction_sale_enabled;
    state.auction_sale_show_price_basis[1] = state.settings.auction_sale_show_price_basis;
    state.auction_sale_show_observed_at[1] = state.settings.auction_sale_show_observed_at;
    state.casket = state.casket or new_casket_state();
    if (state.casket_enabled[1] ~= true) then
        state.casket_visible[1] = false;
    end
    state.settings_observed_text = nil;
    state.settings_saved_text = nil;
    state.settings_pending_at = 0;
    state.settings_last_poll = 0;
    state.settings_save_error = nil;

    local guides_by_key = {};
    local guides = {};
    if (config.disable_builtins ~= true) then
        for index, source in ipairs(builtin_guides()) do
            local guide = normalize_guide(source, index, 'builtin');
            guides_by_key[guide.key] = guide;
            table.insert(guides, guide);
        end
    end

    if (type(config.guides) == 'table') then
        for index, source in ipairs(config.guides) do
            local guide = normalize_guide(source, index + #guides, 'config');
            if (guides_by_key[guide.key] == nil) then
                table.insert(guides, guide);
            else
                for existing_index, existing in ipairs(guides) do
                    if (existing.key == guide.key) then
                        guides[existing_index] = guide;
                        break;
                    end
                end
            end
            guides_by_key[guide.key] = guide;
        end
    end

    local permanent_guides = {};
    for index, source in ipairs(permanent_sources) do
        local guide = normalize_guide(source, index + #guides, 'permanent');
        if (guides_by_key[guide.key] == nil) then
            guides_by_key[guide.key] = guide;
            table.insert(guides, guide);
            table.insert(permanent_guides, guide);
        end
    end

    local ai_guides = {};
    for index, source in ipairs(ai_sources) do
        local guide = normalize_guide(source, index + #guides, 'ai');
        if (guides_by_key[guide.key] == nil) then
            guides_by_key[guide.key] = guide;
            table.insert(guides, guide);
            table.insert(ai_guides, guide);
        end
    end

    state.permanent_guides = permanent_guides;
    state.ai_guides = ai_guides;
    state.ai_storage_error = permanent_error or ai_error;
    state.ai_observed_text = ai_text or '';

    local auction_sale_guide = nil;
    if (auction_sale_source ~= nil) then
        local candidate = normalize_guide(auction_sale_source, #guides + 1, 'auction_sale');
        candidate.type = 'auction_sale_list';
        if (guides_by_key[candidate.key] == nil) then
            auction_sale_guide = candidate;
            guides_by_key[candidate.key] = candidate;
            table.insert(guides, candidate);
        else
            auction_sale_error = 'Auction sale guide key conflicts with another guide.';
        end
    end
    state.auction_sale_guide = auction_sale_guide;
    state.auction_sale_storage_error = auction_sale_error;
    state.auction_sale_observed_text = auction_sale_text or '';

    state.guides = guides;
    state.guide_by_key = guides_by_key;
    state.categories = category_catalog(guides);
    state.active = {};
    state.active_order = {};

    local desired_order = #previous_order > 0 and previous_order or state.settings.default_active_guides;
    for _, key in ipairs(desired_order) do
        local guide = state.guide_by_key[key];
        if (guide ~= nil
            and guide.type ~= 'pages_of_valor'
            and (guide.origin ~= 'auction_sale' or state.auction_sale_enabled[1] == true)) then
            start_guide(guide, previous_active[key]);
        end
    end
    for _, guide in ipairs(state.ai_guides) do
        start_guide(guide, previous_active[guide.key]);
    end
    if (state.auction_sale_enabled[1] == true and state.auction_sale_guide ~= nil) then
        start_guide(state.auction_sale_guide, previous_active[state.auction_sale_guide.key]);
    end

    local pov_guide = state.guide_by_key.pages_of_valor;
    if (pov_guide ~= nil) then
        local restored_run = previous_pov_run;
        if (restored_run == nil and persisted_pov_state ~= nil) then
            restored_run = { pov = persisted_pov_state.pov, step_index = 1 };
            state.pov_active = persisted_pov_state.active;
            state.valor_visible[1] = persisted_pov_state.active and persisted_pov_state.visible;
        end
        state.pov_run = create_run(pov_guide, restored_run);
    else
        state.pov_run = nil;
    end

    state.selected_active_key = previous_selected_active;
    if (state.selected_active_key == nil or state.active[state.selected_active_key] == nil) then
        state.selected_active_key = state.auction_sale_enabled[1] == true
            and state.auction_sale_guide ~= nil
            and state.auction_sale_guide.key
            or state.active_order[1];
    end

    state.selected_guide_key = previous_selected_guide;
    if (not guide_is_configurable(state.guide_by_key[state.selected_guide_key])) then
        state.selected_guide_key = nil;
        for _, guide in ipairs(state.guides) do
            if (guide_is_configurable(guide)) then
                state.selected_guide_key = guide.key;
                break;
            end
        end
    end

    local filter_exists = false;
    for _, category in ipairs(state.categories) do
        if (category.key == state.category_filter) then
            filter_exists = true;
            break;
        end
    end
    if (filter_exists ~= true) then
        state.category_filter = 'all';
    end

    if (state.ai_selected_key == nil or state.guide_by_key[state.ai_selected_key] == nil
        or state.guide_by_key[state.ai_selected_key].origin ~= 'ai') then
        state.ai_selected_key = state.ai_guides[1] ~= nil and state.ai_guides[1].key or nil;
        state.ai_editor_key = nil;
    end
end

state.restore_persisted_pov_state_if_needed = function ()
    if (state.pov_state_restore_pending ~= true or state.current_character_name() == nil) then return; end
    state.pov_state_restore_pending = false;
    local persisted, restore_error = state.load_persisted_pov_state();
    if (restore_error ~= nil) then
        log_warn('Valor state restore failed: ' .. restore_error);
        return;
    end
    if (persisted == nil or state.pov_run == nil) then return; end
    state.pov_run.pov = persisted.pov;
    state.pov_active = persisted.active;
    state.valor_visible[1] = persisted.active and persisted.visible;
end

local function lua_boolean(value)
    return value == true and 'true' or 'false';
end

local function lua_string_list(values)
    local pieces = {};
    for _, value in ipairs(values or {}) do
        table.insert(pieces, string.format('%q', tostring(value)));
    end
    return #pieces > 0 and ('{ ' .. table.concat(pieces, ', ') .. ' }') or '{}';
end

local function lua_number_map(values)
    local keys = {};
    for key, value in pairs(type(values) == 'table' and values or {}) do
        if (type(key) == 'string' and tonumber(value) ~= nil) then
            table.insert(keys, key);
        end
    end
    table.sort(keys);
    local pieces = {};
    for _, key in ipairs(keys) do
        table.insert(pieces, string.format('[%q] = %d', key, bounded_number(values[key], 1, 1, 100000)));
    end
    return #pieces > 0 and ('{ ' .. table.concat(pieces, ', ') .. ' }') or '{}';
end

local function settings_text()
    local values = state.settings;
    local lines = {
        'return {',
        string.format('    visible = %s,', lua_boolean(state.visible[1])),
        string.format('    window_x = %d,', bounded_number(values.window_x, DEFAULT_SETTINGS.window_x, 0, 10000)),
        string.format('    window_y = %d,', bounded_number(values.window_y, DEFAULT_SETTINGS.window_y, 0, 10000)),
        string.format('    guide_anchor_corner = %q,', normalize_guide_anchor_corner(values.guide_anchor_corner)),
        string.format('    guide_show_step_list = %s,', lua_boolean(state.guide_show_step_list[1])),
        string.format('    guide_map_size = %d,', bounded_number(state.guide_map_size[1], DEFAULT_SETTINGS.guide_map_size, 120, 260)),
        string.format('    minimap_marker_enabled = %s,', lua_boolean(state.minimap_marker_enabled[1])),
        string.format('    guide_opacity = %d,', bounded_number(state.guide_opacity[1], DEFAULT_SETTINGS.guide_opacity, 0, 100)),
        string.format('    decision_enabled = %s,', lua_boolean(state.decision_enabled[1])),
        string.format('    decision_hide_native_chat = %s,', lua_boolean(state.decision_hide_native_chat[1])),
        string.format('    decision_anchor_corner = %q,', decision.normalize_anchor(values.decision_anchor_corner)),
        string.format('    decision_window_x = %d,', bounded_number(values.decision_window_x, DEFAULT_SETTINGS.decision_window_x, 0, 10000)),
        string.format('    decision_window_y = %d,', bounded_number(values.decision_window_y, DEFAULT_SETTINGS.decision_window_y, 0, 10000)),
        string.format('    decision_opacity = %d,', bounded_number(state.decision_opacity[1], DEFAULT_SETTINGS.decision_opacity, 0, 100)),
        string.format('    config_visible = %s,', lua_boolean(state.config_visible[1])),
        string.format('    config_window_x = %d,', bounded_number(values.config_window_x, DEFAULT_SETTINGS.config_window_x, 0, 10000)),
        string.format('    config_window_y = %d,', bounded_number(values.config_window_y, DEFAULT_SETTINGS.config_window_y, 0, 10000)),
        string.format('    config_window_width = %d,', bounded_number(values.config_window_width, DEFAULT_SETTINGS.config_window_width, 260, 600)),
        string.format('    config_window_height = %d,', bounded_number(values.config_window_height, DEFAULT_SETTINGS.config_window_height, 320, 1000)),
        string.format('    valor_enabled = %s,', lua_boolean(state.valor_enabled[1])),
        string.format('    valor_show_zone = %s,', lua_boolean(state.valor_show_zone[1])),
        string.format('    valor_show_totals = %s,', lua_boolean(state.valor_show_totals[1])),
        string.format('    valor_opacity = %d,', bounded_number(state.valor_opacity[1], DEFAULT_SETTINGS.valor_opacity, 0, 100)),
        string.format('    valor_window_x = %d,', bounded_number(values.valor_window_x, DEFAULT_SETTINGS.valor_window_x, 0, 10000)),
        string.format('    valor_window_y = %d,', bounded_number(values.valor_window_y, DEFAULT_SETTINGS.valor_window_y, 0, 10000)),
        string.format('    valor_window_width = %d,', bounded_number(values.valor_window_width, DEFAULT_SETTINGS.valor_window_width, 220, 600)),
        string.format('    valor_window_height = %d,', bounded_number(values.valor_window_height, DEFAULT_SETTINGS.valor_window_height, 80, 400)),
        string.format('    casket_enabled = %s,', lua_boolean(state.casket_enabled[1])),
        string.format('    casket_opacity = %d,', bounded_number(state.casket_opacity[1], DEFAULT_SETTINGS.casket_opacity, 0, 100)),
        string.format('    casket_window_x = %d,', bounded_number(values.casket_window_x, DEFAULT_SETTINGS.casket_window_x, 0, 10000)),
        string.format('    casket_window_y = %d,', bounded_number(values.casket_window_y, DEFAULT_SETTINGS.casket_window_y, 0, 10000)),
        string.format('    casket_window_width = %d,', bounded_number(values.casket_window_width, DEFAULT_SETTINGS.casket_window_width, 430, 900)),
        string.format('    casket_window_height = %d,', bounded_number(values.casket_window_height, DEFAULT_SETTINGS.casket_window_height, 280, 800)),
        string.format('    casket_stale_seconds = %d,', bounded_number(state.casket_stale_seconds[1], DEFAULT_SETTINGS.casket_stale_seconds, 0, 900)),
        string.format('    auction_sale_enabled = %s,', lua_boolean(state.auction_sale_enabled[1])),
        string.format('    auction_sale_show_price_basis = %s,', lua_boolean(state.auction_sale_show_price_basis[1])),
        string.format('    auction_sale_show_observed_at = %s,', lua_boolean(state.auction_sale_show_observed_at[1])),
        string.format('    chat_log_seed_lines = %d,', bounded_number(values.chat_log_seed_lines, DEFAULT_SETTINGS.chat_log_seed_lines, 0, 5000)),
        string.format('    poll_chat_log = %s,', lua_boolean(values.poll_chat_log)),
        string.format('    default_active_guides = %s,', lua_string_list(state.active_order)),
        string.format('    guide_steps = %s,', lua_number_map(values.guide_steps)),
        '};',
        '',
    };
    return table.concat(lines, '\n');
end

local function save_settings_if_needed(force)
    local now = os.clock();
    if (not force and now - state.settings_last_poll < 0.25) then
        return;
    end
    state.settings_last_poll = now;

    local current_text = settings_text();
    if (current_text ~= state.settings_observed_text) then
        state.settings_observed_text = current_text;
        state.settings_pending_at = now;
    end
    if (not force and (current_text == state.settings_saved_text or now - state.settings_pending_at < 0.75)) then
        return;
    end

    local dir_ok, dir_or_error = ensure_config_dir();
    if (not dir_ok) then
        local message = tostring(dir_or_error or 'persistent settings directory is unavailable');
        if (state.settings_save_error ~= message) then
            state.settings_save_error = message;
            log_warn('Settings save failed: ' .. message);
        end
        return;
    end
    local path = path_join(dir_or_error, 'settings.lua');
    local write_ok, write_error = write_text_file(path, current_text);
    if (not write_ok) then
        local message = tostring(write_error or 'settings file could not be written');
        if (state.settings_save_error ~= message) then
            state.settings_save_error = message;
            log_warn('Settings save failed: ' .. message);
        end
        return;
    end
    state.settings_saved_text = current_text;
    state.settings_save_error = nil;
end

local function current_pov_page(run)
    if (run == nil or run.pov == nil) then
        return nil;
    end
    return run.pov.runtime_page;
end

local function reset_pov_pending(pov)
    pov.pending = {
        capturing = false,
        targets = {},
        target_by_name = {},
        zone = '',
        level_range = '',
    };
end

local function transcript_body(text)
    return trim_string(tostring(text or ''):gsub('%[%d%d:%d%d:%d%d%]%s*', ''));
end

local function capture_pov_transcript(pov, text)
    local body = transcript_body(text);
    local lower = body:lower();
    if (lower:find('the information on this page instructs you to defeat the following:', 1, true) ~= nil) then
        reset_pov_pending(pov);
        pov.pending.capturing = true;
    end
    if (pov.pending.capturing ~= true) then
        return;
    end

    for count_text, name_text in body:gmatch('(%d+)%s+([^%.]+)%.') do
        local name = trim_string(name_text);
        local key = name:lower();
        if (name ~= '' and key ~= 'target level range') then
            local count = math.max(1, math.floor(tonumber(count_text) or 1));
            local existing = pov.pending.target_by_name[key];
            if (existing ~= nil) then
                existing.count = count;
            else
                local target = { name = name, count = count };
                pov.pending.target_by_name[key] = target;
                table.insert(pov.pending.targets, target);
            end
        end
    end

    local level_range = body:match('[Tt]arget level range:%s*(.-)%.');
    if (level_range ~= nil) then
        pov.pending.level_range = trim_string(level_range);
    end
    local zone = body:match('[Tt]raining area:%s*(.-)%.');
    if (zone ~= nil) then
        pov.pending.zone = trim_string(zone);
    end
end

local function commit_pov_transcript(run)
    local pov = run.pov;
    local pending = pov.pending;
    if (pending == nil or #pending.targets == 0) then
        return false;
    end

    local targets = {};
    for _, target in ipairs(pending.targets) do
        table.insert(targets, { name = target.name, count = target.count, progress = 0 });
    end
    local notes = '';
    if (pending.level_range ~= '') then
        notes = 'Target level range: ' .. pending.level_range;
    end
    local zone = pending.zone ~= '' and pending.zone or trim_string(pov.zone);
    pov.runtime_page = {
        key = 'active_regime',
        name = zone ~= '' and zone or 'Active training regime',
        number = nil,
        zone = zone,
        notes = notes,
        targets = targets,
    };
    pov.zone = zone;
    pov.progress = 0;
    pov.total = page_total(pov.runtime_page);
    pov.completed = false;
    run.step_index = 1;
    reset_pov_pending(pov);
    log_info(string.format('Detected active Pages of Valor regime in %s with %d targets.', zone ~= '' and zone or 'the current area', pov.total));
    return true;
end

local function extract_area(text)
    return trim_string(text:match('^=== Area:%s*(.-)%s*===') or '');
end

local function is_training_accept(text)
    local lower = text:lower();
    if (lower:find('training', 1, true) == nil and lower:find('regime', 1, true) == nil) then
        return false;
    end
    return lower:find('registered', 1, true) ~= nil
        or lower:find('undertaken', 1, true) ~= nil
        or lower:find('accepted', 1, true) ~= nil
        or lower:find('set training', 1, true) ~= nil
        or lower:find('begin', 1, true) ~= nil;
end

local function is_training_complete(text)
    local lower = text:lower();
    return lower:find('successfully completed the training regime', 1, true) ~= nil
        or lower:find('training regime complete', 1, true) ~= nil
        or lower:find('completed the training regime', 1, true) ~= nil;
end

state.is_training_repeat = function (text)
    local lower = text:lower();
    return lower:find('current training regime will begin anew', 1, true) ~= nil
        or lower:find('training regime will begin anew', 1, true) ~= nil;
end

local function is_training_cancel(text)
    local lower = text:lower();
    return lower:find('training regime has been canceled', 1, true) ~= nil
        or lower:find('training regime has been cancelled', 1, true) ~= nil
        or lower:find('training regime canceled', 1, true) ~= nil
        or lower:find('training regime cancelled', 1, true) ~= nil;
end

local function extract_progress(text)
    local patterns = {
        'You defeated a training regime target%. %(Progress:%s*(%d+)%s*/%s*(%d+)%)',
        'You defeated a training regime target%. %(Progress%s*(%d+)%s*/%s*(%d+)%)',
        'training regime target.-%(Progress:%s*(%d+)%s*/%s*(%d+)%)',
        'training regime target.-%((%d+)%s*/%s*(%d+)%)',
    };
    for _, pattern in ipairs(patterns) do
        local current, total = text:match(pattern);
        if (current ~= nil and total ~= nil) then
            return math.floor(tonumber(current)), math.floor(tonumber(total));
        end
    end
    return nil, nil;
end

local function extract_designated_progress(text)
    local current, total = text:match('You defeated a designated target%. %(Progress:%s*(%d+)%s*/%s*(%d+)%)');
    if (current == nil or total == nil) then
        return nil, nil;
    end
    return math.floor(tonumber(current)), math.floor(tonumber(total));
end

local function singular_target_name(value)
    local name = trim_string(value):lower():gsub('^the%s+', ''):gsub('[^%a%d%s]', ''):gsub('%s+', ' ');
    if (name:sub(-3) == 'ies') then
        return name:sub(1, -4) .. 'y';
    end
    if (name:sub(-2) == 'es') then
        return name:sub(1, -3);
    end
    if (name:sub(-1) == 's') then
        return name:sub(1, -2);
    end
    return name;
end

state.infer_pov_runtime_page = function (pov, total)
    local zone = trim_string(pov.zone);
    if (zone == '') then zone = state.current_zone_name() or ''; end
    local defeated = singular_target_name(pov.last_defeated_name);
    if (zone == '' or defeated == '' or total == nil) then return nil; end
    for _, page in ipairs(state.pov_recovery_pages) do
        if (page.zone:lower() == zone:lower()) then
            for _, target in ipairs(page.targets) do
                if (target.count == total and singular_target_name(target.name) == defeated) then
                    local recovered = {
                        key = page.key,
                        name = page.name,
                        number = page.number,
                        zone = page.zone,
                        notes = page.notes,
                        targets = {},
                    };
                    for _, page_target in ipairs(page.targets) do
                        table.insert(recovered.targets, {
                            name = page_target.name,
                            count = page_target.count,
                            progress = 0,
                        });
                    end
                    pov.runtime_page = recovered;
                    pov.zone = recovered.zone;
                    pov.total = page_total(recovered);
                    log_info('Recovered active training details as ' .. recovered.name .. ' from recent chat evidence.');
                    return recovered;
                end
            end
        end
    end
    return nil;
end

local function update_designated_progress(run, current, total)
    local pov = run.pov;
    local page = current_pov_page(run);
    if (page == nil) then
        page = state.infer_pov_runtime_page(pov, total);
        if (page == nil) then return; end
    end

    local defeated = singular_target_name(pov.last_defeated_name);
    local matched = nil;
    for _, target in ipairs(page.targets or {}) do
        if (target.count == total and defeated ~= '' and singular_target_name(target.name) == defeated) then
            matched = target;
            break;
        end
    end
    if (matched == nil) then
        for _, target in ipairs(page.targets or {}) do
            if (target.count == total) then
                if (matched ~= nil) then
                    return;
                end
                matched = target;
            end
        end
    end
    if (matched == nil) then
        return;
    end

    matched.progress = math.max(0, math.min(current, total));
    local aggregate = 0;
    for _, target in ipairs(page.targets or {}) do
        aggregate = aggregate + (tonumber(target.progress) or 0);
    end
    pov.progress = aggregate;
    pov.total = page_total(page);
    pov.completed = pov.total > 0 and pov.progress >= pov.total;
    run.step_index = 1;
end

local function update_pov_progress(run, current, total)
    if (run == nil or run.pov == nil or current == nil or total == nil) then
        return;
    end

    local pov = run.pov;
    if (pov.total ~= 0 and total ~= pov.total) then
        pov.total = total;
    elseif (pov.total == 0) then
        pov.total = total;
    end

    current = math.max(0, math.min(current, total));
    if (current < (pov.progress or 0) and total == pov.total) then
        pov.cycle = (pov.cycle or 1) + 1;
        pov.completed = false;
    end

    pov.progress = current;
    if (total > 0 and current >= total) then
        pov.completed = true;
        run.step_index = 1;
    else
        pov.completed = false;
        run.step_index = 1;
    end
end

local function handle_pov_text(run, text)
    if (run == nil or run.pov == nil or text == '') then
        return false;
    end

    local pov = run.pov;
    capture_pov_transcript(pov, text);
    local defeated_name = text:match('defeats the ([^%.]+)%.')
        or text:match('^The (.-) falls to the ground%.$');
    if (defeated_name ~= nil) then
        pov.last_defeated_name = trim_string(defeated_name);
        pov.last_defeated_time = os.clock();
    end
    local area = extract_area(text);
    if (area ~= '') then
        pov.zone = area;
    end

    if (state.is_training_repeat(text)) then
        pov.progress = 0;
        pov.completed = false;
        pov.cycle = (pov.cycle or 1) + 1;
        if (pov.runtime_page ~= nil) then
            for _, target in ipairs(pov.runtime_page.targets or {}) do target.progress = 0; end
            pov.total = page_total(pov.runtime_page);
        end
        run.step_index = 1;
        return true;
    end

    if (is_training_accept(text)) then
        commit_pov_transcript(run);
        return true;
    end

    local designated_current, designated_total = extract_designated_progress(text);
    if (designated_current ~= nil and designated_total ~= nil) then
        update_designated_progress(run, designated_current, designated_total);
        return true;
    end

    local current, total = extract_progress(text);
    if (current ~= nil and total ~= nil) then
        update_pov_progress(run, current, total);
        return true;
    end

    if (is_training_complete(text)) then
        if (pov.completed ~= true) then
            pov.completion_count = (pov.completion_count or 0) + 1;
        end
        pov.completed = true;
        if (pov.total > 0) then
            pov.progress = pov.total;
        end
        run.step_index = 1;
        return true;
    end

    if (is_training_cancel(text)) then
        run.pov = new_pov_state();
        run.step_index = 1;
        return true;
    end

    return false;
end

local function process_observed_text(text, source, mode, alternate_mode)
    local cleaned = clean_message(text);
    if (cleaned == '') then
        return false;
    end

    local handled = process_casket_text(cleaned, source, mode, alternate_mode);
    if (source == 'text') then
        local run = state.active[state.selected_active_key];
        local step = run ~= nil and run.guide.steps[run.step_index] or nil;
        local trigger = step ~= nil and trim_string(step.advance_on_text) or '';
        if (trigger ~= '' and run.step_index < #run.guide.steps) then
            local normalized_text = trim_string(cleaned:lower():gsub('[^%w]+', ' '));
            local normalized_trigger = trim_string(trigger:lower():gsub('[^%w]+', ' '));
            if (normalized_trigger ~= '' and normalized_text:find(normalized_trigger, 1, true) ~= nil) then
                next_step(run);
                handled = true;
            end
        end
    end
    local guide = state.guide_by_key.pages_of_valor;
    if (guide ~= nil) then
        local run = state.pov_run;
        if (run == nil) then
            run = create_run(guide);
            state.pov_run = run;
        end

        local current, total = extract_progress(cleaned);
        local designated_current, designated_total = extract_designated_progress(cleaned);
        local activation_evidence = is_training_accept(cleaned)
            or state.is_training_repeat(cleaned)
            or (current ~= nil and total ~= nil)
            or (designated_current ~= nil and designated_total ~= nil);
        local ended = is_training_cancel(cleaned) or is_training_complete(cleaned);
        local pov_handled = handle_pov_text(run, cleaned) or activation_evidence;

        if (activation_evidence) then
            local was_active = state.pov_active;
            state.pov_active = true;
            if (not was_active and state.valor_enabled[1] == true) then
                state.valor_visible[1] = true;
            end
        elseif (ended) then
            state.pov_active = false;
            state.valor_visible[1] = false;
        end

        handled = handled or pov_handled;
    end

    if (handled == true) then
        if (source == 'log' or source == 'seed') then
            state.observed_log_events = state.observed_log_events + 1;
        else
            state.observed_text_events = state.observed_text_events + 1;
        end
    end
    return handled;
end

local function seed_chat_log()
    local limit = tonumber(state.settings.chat_log_seed_lines) or 0;
    if (limit <= 0) then
        return;
    end

    local path = current_chat_log_path();
    if (path == nil) then
        return;
    end

    local file = io.open(path, 'r');
    if (file == nil) then
        return;
    end

    local lines = {};
    for line in file:lines() do
        table.insert(lines, line);
        if (#lines > limit) then
            table.remove(lines, 1);
        end
    end

    for _, line in ipairs(lines) do
        process_observed_text(line, 'seed');
    end

    state.observed_log_path = path;
    state.observed_log_position = file:seek('end') or 0;
    file:close();
end

local function poll_chat_log()
    if (state.settings.poll_chat_log ~= true) then
        return;
    end

    local now = os.time();
    if (state.observed_log_last_check == now) then
        return;
    end
    state.observed_log_last_check = now;

    local path = current_chat_log_path();
    if (path == nil) then
        return;
    end
    if (state.observed_log_path ~= path) then
        state.observed_log_path = path;
        state.observed_log_position = 0;
        seed_chat_log();
        return;
    end

    local file = io.open(path, 'r');
    if (file == nil) then
        return;
    end

    local size = file:seek('end') or 0;
    local position = tonumber(state.observed_log_position) or 0;
    if (position <= 0 or position > size) then
        state.observed_log_position = size;
        file:close();
        return;
    end

    file:seek('set', position);
    for line in file:lines() do
        process_observed_text(line, 'log');
    end
    state.observed_log_position = file:seek() or size;
    file:close();
end

local function poll_ai_guides_file()
    local now = os.time();
    if (now - state.ai_last_poll < 1.0) then
        return;
    end
    state.ai_last_poll = now;
    local path = ai_guides_file_path();
    local contents = '';
    if (file_exists(path)) then
        contents = read_text_file(path) or '';
    end
    if (state.ai_observed_text ~= nil and contents ~= state.ai_observed_text) then
        load_config();
    end
end

local function poll_auction_sale_guide_file()
    local now = os.time();
    if (now - state.auction_sale_last_poll < 1.0) then
        return;
    end
    state.auction_sale_last_poll = now;
    local path = auction_sale_guide_file_path();
    local contents = '';
    if (file_exists(path)) then
        contents = read_text_file(path) or '';
    end
    if (state.auction_sale_observed_text ~= nil and contents ~= state.auction_sale_observed_text) then
        load_config();
        if (state.auction_sale_enabled[1] == true and state.auction_sale_guide ~= nil) then
            state.selected_active_key = state.auction_sale_guide.key;
            state.visible[1] = true;
        end
    end
end

local function guides_without_key(guides, key)
    local output = {};
    for _, guide in ipairs(guides or {}) do
        if (guide.key ~= key) then
            table.insert(output, guide);
        end
    end
    return output;
end

local function delete_ai_guide(key)
    local guide = state.guide_by_key[key];
    if (guide == nil or guide.origin ~= 'ai') then
        stop_guide(key);
        return true;
    end

    local remaining = guides_without_key(state.ai_guides, key);
    local ok, error_message = save_guide_storage(ai_guides_file_path(), remaining);
    if (not ok) then
        state.ai_storage_error = tostring(error_message or 'AI guide could not be deleted');
        log_warn('AI guide delete failed: ' .. state.ai_storage_error);
        return false;
    end

    state.ai_storage_error = nil;
    load_config();
    return true;
end

local function delete_auction_sale_guide(key)
    local guide = state.guide_by_key[key];
    if (guide == nil or guide.origin ~= 'auction_sale') then
        stop_guide(key);
        return true;
    end

    local path = auction_sale_guide_file_path();
    if (path ~= nil and file_exists(path)) then
        local ok, error_message = os.remove(path);
        if (not ok) then
            state.auction_sale_storage_error = tostring(error_message or 'auction sale guide could not be deleted');
            log_warn('Auction sale guide delete failed: ' .. state.auction_sale_storage_error);
            return false;
        end
    end

    state.auction_sale_storage_error = nil;
    load_config();
    return true;
end

local function close_guide_tab(key)
    local guide = state.guide_by_key[key];
    if (guide ~= nil and guide.origin == 'auction_sale') then
        return delete_auction_sale_guide(key);
    end
    if (guide ~= nil and guide.origin == 'ai') then
        return delete_ai_guide(key);
    end
    stop_guide(key);
    return true;
end

local function comma_list(value)
    local output = {};
    local seen = {};
    for part in tostring(value or ''):gmatch('[^,]+') do
        local label = trim_string(part);
        local key = label:lower();
        if (label ~= '' and seen[key] ~= true) then
            seen[key] = true;
            table.insert(output, label);
        end
    end
    if (#output == 0) then
        table.insert(output, 'Uncategorized');
    end
    return output;
end

local function sync_ai_editor(guide)
    if (guide == nil or guide.origin ~= 'ai') then
        state.ai_editor_key = nil;
        state.ai_name_buffer[1] = '';
        state.ai_categories_buffer[1] = '';
        state.ai_description_buffer[1] = '';
        return;
    end
    if (state.ai_editor_key == guide.key) then
        return;
    end
    state.ai_editor_key = guide.key;
    state.ai_name_buffer[1] = guide.name;
    state.ai_categories_buffer[1] = table.concat(guide.categories or {}, ', ');
    state.ai_description_buffer[1] = guide.description or '';
end

local function make_ai_guide_permanent(guide)
    if (guide == nil or guide.origin ~= 'ai') then
        return false;
    end
    local name = trim_string(state.ai_name_buffer[1]);
    if (name == '') then
        state.ai_storage_error = 'A permanent guide needs a title.';
        return false;
    end

    local permanent = normalize_guide({
        key = guide.key,
        name = name,
        type = guide.type,
        description = state.ai_description_buffer[1],
        categories = comma_list(state.ai_categories_buffer[1]),
        steps = guide.steps,
    }, #state.permanent_guides + 1, 'permanent');

    local new_permanent = copy_array(state.permanent_guides);
    table.insert(new_permanent, permanent);
    local new_ai = guides_without_key(state.ai_guides, guide.key);
    local permanent_ok, permanent_error = save_guide_storage(permanent_guides_file_path(), new_permanent);
    if (not permanent_ok) then
        state.ai_storage_error = tostring(permanent_error or 'permanent guide could not be saved');
        return false;
    end
    local ai_ok, ai_error = save_guide_storage(ai_guides_file_path(), new_ai);
    if (not ai_ok) then
        save_guide_storage(permanent_guides_file_path(), state.permanent_guides);
        state.ai_storage_error = tostring(ai_error or 'temporary AI guide could not be removed');
        return false;
    end

    state.ai_storage_error = nil;
    state.selected_guide_key = permanent.key;
    load_config();
    return true;
end

local function guide_matches_category(guide)
    if (state.category_filter == 'all') then
        return true;
    end
    for _, label in ipairs(guide.categories) do
        if (normalize_key(label, label) == state.category_filter) then
            return true;
        end
    end
    return false;
end

local function guide_matches_search(guide)
    local query = lower_string(state.search_buffer[1]);
    if (query == '') then
        return true;
    end
    if (guide.name:lower():find(query, 1, true) ~= nil) then
        return true;
    end
    if (guide.key:lower():find(query, 1, true) ~= nil) then
        return true;
    end
    for _, label in ipairs(guide.categories) do
        if (label:lower():find(query, 1, true) ~= nil) then
            return true;
        end
    end
    return false;
end

local function category_label(key)
    for _, category in ipairs(state.categories) do
        if (category.key == key) then
            return category.label;
        end
    end
    return 'All Categories';
end

local function render_guide_anchor_selector()
    if (type(imgui.BeginCombo) ~= 'function' or type(imgui.Selectable) ~= 'function') then
        imgui.Text('Anchor corner: ' .. guide_anchor_corner_label(state.settings.guide_anchor_corner));
        return;
    end

    imgui.PushItemWidth(220);
    if (imgui.BeginCombo(
        'Anchor corner##ashitaguide_anchor_corner',
        guide_anchor_corner_label(state.settings.guide_anchor_corner))) then
        local current = normalize_guide_anchor_corner(state.settings.guide_anchor_corner);
        for _, option in ipairs(GUIDE_ANCHOR_CORNERS) do
            if (imgui.Selectable(
                option.label .. '##ashitaguide_anchor_corner_' .. option.key,
                current == option.key)) then
                set_guide_anchor_corner(option.key);
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

function decision.render_anchor_selector()
    if (type(imgui.BeginCombo) ~= 'function' or type(imgui.Selectable) ~= 'function') then
        imgui.Text('Anchor corner: ' .. decision.anchor_label(state.settings.decision_anchor_corner));
        return;
    end

    imgui.PushItemWidth(220);
    if (imgui.BeginCombo(
        'Anchor corner##ashitaguide_decision_anchor_corner',
        decision.anchor_label(state.settings.decision_anchor_corner))) then
        local current = decision.normalize_anchor(state.settings.decision_anchor_corner);
        for _, option in ipairs(GUIDE_ANCHOR_CORNERS) do
            if (imgui.Selectable(
                option.label .. '##ashitaguide_decision_anchor_corner_' .. option.key,
                current == option.key)) then
                decision.set_anchor(option.key);
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

function decision.render_config()
    imgui.TextColored(COLORS.header, 'Decision Window');
    imgui.Checkbox('Enabled##ashitaguide_decision_enabled', state.decision_enabled);
    imgui.Checkbox(
        'Hide native chat frame##ashitaguide_decision_hide_native_chat',
        state.decision_hide_native_chat);
    imgui.PushItemWidth(220);
    imgui.SliderInt(
        'Background opacity##ashitaguide_decision_opacity',
        state.decision_opacity,
        0,
        100,
        '%d%%');
    imgui.PopItemWidth();
    decision.render_anchor_selector();
    imgui.TextColored(COLORS.muted, 'The selected corner stays fixed while menu content expands.');
    imgui.TextColored(COLORS.muted, 'Native chat reopens while the normal chat input is active.');
    imgui.TextColored(COLORS.muted, 'Open an NPC decision menu to drag the window into position.');
end

local function render_category_filter()
    if (type(imgui.BeginCombo) == 'function' and type(imgui.Selectable) == 'function') then
        imgui.PushItemWidth(220);
        if (imgui.BeginCombo('Category##ashitaguide_category', category_label(state.category_filter))) then
            for _, category in ipairs(state.categories) do
                if (imgui.Selectable(category.label, state.category_filter == category.key)) then
                    state.category_filter = category.key;
                end
            end
            imgui.EndCombo();
        end
        imgui.PopItemWidth();
        return;
    end

    imgui.Text('Category');
    for _, category in ipairs(state.categories) do
        if (category.key ~= 'all') then
            imgui.SameLine(0, 4);
        end
        local selected = state.category_filter == category.key;
        if (imgui.Button((selected and '* ' or '') .. category.label .. '##ashitaguide_category_' .. category.key)) then
            state.category_filter = category.key;
        end
    end
end

local function render_guide_selector()
    imgui.TextColored(COLORS.header, 'Guides');
    imgui.PushItemWidth(220);
    imgui.SliderInt('Background opacity##ashitaguide_guide_opacity', state.guide_opacity, 0, 100, '%d%%');
    imgui.PopItemWidth();
    render_guide_anchor_selector();
    imgui.Checkbox('Show step list##ashitaguide_guide_show_step_list', state.guide_show_step_list);
    imgui.Checkbox('Show destination on Minimap##ashitaguide_minimap_marker', state.minimap_marker_enabled);
    imgui.PushItemWidth(220);
    imgui.SliderInt('Map size##ashitaguide_guide_map_size', state.guide_map_size, 120, 260, '%d px');
    imgui.PopItemWidth();
    render_category_filter();
    imgui.PushItemWidth(220);
    imgui.InputText('Search##ashitaguide_search', state.search_buffer, 64);
    imgui.PopItemWidth();

    local child_open, child_visible = begin_child('##ashitaguide_guides', { 250, 250 }, true);
    if (child_visible) then
        local visible_index = 0;
        for _, guide in ipairs(state.guides) do
            if (guide_is_configurable(guide)
                and guide_matches_category(guide)
                and guide_matches_search(guide)) then
                visible_index = visible_index + 1;
                local selected = state.selected_guide_key == guide.key;
                local label = string.format('%d. %s##ashitaguide_guide_%s', visible_index, guide.name, guide.key);
                if (type(imgui.Selectable) == 'function') then
                    if (imgui.Selectable(label, selected)) then
                        state.selected_guide_key = guide.key;
                    end
                else
                    if (imgui.Button((selected and '> ' or '') .. label, { 230, 0 })) then
                        state.selected_guide_key = guide.key;
                    end
                end
            end
        end
    end
    if (child_open) then
        imgui.EndChild();
    end

    local selected = state.selected_guide_key ~= nil and state.guide_by_key[state.selected_guide_key] or nil;
    if (selected == nil) then
        imgui.TextColored(COLORS.muted, 'No guide selected.');
        return;
    end

    imgui.Separator();
    imgui.TextColored(COLORS.accent, selected.name);
    text_colored_wrapped(COLORS.muted, table.concat(selected.categories, ', '));
    if (selected.description ~= '') then
        text_wrapped(selected.description);
    end

    if (state.active[selected.key] ~= nil) then
        if (imgui.Button('Stop##ashitaguide_stop_selected', { 76, 0 })) then
            stop_guide(selected.key);
        end
        imgui.SameLine(0, 6);
        if (imgui.Button('Focus##ashitaguide_focus_selected', { 76, 0 })) then
            state.selected_active_key = selected.key;
        end
    else
        if (imgui.Button('Start##ashitaguide_start_selected', { 158, 0 })) then
            start_guide(selected);
        end
    end
end

local function render_ai_guide_config()
    imgui.TextColored(COLORS.header, 'AI Guides');
    text_colored_wrapped(
        COLORS.muted,
        'AI-created guides stay open across reloads and reinstalls. Closing an AI guide with its tab x deletes it permanently.');

    if (state.ai_storage_error ~= nil) then
        text_colored_wrapped(COLORS.warning, 'Storage warning: ' .. state.ai_storage_error);
    end

    if (#state.ai_guides == 0) then
        imgui.Separator();
        imgui.TextColored(COLORS.muted, 'No temporary AI guides are open.');
        return;
    end

    local child_open, child_visible = begin_child('##ashitaguide_ai_guides', { 250, 120 }, true);
    if (child_visible) then
        for index, guide in ipairs(state.ai_guides) do
            local selected = state.ai_selected_key == guide.key;
            local label = string.format('%d. %s##ashitaguide_ai_guide_%s', index, guide.name, guide.key);
            if (type(imgui.Selectable) == 'function') then
                if (imgui.Selectable(label, selected)) then
                    state.ai_selected_key = guide.key;
                end
            elseif (imgui.Button((selected and '> ' or '') .. label, { 230, 0 })) then
                state.ai_selected_key = guide.key;
            end
        end
    end
    if (child_open) then
        imgui.EndChild();
    end

    local selected = state.ai_selected_key ~= nil and state.guide_by_key[state.ai_selected_key] or nil;
    if (selected == nil or selected.origin ~= 'ai') then
        state.ai_selected_key = state.ai_guides[1].key;
        selected = state.ai_guides[1];
    end
    sync_ai_editor(selected);

    imgui.Separator();
    imgui.TextColored(COLORS.accent, 'Make permanent');
    imgui.PushItemWidth(220);
    imgui.InputText('Title##ashitaguide_ai_title', state.ai_name_buffer, 128);
    imgui.InputText('Categories##ashitaguide_ai_categories', state.ai_categories_buffer, 256);
    if (type(imgui.InputTextMultiline) == 'function') then
        imgui.InputTextMultiline(
            'Description##ashitaguide_ai_description',
            state.ai_description_buffer,
            1024,
            { 220, 72 });
    else
        imgui.InputText('Description##ashitaguide_ai_description', state.ai_description_buffer, 1024);
    end
    imgui.PopItemWidth();
    text_colored_wrapped(COLORS.muted, 'Separate categories with commas. The AI-created steps and navigation data are retained.');

    if (imgui.Button('Make Permanent##ashitaguide_ai_permanent', { 158, 0 })) then
        make_ai_guide_permanent(selected);
    end
    imgui.SameLine(0, 6);
    if (imgui.Button('Focus##ashitaguide_ai_focus', { 76, 0 })) then
        state.selected_active_key = selected.key;
        state.visible[1] = true;
    end
end

local function render_auction_sale_config()
    imgui.TextColored(COLORS.header, 'Auction Sales');
    text_colored_wrapped(
        COLORS.muted,
        'A trusted local MCP client can publish one temporary sale list. Closing its guide tab deletes it forever.');

    local enabled_changed = imgui.Checkbox(
        'Enable published sale lists##ashitaguide_auction_sale_enabled',
        state.auction_sale_enabled);
    if (enabled_changed) then
        if (state.auction_sale_enabled[1] == true and state.auction_sale_guide ~= nil) then
            start_guide(state.auction_sale_guide);
            state.selected_active_key = state.auction_sale_guide.key;
            state.visible[1] = true;
        elseif (state.auction_sale_guide ~= nil) then
            stop_guide(state.auction_sale_guide.key);
        end
    end
    imgui.Checkbox(
        'Show price basis##ashitaguide_auction_sale_price_basis',
        state.auction_sale_show_price_basis);
    imgui.Checkbox(
        'Show market date##ashitaguide_auction_sale_observed_at',
        state.auction_sale_show_observed_at);

    imgui.Separator();
    if (state.auction_sale_storage_error ~= nil) then
        text_colored_wrapped(COLORS.warning, 'Storage warning: ' .. state.auction_sale_storage_error);
    end
    if (state.auction_sale_guide == nil) then
        imgui.TextColored(COLORS.muted, 'No auction sale list is currently published.');
        return;
    end

    local step = state.auction_sale_guide.steps[1];
    local item_count = step ~= nil and #(step.sale_items or {}) or 0;
    imgui.TextColored(COLORS.accent, state.auction_sale_guide.name);
    text_colored_wrapped(COLORS.muted, string.format('%d sale item%s published.', item_count, item_count == 1 and '' or 's'));

    if (state.active[state.auction_sale_guide.key] ~= nil) then
        if (imgui.Button('Focus##ashitaguide_auction_sale_focus', { 92, 0 })) then
            state.selected_active_key = state.auction_sale_guide.key;
            state.visible[1] = true;
        end
    elseif (state.auction_sale_enabled[1] == true) then
        if (imgui.Button('Open##ashitaguide_auction_sale_open', { 92, 0 })) then
            start_guide(state.auction_sale_guide);
            state.selected_active_key = state.auction_sale_guide.key;
            state.visible[1] = true;
        end
    end
    imgui.SameLine(0, 6);
    if (imgui.Button('Delete Forever##ashitaguide_auction_sale_delete', { 126, 0 })) then
        delete_auction_sale_guide(state.auction_sale_guide.key);
    end
end

local function render_valor_config()
    imgui.TextColored(COLORS.header, 'Pages of Valor');
    local enabled_changed = imgui.Checkbox('Enabled##ashitaguide_valor_enabled', state.valor_enabled);
    if (enabled_changed) then
        if (state.valor_enabled[1] == true and state.pov_active) then
            state.valor_visible[1] = true;
        elseif (state.valor_enabled[1] ~= true) then
            state.valor_visible[1] = false;
        end
    end
    imgui.Checkbox('Show zone##ashitaguide_valor_zone', state.valor_show_zone);
    imgui.Checkbox('Show progress totals##ashitaguide_valor_totals', state.valor_show_totals);
    imgui.PushItemWidth(220);
    imgui.SliderInt('Background opacity##ashitaguide_valor_opacity', state.valor_opacity, 0, 100, '%d%%');
    imgui.PopItemWidth();
    if (state.pov_active) then
        imgui.Checkbox('Window visible##ashitaguide_valor_visible', state.valor_visible);
    else
        imgui.TextColored(COLORS.muted, 'Status: inactive');
    end
end

local function casket_odds_label(count)
    count = tonumber(count) or 0;
    if (count <= 0) then
        return 'no candidates';
    end
    if (count == 1) then
        return 'certain';
    end
    return string.format('1 in %d', count);
end

local function casket_best_summary(analysis)
    if (analysis.count <= 0) then
        return 'No valid candidates remain; reset and re-check the hints.';
    end
    if (analysis.count == 1) then
        return string.format('Code is %02d.', analysis.best);
    end
    return string.format(
        'Best %02d; %s now; miss leaves at most %d.',
        analysis.best,
        casket_odds_label(analysis.count),
        analysis.worst_after_miss);
end

local function reset_casket_inactive()
    state.casket = new_casket_state();
    state.casket_visible[1] = false;
end

local function run_casket_sample()
    reset_casket_state(os.clock());
    process_casket_text('You have a hunch that one of the two digits is 8.', 'text');
    process_casket_text("You have a hunch that the lock's combination is greater than 80.", 'text');
    process_casket_text("You have a hunch that the lock's combination is less than 88.", 'text');
end

local function render_casket_config()
    state.casket = state.casket or new_casket_state();

    imgui.TextColored(COLORS.header, 'Casket Helper');
    local enabled_changed = imgui.Checkbox('Enabled##ashitaguide_casket_enabled', state.casket_enabled);
    if (enabled_changed and state.casket_enabled[1] ~= true) then
        state.casket_visible[1] = false;
    elseif (enabled_changed and state.casket_enabled[1] == true and state.casket.active == true) then
        state.casket_visible[1] = true;
    end

    imgui.PushItemWidth(220);
    imgui.SliderInt('Background opacity##ashitaguide_casket_opacity', state.casket_opacity, 0, 100, '%d%%');
    imgui.PopItemWidth();
    imgui.SliderInt('Stale timeout##ashitaguide_casket_stale_seconds', state.casket_stale_seconds, 0, 900, '%d sec');

    if (state.casket.active == true) then
        imgui.Checkbox('Window visible##ashitaguide_casket_visible', state.casket_visible);
        local analysis = casket_analyze(state.casket);
        imgui.TextColored(COLORS.muted, string.format('%d possible', analysis.count));
    else
        imgui.TextColored(COLORS.muted, 'Status: inactive');
    end

    if (imgui.Button('Sample##ashitaguide_casket_sample', { 86, 0 })) then
        run_casket_sample();
    end
end

local function render_step_fields(step)
    if (step.answer ~= '') then
        imgui.TextColored(COLORS.muted, 'Answer');
        imgui.SameLine(88, 4);
        text_wrapped(step.answer);
    end
    if (step.note ~= '') then
        imgui.TextColored(COLORS.muted, 'Note');
        imgui.SameLine(88, 4);
        text_wrapped(step.note);
    end
end

local function render_destination_strip(step, navigation)
    local parts = {};
    if (step.zone ~= '') then
        table.insert(parts, step.zone);
    end
    if (step.location ~= '') then
        table.insert(parts, step.location);
    end
    if (step.npc ~= '') then
        table.insert(parts, step.npc);
    end
    if (navigation ~= nil) then
        table.insert(parts, navigation.distance <= 2.5
            and 'Arrived'
            or string.format('%.1f yalms', navigation.distance));
    end
    if (#parts > 0) then
        text_colored_wrapped(COLORS.muted, table.concat(parts, '  |  '));
    end
end

local function current_navigation_player()
    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    if (memory == nil) then
        return nil;
    end

    local party = safe_read(function () return memory:GetParty(); end, nil);
    local entity = safe_read(function () return memory:GetEntity(); end, nil);
    if (party == nil or entity == nil) then
        return nil;
    end

    local index = tonumber(safe_read(function () return party:GetMemberTargetIndex(0); end, 0)) or 0;
    local player = safe_read(function () return GetPlayerEntity(); end, nil);
    local position = player ~= nil and safe_read(function () return player.Movement.LocalPosition; end, nil) or nil;
    local x = position ~= nil and tonumber(safe_read(function () return position.X; end, nil)) or nil;
    local y = position ~= nil and tonumber(safe_read(function () return position.Y; end, nil)) or nil;
    local yaw = position ~= nil and tonumber(safe_read(function () return position.Yaw; end, nil)) or nil;

    if (index > 0) then
        x = x or tonumber(safe_read(function () return entity:GetLocalPositionX(index); end, nil));
        y = y or tonumber(safe_read(function () return entity:GetLocalPositionY(index); end, nil));
        yaw = yaw or tonumber(safe_read(function () return entity:GetLocalPositionYaw(index); end, nil));
        yaw = yaw or tonumber(safe_read(function () return entity:GetHeading(index); end, nil));
    end
    if (x == nil or y == nil or yaw == nil) then
        return nil;
    end

    local zone_id = tonumber(safe_read(function () return party:GetMemberZone(0); end, nil));
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    local zone_name = resources ~= nil
        and clean_message(safe_read(function () return resources:GetString('zones.names', zone_id); end, ''))
        or '';
    return { x = x, y = y, yaw = yaw, zone = zone_name, zone_id = zone_id, entity = entity };
end

state.read_navigation_target_at_index = function(entity, index, lookup, checked_at)
    local name = clean_message(safe_read(function () return entity:GetName(index); end, ''));
    if (name == '' or name:lower() ~= lookup) then
        return nil;
    end

    local x = tonumber(safe_read(function () return entity:GetLocalPositionX(index); end, nil));
    local y = tonumber(safe_read(function () return entity:GetLocalPositionY(index); end, nil));
    if (x == nil or y == nil) then
        return nil;
    end

    return {
        checked_at = checked_at,
        x = x,
        y = y,
        index = index,
        name = name,
    };
end

local function find_navigation_target(player, npc, fallback_x, fallback_y)
    local lookup = lower_string(npc);
    if (player == nil or player.entity == nil or lookup == '') then
        return nil;
    end

    local entity = player.entity;
    if (fallback_x ~= nil and fallback_y ~= nil) then
        local fallback_delta_x = fallback_x - player.x;
        local fallback_delta_y = fallback_y - player.y;
        local fallback_distance = math.sqrt(
            (fallback_delta_x * fallback_delta_x) + (fallback_delta_y * fallback_delta_y));
        if (fallback_distance > state.navigation_target_fallback_scan_distance) then
            return nil;
        end
    end

    local now = os.clock();
    local cache_key = string.format(
        '%s:%s:%s:%s',
        tostring(player.zone_id or 0),
        lookup,
        fallback_x ~= nil and string.format('%.3f', fallback_x) or '',
        fallback_y ~= nil and string.format('%.3f', fallback_y) or '');
    local cached = state.navigation_targets[cache_key];
    if (cached ~= nil and cached.index ~= nil) then
        if (now - cached.checked_at < state.navigation_target_live_refresh_seconds) then
            return cached;
        end

        local refreshed = state.read_navigation_target_at_index(entity, cached.index, lookup, now);
        if (refreshed ~= nil) then
            state.navigation_targets[cache_key] = refreshed;
            return refreshed;
        end
        cached = nil;
    elseif (cached ~= nil and now - cached.checked_at < state.navigation_target_miss_retry_seconds) then
        return cached;
    end

    local result = { checked_at = now };
    local best_distance_squared = nil;
    local count = tonumber(safe_read(function () return entity:GetEntityMapSize(); end, 0)) or 0;
    for index = 0, count - 1 do
        local candidate = state.read_navigation_target_at_index(entity, index, lookup, now);
        if (candidate ~= nil) then
            if (fallback_x == nil or fallback_y == nil) then
                result = candidate;
                break;
            end
            local candidate_delta_x = candidate.x - fallback_x;
            local candidate_delta_y = candidate.y - fallback_y;
            local candidate_distance_squared =
                (candidate_delta_x * candidate_delta_x) + (candidate_delta_y * candidate_delta_y);
            if (best_distance_squared == nil or candidate_distance_squared < best_distance_squared) then
                best_distance_squared = candidate_distance_squared;
                result = candidate;
            end
        end
    end
    state.navigation_targets[cache_key] = result;
    return result;
end

local function current_target_index()
    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    local target = memory ~= nil and safe_read(function () return memory:GetTarget(); end, nil) or nil;
    if (target == nil) then
        return 0;
    end
    local primary = tonumber(safe_read(function () return target:GetTargetIndex(0); end, 0)) or 0;
    local sub = tonumber(safe_read(function () return target:GetTargetIndex(1); end, 0)) or 0;
    local sub_active = truthy(safe_read(function () return target:GetIsSubTargetActive(); end, false));
    return sub_active and sub or primary;
end

local function update_npc_step_auto_advance()
    local run = state.active[state.selected_active_key];
    if (run == nil) then
        return;
    end
    local step = run.guide.steps[run.step_index];
    if (step == nil or step.npc == '' or step.advance_on_target ~= true) then
        run.target_match_step = nil;
        return;
    end

    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    local entity = memory ~= nil and safe_read(function () return memory:GetEntity(); end, nil) or nil;
    local index = current_target_index();
    local name = entity ~= nil and index > 0
        and clean_message(safe_read(function () return entity:GetName(index); end, ''))
        or '';
    local token = string.format('%s:%d', run.key, run.step_index);
    if (name ~= '' and name:lower() == step.npc:lower()) then
        if (run.target_match_step ~= token) then
            run.target_match_step = token;
            next_step(run);
        end
    else
        run.target_match_step = nil;
    end
end

local function update_level_step_auto_advance()
    local run = state.active[state.selected_active_key];
    if (run == nil) then
        return;
    end

    local step = run.guide.steps[run.step_index];
    if (step == nil or step.minimum_level == nil) then
        run.level_match_step = nil;
        return;
    end

    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    local player = memory ~= nil and safe_read(function () return memory:GetPlayer(); end, nil) or nil;
    local job_id = player ~= nil and tonumber(safe_read(function () return player:GetMainJob(); end, nil)) or nil;
    local level = player ~= nil and tonumber(safe_read(function () return player:GetMainJobLevel(); end, nil)) or nil;
    local job = job_id ~= nil and JOB_NAMES[job_id] or nil;
    local job_matches = step.required_job == '' or job == step.required_job;
    local token = string.format('%s:%d', run.key, run.step_index);

    if (level ~= nil and level >= step.minimum_level and job_matches) then
        if (run.level_match_step ~= token) then
            run.level_match_step = token;
            next_step(run);
        end
    else
        run.level_match_step = nil;
    end
end

local function navigation_context(step)
    if (step == nil or (step.target_x == nil and step.target_y == nil and step.npc == '')) then
        return nil;
    end

    local player = current_navigation_player();
    if (player == nil) then
        return nil;
    end
    if (step.zone ~= '' and lower_string(player.zone) ~= lower_string(step.zone)) then
        return nil;
    end

    local live_target = find_navigation_target(player, step.npc, step.target_x, step.target_y);
    local target_x = live_target ~= nil and live_target.x or step.target_x;
    local target_y = live_target ~= nil and live_target.y or step.target_y;
    if (target_x == nil or target_y == nil) then
        return nil;
    end

    local delta_x = target_x - player.x;
    local delta_y = target_y - player.y;
    return {
        player = player,
        live_target = live_target,
        target_x = target_x,
        target_y = target_y,
        delta_x = delta_x,
        delta_y = delta_y,
        distance = math.sqrt((delta_x * delta_x) + (delta_y * delta_y)),
        selected = live_target ~= nil and live_target.index == current_target_index(),
    };
end

local function rotate_minimap_delta(x, y, yaw)
    local angle = (-math.pi / 2) - yaw;
    local cosine = math.cos(angle);
    local sine = math.sin(angle);
    return (x * cosine) - (y * sine), (x * sine) + (y * cosine);
end

local function render_minimap_destination_marker()
    if (state.minimap_marker_enabled[1] ~= true or not minimap_plugin_loaded()) then
        return;
    end

    local run = state.active[state.selected_active_key];
    local step = run ~= nil and run.guide.steps[run.step_index] or nil;
    local navigation = navigation_context(step);
    if (navigation == nil) then
        return;
    end

    local minimap = load_minimap_settings();
    if (minimap == nil or minimap.map_scale_raw == nil) then
        return;
    end
    if (state.minimap.reported_scale_zone ~= navigation.player.zone_id) then
        state.minimap.reported_scale_zone = navigation.player.zone_id;
        log_info(string.format(
            'Minimap marker: zone=%d mapScaleByte=%d zoom=%.2f scale=%.2fx%.2f.',
            navigation.player.zone_id,
            minimap.map_scale_raw,
            minimap.zoom,
            minimap.scale_x,
            minimap.scale_y));
    end

    local delta_x = navigation.delta_x;
    local delta_y = -navigation.delta_y;
    if (minimap.rotate_map) then
        delta_x, delta_y = rotate_minimap_delta(delta_x, delta_y, navigation.player.yaw);
    end

    local center_x = (minimap.x + (minimap.frame_width / 2)) * minimap.scale_x;
    local center_y = (minimap.y + (minimap.frame_height / 2)) * minimap.scale_y;
    -- Match Minimap's live world-to-map transform exactly. Its renderer divides
    -- the active mask size by mapScaleByte * 20, then applies zoom and display scale.
    local pixels_per_yalm_x = minimap.mask_width * minimap.zoom
        / (minimap.map_scale_raw * 20) * minimap.scale_x;
    local pixels_per_yalm_y = minimap.mask_height * minimap.zoom
        / (minimap.map_scale_raw * 20) * minimap.scale_y;
    local marker_x = center_x + (delta_x * pixels_per_yalm_x);
    local marker_y = center_y + (delta_y * pixels_per_yalm_y);

    state.minimap.debug = {
        player_x = navigation.player.x,
        player_y = navigation.player.y,
        player_yaw = navigation.player.yaw,
        target_x = navigation.target_x,
        target_y = navigation.target_y,
        target_index = navigation.live_target ~= nil and navigation.live_target.index or 0,
        delta_x = navigation.delta_x,
        delta_y = navigation.delta_y,
        transformed_x = delta_x,
        transformed_y = delta_y,
        center_x = center_x,
        center_y = center_y,
        marker_x = marker_x,
        marker_y = marker_y,
        pixels_per_yalm_x = pixels_per_yalm_x,
        pixels_per_yalm_y = pixels_per_yalm_y,
        zoom = minimap.zoom,
        scale_x = minimap.scale_x,
        scale_y = minimap.scale_y,
        mask_width = minimap.mask_width,
        mask_height = minimap.mask_height,
        map_scale_raw = minimap.map_scale_raw,
        rotate_map = minimap.rotate_map,
        rotate_frame = minimap.rotate_frame,
        runtime_address = minimap.runtime_address,
    };

    local marker_radius = 10;
    local half_width = math.max(marker_radius, (minimap.mask_width * minimap.scale_x) / 2 - marker_radius);
    local half_height = math.max(marker_radius, (minimap.mask_height * minimap.scale_y) / 2 - marker_radius);
    local clamped = false;
    if (marker_x < center_x - half_width) then
        marker_x = center_x - half_width;
        clamped = true;
    elseif (marker_x > center_x + half_width) then
        marker_x = center_x + half_width;
        clamped = true;
    end
    if (marker_y < center_y - half_height) then
        marker_y = center_y - half_height;
        clamped = true;
    elseif (marker_y > center_y + half_height) then
        marker_y = center_y + half_height;
        clamped = true;
    end

    local marker_token = string.format('%s:%d', run.key, run.step_index);
    if (state.minimap.reported_marker_step ~= marker_token) then
        state.minimap.reported_marker_step = marker_token;
        log_info(string.format(
            'Minimap marker geometry: center=%.1f,%.1f marker=%.1f,%.1f delta=%.1f,%.1f clamped=%s.',
            center_x,
            center_y,
            marker_x,
            marker_y,
            navigation.delta_x,
            navigation.delta_y,
            tostring(clamped)));
    end

    local viewport = safe_read(function ()
        local _, value = d3d8_device:GetViewport();
        return value;
    end, nil);
    if (viewport == nil) then
        return;
    end
    local flags = bit.bor(
        bit.lshift(1, 0),  -- NoTitleBar
        bit.lshift(1, 1),  -- NoResize
        bit.lshift(1, 2),  -- NoMove
        bit.lshift(1, 3),  -- NoScrollbar
        bit.lshift(1, 7),  -- NoBackground
        bit.lshift(1, 8),  -- NoSavedSettings
        bit.lshift(1, 9),  -- NoMouseInputs
        bit.lshift(1, 12), -- NoFocusOnAppearing
        bit.lshift(1, 13), -- NoBringToFrontOnFocus
        bit.lshift(1, 18), -- NoNavInputs
        bit.lshift(1, 19));-- NoNavFocus
    imgui.SetNextWindowPos({ 0, 0 }, 0);
    imgui.SetNextWindowSize({ viewport.Width, viewport.Height }, 0);
    if (type(imgui.SetNextWindowBgAlpha) == 'function') then
        imgui.SetNextWindowBgAlpha(0.0);
    end
    if (imgui.Begin('##ashitaguide_minimap_destination_marker', true, flags)) then
        local draw_list = imgui.GetWindowDrawList();
        if (state.minimap.reported_overlay_window ~= true) then
            state.minimap.reported_overlay_window = true;
            local window_x, window_y = imgui.GetWindowPos();
            local cursor_x, cursor_y = imgui.GetCursorScreenPos();
            log_info(string.format(
                'Minimap overlay window: position=%.1f,%.1f cursor=%.1f,%.1f viewport=%dx%d.',
                tonumber(window_x) or -1,
                tonumber(window_y) or -1,
                tonumber(cursor_x) or -1,
                tonumber(cursor_y) or -1,
                tonumber(viewport.Width) or 0,
                tonumber(viewport.Height) or 0));
        end
        local pulse = 0.82 + ((math.sin(os.clock() * 5) + 1) * 0.09);
        local fill_color = navigation.distance <= 2.5
            and imgui.GetColorU32(COLORS.accent)
            or imgui.GetColorU32({ COLORS.header[1], COLORS.header[2], COLORS.header[3], pulse });
        local outline_color = imgui.GetColorU32({ 0.02, 0.02, 0.02, 0.96 });
        draw_list:AddCircleFilled({ marker_x, marker_y }, 6.0, outline_color, 20);
        draw_list:AddCircleFilled({ marker_x, marker_y }, 4.0, fill_color, 20);
        draw_list:AddCircle({ marker_x, marker_y }, clamped and 9.0 or 8.0, fill_color, 20, 2.0);
    end
    imgui.End();
end

local function navigation_world_radius(distance)
    return math.max(5, distance + 5);
end

local function render_navigation_map(step, navigation)
    if (navigation == nil) then
        return;
    end

    imgui.Separator();
    imgui.TextColored(COLORS.accent, 'Navigation');

    local player = navigation.player;
    local target_x = navigation.target_x;
    local target_y = navigation.target_y;
    local distance = navigation.distance;
    local size = bounded_number(state.guide_map_size[1], 160, 120, 260);
    local padding = 14;
    local world_radius = navigation_world_radius(distance);
    local map_scale = ((size / 2) - padding) / world_radius;
    local cursor_x, cursor_y = imgui.GetCursorScreenPos();
    local center_x = cursor_x + (size / 2);
    local center_y = cursor_y + (size / 2);
    local target_screen_x = center_x + (navigation.delta_x * map_scale);
    local target_screen_y = center_y - (navigation.delta_y * map_scale);
    local draw_list = imgui.GetWindowDrawList();
    local background = imgui.GetColorU32({ 0.045, 0.055, 0.060, 0.96 });
    local grid = imgui.GetColorU32({ 0.40, 0.48, 0.50, 0.24 });
    local border = imgui.GetColorU32({ COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.72 });
    local player_color = imgui.GetColorU32(COLORS.accent);
    local target_color = imgui.GetColorU32(distance <= 2.5 and COLORS.accent or COLORS.header);
    local text_color = imgui.GetColorU32(COLORS.muted);

    draw_list:AddRectFilled(
        { cursor_x, cursor_y },
        { cursor_x + size, cursor_y + size },
        background,
        4.0);
    for index = 1, 3 do
        local offset = (size / 4) * index;
        draw_list:AddLine({ cursor_x + offset, cursor_y }, { cursor_x + offset, cursor_y + size }, grid, 1.0);
        draw_list:AddLine({ cursor_x, cursor_y + offset }, { cursor_x + size, cursor_y + offset }, grid, 1.0);
    end
    draw_list:AddLine({ center_x, cursor_y }, { center_x, cursor_y + size }, grid, 1.4);
    draw_list:AddLine({ cursor_x, center_y }, { cursor_x + size, center_y }, grid, 1.4);
    draw_list:AddRect(
        { cursor_x, cursor_y },
        { cursor_x + size, cursor_y + size },
        border,
        4.0,
        IMGUI.draw_corner_all,
        1.5);

    draw_list:AddText({ center_x - 4, cursor_y + 3 }, text_color, 'N');
    draw_list:AddText({ cursor_x + size - 13, center_y - 8 }, text_color, 'E');
    draw_list:AddText({ center_x - 3, cursor_y + size - 18 }, text_color, 'S');
    draw_list:AddText({ cursor_x + 4, center_y - 8 }, text_color, 'W');

    draw_list:AddCircleFilled({ target_screen_x, target_screen_y }, 6.0, target_color, 20);
    draw_list:AddCircle({ target_screen_x, target_screen_y }, 10.0, target_color, 20, 2.0);

    local heading_x = math.cos(player.yaw);
    local heading_y = math.sin(player.yaw);
    local side_x = -heading_y;
    local side_y = heading_x;
    local tip = { center_x + (heading_x * 13), center_y + (heading_y * 13) };
    local back_x = center_x - (heading_x * 7);
    local back_y = center_y - (heading_y * 7);
    local left = { back_x + (side_x * 7), back_y + (side_y * 7) };
    local right = { back_x - (side_x * 7), back_y - (side_y * 7) };
    draw_list:AddTriangleFilled(tip, left, right, player_color);
    draw_list:AddCircle({ center_x, center_y }, 4.0, player_color, 16, 1.5);

    imgui.Dummy({ size, size });
    imgui.SameLine(0, 8);
    imgui.BeginGroup();
    imgui.TextColored(COLORS.muted, 'Target');
    imgui.Text(step.npc ~= '' and step.npc or 'Destination');
    imgui.Text(distance <= 2.5 and 'Arrived' or string.format('%.1f yalms', distance));
    imgui.TextColored(COLORS.muted, string.format('Map radius: %.1f yalms', world_radius));
    if (step.npc ~= '') then
        imgui.TextColored(
            navigation.selected and COLORS.accent or COLORS.muted,
            navigation.selected and 'Selected: Yes' or 'Selected: No');
    end
    imgui.TextColored(COLORS.muted, string.format('X %.1f  Y %.1f', target_x, target_y));
    imgui.EndGroup();
end

local function render_pov_panel(run)
    if (run == nil or run.pov == nil) then
        return;
    end

    local page = current_pov_page(run);
    if (page == nil) then
        text_colored_wrapped(COLORS.warning, 'Waiting for the active training regime details from chat.');
        return;
    end

    if (state.valor_show_zone[1] == true and page.zone ~= '') then
        imgui.TextColored(COLORS.accent, page.zone);
    end

    if (#page.targets > 0) then
        for _, target in ipairs(page.targets) do
            local count = tonumber(target.count) or 0;
            local killed = math.max(0, math.min(count, tonumber(target.progress) or 0));
            local remaining = math.max(0, count - killed);
            if (state.valor_show_totals[1] == true) then
                imgui.Text(string.format('Kill %d %s  (%d / %d)', remaining, target.name, killed, count));
            else
                imgui.Text(string.format('Kill %d %s', remaining, target.name));
            end
        end
    end

end

local function render_step_list(run)
    for index, step in ipairs(run.guide.steps) do
        local prefix = index == run.step_index and '> ' or '  ';
        local label = step.title ~= '' and step.title or step.text;
        if (index == run.step_index) then
            text_colored_wrapped(COLORS.accent, string.format('%s%d. %s', prefix, index, label));
        else
            text_colored_wrapped(COLORS.muted, string.format('%s%d. %s', prefix, index, label));
        end
    end
end

local function render_guide_navigation_row(run)
    if (imgui.Button('<##ashitaguide_back_' .. run.key, { 36, 0 })) then
        previous_step(run);
    end
    imgui.SameLine(0, 8);

    local child_open, child_visible = begin_child(
        '##ashitaguide_guide_summary_' .. run.key,
        { -52, 46 },
        false);
    if (child_visible) then
        local step = run.guide.steps[run.step_index] or run.guide.steps[1];
        local progress = string.format('STEP %d OF %d', run.step_index, #run.guide.steps);
        centered_text_colored(COLORS.accent, progress);
        if (step.title ~= '') then
            centered_text_colored(COLORS.header, step.title);
        end
    end
    if (child_open) then
        imgui.EndChild();
    end

    imgui.SameLine(0, 8);
    if (imgui.Button('>##ashitaguide_next_' .. run.key, { 36, 0 })) then
        next_step(run);
    end
end

local function format_gil(value)
    local text = tostring(math.max(0, math.floor(tonumber(value) or 0)));
    local reversed = text:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '');
    return reversed .. ' gil';
end

local function render_auction_sale_items(step)
    local items = type(step.sale_items) == 'table' and step.sale_items or {};
    if (step.text ~= '') then
        text_wrapped(step.text);
    end
    if (#items == 0) then
        text_colored_wrapped(COLORS.warning, 'This published sale list contains no items.');
        return;
    end

    imgui.Separator();
    for index, item in ipairs(items) do
        text_colored_wrapped(COLORS.header, string.format('%d. %s', index, item.name));
        local listing_quantity = math.max(1, tonumber(item.listing_quantity) or 1);
        local listing_count = math.floor((tonumber(item.quantity_owned) or 1) / listing_quantity);
        local listing_label = listing_quantity == 1
            and 'Single'
            or string.format('Stack of %d', listing_quantity);
        text_colored_wrapped(
            COLORS.muted,
            string.format(
                'Owned: %d  |  List as: %s  |  Listings: %d',
                item.quantity_owned,
                listing_label,
                listing_count));
        text_colored_wrapped(
            COLORS.accent,
            'Suggested listing price: ' .. format_gil(item.suggested_price_gil));
        if (state.auction_sale_show_price_basis[1] == true and item.price_basis ~= '') then
            text_colored_wrapped(COLORS.muted, 'Basis: ' .. item.price_basis);
        end
        if (state.auction_sale_show_observed_at[1] == true and item.observed_at ~= '') then
            text_colored_wrapped(COLORS.muted, 'Market observed: ' .. item.observed_at);
        end
        if (item.note ~= '') then
            text_colored_wrapped(COLORS.warning, item.note);
        end
        if (index < #items) then
            imgui.Separator();
        end
    end
end

local function render_active_guide(run)
    if (run == nil) then
        imgui.TextColored(COLORS.muted, 'No active guide selected.');
        return;
    end

    local guide = run.guide;
    local step = guide.steps[run.step_index] or guide.steps[1];

    if (#guide.steps > 1) then
        render_guide_navigation_row(run);
    elseif (guide.description ~= '') then
        text_colored_wrapped(COLORS.muted, guide.description);
    end

    imgui.Separator();
    if (#guide.steps == 1 and step.title ~= '') then
        imgui.TextColored(COLORS.header, step.title);
    end
    if (guide.type == 'auction_sale_list') then
        render_auction_sale_items(step);
        return;
    end
    text_wrapped(step.text);
    local navigation = navigation_context(step);
    render_destination_strip(step, navigation);
    render_step_fields(step);
    render_navigation_map(step, navigation);

    if (#guide.steps > 1 and state.guide_show_step_list[1] == true) then
        imgui.Separator();
        render_step_list(run);
    end
end

function decision.guide_answer()
    local run = state.active[state.selected_active_key] or state.active[state.active_order[1]];
    if (run == nil or run.guide == nil) then
        return '';
    end
    local step = run.guide.steps[run.step_index] or run.guide.steps[1];
    return step ~= nil and trim_string(step.answer) or '';
end

function decision.normalize_match(value)
    return trim_string(tostring(value or '')
        :upper()
        :gsub('[^A-Z0-9]+', ' ')
        :gsub('%s+', ' '));
end

function decision.recommended_index(menu, answer)
    local requested = decision.normalize_match(answer)
        :gsub('^SELECT%s+', '')
        :gsub('^CHOOSE%s+', '')
        :gsub('^PICK%s+', '');
    if (requested == '') then
        return nil;
    end

    for index, choice in ipairs(menu.choices) do
        local candidate = decision.normalize_match(choice);
        if (candidate ~= '' and (requested == candidate
            or requested:find(candidate, 1, true) ~= nil
            or candidate:find(requested, 1, true) ~= nil)) then
            return index;
        end
    end
    return nil;
end

function decision.top_left(width, height)
    local x = state.settings.decision_window_x;
    local y = state.settings.decision_window_y;
    local corner = decision.normalize_anchor(state.settings.decision_anchor_corner);
    if (corner == 'top_right' or corner == 'bottom_right') then
        x = x - width;
    end
    if (corner == 'bottom_left' or corner == 'bottom_right') then
        y = y - height;
    end
    return x, y;
end

function decision.capture_anchor(expected_x, expected_y)
    if (type(imgui.GetWindowPos) ~= 'function' or type(imgui.GetWindowSize) ~= 'function') then
        return;
    end

    local x, y = imgui.GetWindowPos();
    local width, height = imgui.GetWindowSize();
    x = tonumber(x) or expected_x;
    y = tonumber(y) or expected_y;
    width = tonumber(width) or state.decision_window_width or 0;
    height = tonumber(height) or state.decision_window_height or 0;

    if (math.abs(x - expected_x) > 0.5 or math.abs(y - expected_y) > 0.5) then
        local corner = decision.normalize_anchor(state.settings.decision_anchor_corner);
        state.settings.decision_window_x = bounded_number(
            x + ((corner == 'top_right' or corner == 'bottom_right') and width or 0),
            state.settings.decision_window_x,
            0,
            10000);
        state.settings.decision_window_y = bounded_number(
            y + ((corner == 'bottom_left' or corner == 'bottom_right') and height or 0),
            state.settings.decision_window_y,
            0,
            10000);
    end

    if (type(imgui.SetWindowPos) == 'function') then
        local anchored_x, anchored_y = decision.top_left(width, height);
        pcall(imgui.SetWindowPos, { anchored_x, anchored_y }, 0);
    end

    state.decision_window_width = width;
    state.decision_window_height = height;
end

function decision.render()
    local menu = state.decision_menu;
    if (state.decision_enabled[1] ~= true
        or menu == nil
        or state.decision_menu_open[1] ~= true) then
        return;
    end

    local answer = decision.guide_answer();
    local recommended = decision.recommended_index(menu, answer);
    local width = state.decision_window_width or 0;
    local height = state.decision_window_height or 0;
    local window_x, window_y = decision.top_left(width, height);
    imgui.SetNextWindowPos({ window_x, window_y }, IMGUI.cond_first_use);
    if (type(imgui.SetNextWindowSizeConstraints) == 'function') then
        imgui.SetNextWindowSizeConstraints({ 0, 0 }, { 620, 10000 });
    end
    imgui.PushStyleVar(IMGUI.style_window_padding, { 8, 6 });
    imgui.PushStyleVar(IMGUI.style_window_border_size, 1.0);
    imgui.PushStyleColor(IMGUI.col_window_bg, {
        COLORS.display_bg[1],
        COLORS.display_bg[2],
        COLORS.display_bg[3],
        bounded_number(state.decision_opacity[1], DEFAULT_SETTINGS.decision_opacity, 0, 100) / 100,
    });
    imgui.PushStyleColor(IMGUI.col_border, COLORS.display_border);

    local flags = bit.bor(
        IMGUI.window_no_title_bar,
        IMGUI.window_no_collapse,
        IMGUI.window_no_resize,
        IMGUI.window_no_scrollbar,
        IMGUI.window_no_scroll_with_mouse,
        IMGUI.window_always_auto_resize,
        IMGUI.window_no_saved_settings);
    local visible = imgui.Begin('Guide Decision###AshitaGuideDecisionMenu', state.decision_menu_open, flags);
    decision.capture_anchor(window_x, window_y);
    if (visible) then
        imgui.TextColored(COLORS.header, menu.prompt ~= '' and menu.prompt or 'Choose an option');
        imgui.Separator();
        for index, choice in ipairs(menu.choices) do
            local selected = index == menu.selected;
            local suggested = index == recommended;
            local choice_color = selected and COLORS.decision_selected
                or suggested and COLORS.decision_recommended
                or COLORS.decision_normal;
            imgui.TextColored(
                selected and COLORS.decision_selected or COLORS.decision_normal,
                selected and '>' or ' ');
            imgui.SameLine(0, 4);
            imgui.TextColored(
                suggested and COLORS.decision_recommended or COLORS.decision_normal,
                suggested and '*' or ' ');
            imgui.SameLine(0, 6);
            imgui.TextColored(
                choice_color,
                choice);
        end
    end

    imgui.End();
    imgui.PopStyleColor(2);
    imgui.PopStyleVar(2);
end

local function render_active_tabs()
    if (#state.active_order == 0) then
        imgui.TextColored(COLORS.muted, 'No active guides. Open Guide Config to start one.');
        if (imgui.Button('Open Guide Config##ashitaguide_open_config', { 150, 0 })) then
            state.config_visible[1] = true;
        end
        return;
    end

    local close_keys = {};
    for index, key in ipairs(state.active_order) do
        local run = state.active[key];
        if (run ~= nil) then
            if (index > 1) then
                imgui.SameLine(0, 3);
            end
            local selected = state.selected_active_key == key;
            imgui.PushStyleColor(IMGUI.col_button, selected and COLORS.tab_active or COLORS.tab);
            imgui.PushStyleColor(IMGUI.col_button_hovered, COLORS.tab_hover);
            imgui.PushStyleColor(IMGUI.col_button_active, COLORS.tab_active);
            imgui.PushStyleColor(IMGUI.col_text, selected and COLORS.tab_text_active or COLORS.tab_text);
            local label_width = type(imgui.CalcTextSize) == 'function'
                and tonumber(imgui.CalcTextSize(run.guide.name))
                or 100;
            local tab_width = math.max(88, math.min(170, (label_width or 100) + 18));
            if (imgui.Button(run.guide.name .. '##ashitaguide_tab_button_' .. key, { tab_width, 22 })) then
                state.selected_active_key = key;
            end
            imgui.SameLine(0, 0);
            if (imgui.Button('x##ashitaguide_tab_close_' .. key, { 22, 22 })) then
                table.insert(close_keys, key);
            end
            imgui.PopStyleColor(4);
        end
    end
    for _, key in ipairs(close_keys) do
        close_guide_tab(key);
    end
    imgui.Separator();
    render_active_guide(state.active[state.selected_active_key] or state.active[state.active_order[1]]);
end

local function push_display_window_style(opacity)
    local alpha = bounded_number(opacity[1], 92, 0, 100) / 100;
    imgui.PushStyleVar(IMGUI.style_window_padding, { 6, 4 });
    imgui.PushStyleVar(IMGUI.style_window_border_size, 1.0);
    imgui.PushStyleVar(IMGUI.style_frame_padding, { 5, 2 });
    imgui.PushStyleColor(IMGUI.col_window_bg, {
        COLORS.display_bg[1],
        COLORS.display_bg[2],
        COLORS.display_bg[3],
        alpha,
    });
    imgui.PushStyleColor(IMGUI.col_child_bg, COLORS.display_child_bg);
    imgui.PushStyleColor(IMGUI.col_border, COLORS.display_border);
end

local function push_config_window_style()
    imgui.PushStyleVar(IMGUI.style_window_padding, { 8, 8 });
    imgui.PushStyleVar(IMGUI.style_window_border_size, 1.0);
    imgui.PushStyleVar(IMGUI.style_frame_padding, { 4, 3 });
    imgui.PushStyleColor(IMGUI.col_window_bg, COLORS.panel_bg);
    imgui.PushStyleColor(IMGUI.col_child_bg, COLORS.child_bg);
    imgui.PushStyleColor(IMGUI.col_border, COLORS.border);
end

local function pop_window_style()
    imgui.PopStyleColor(3);
    imgui.PopStyleVar(3);
end

local function capture_window_geometry(x_key, y_key, width_key, height_key, min_width, max_width, min_height, max_height)
    if (type(imgui.GetWindowPos) == 'function') then
        local x, y = imgui.GetWindowPos();
        state.settings[x_key] = bounded_number(x, state.settings[x_key], 0, 10000);
        state.settings[y_key] = bounded_number(y, state.settings[y_key], 0, 10000);
    end
    if (type(imgui.GetWindowSize) == 'function') then
        local width, height = imgui.GetWindowSize();
        state.settings[width_key] = bounded_number(width, state.settings[width_key], min_width, max_width);
        state.settings[height_key] = bounded_number(height, state.settings[height_key], min_height, max_height);
    end
end

local function guide_window_top_left(width, height)
    local x = state.settings.window_x;
    local y = state.settings.window_y;
    local corner = normalize_guide_anchor_corner(state.settings.guide_anchor_corner);
    if (corner == 'top_right' or corner == 'bottom_right') then
        x = x - width;
    end
    if (corner == 'bottom_left' or corner == 'bottom_right') then
        y = y - height;
    end
    return x, y;
end

local function set_next_guide_window_position(width, height)
    local window_x, window_y = guide_window_top_left(width, height);
    imgui.SetNextWindowPos({ window_x, window_y }, IMGUI.cond_first_use);
    return window_x, window_y;
end

local function capture_guide_window_anchor(expected_x, expected_y)
    if (type(imgui.GetWindowPos) ~= 'function' or type(imgui.GetWindowSize) ~= 'function') then
        return;
    end

    local x, y = imgui.GetWindowPos();
    local width, height = imgui.GetWindowSize();
    x = tonumber(x) or expected_x;
    y = tonumber(y) or expected_y;
    width = tonumber(width) or state.guide_window_width or 0;
    height = tonumber(height) or state.guide_window_height or 0;

    -- Preserve the configured anchor while auto-resize changes the opposite edges.
    -- A position delta means the player dragged or ImGui clamped the window, so
    -- capture the newly chosen anchor using the freshly measured size.
    if (math.abs(x - expected_x) > 0.5 or math.abs(y - expected_y) > 0.5) then
        local corner = normalize_guide_anchor_corner(state.settings.guide_anchor_corner);
        state.settings.window_x = bounded_number(
            x + ((corner == 'top_right' or corner == 'bottom_right') and width or 0),
            state.settings.window_x,
            0,
            10000);
        state.settings.window_y = bounded_number(
            y + ((corner == 'bottom_left' or corner == 'bottom_right') and height or 0),
            state.settings.window_y,
            0,
            10000);
    end

    -- Correct the position during the same frame that auto-resize changes the
    -- measured size. This keeps the configured corner visually stationary.
    if (type(imgui.SetWindowPos) == 'function') then
        local anchored_x, anchored_y = guide_window_top_left(width, height);
        pcall(imgui.SetWindowPos, { anchored_x, anchored_y }, 0);
    end

    state.guide_window_width = width;
    state.guide_window_height = height;
end

local function render_guide_window()
    if (state.visible[1] ~= true) then
        return;
    end

    local width = state.guide_window_width or 0;
    local height = state.guide_window_height or 0;
    local window_x, window_y = set_next_guide_window_position(width, height);
    if (type(imgui.SetNextWindowSizeConstraints) == 'function') then
        imgui.SetNextWindowSizeConstraints({ 0, 0 }, { GUIDE_WINDOW_MAX_WIDTH, 10000 });
    end
    push_display_window_style(state.guide_opacity);
    local flags = bit.bor(
        IMGUI.window_no_title_bar,
        IMGUI.window_no_collapse,
        IMGUI.window_no_resize,
        IMGUI.window_no_scrollbar,
        IMGUI.window_no_scroll_with_mouse,
        IMGUI.window_always_auto_resize,
        IMGUI.window_no_saved_settings);
    local visible = imgui.Begin(string.format('Guides v%s###AshitaGuideGuides', addon.version), state.visible, flags);
    capture_guide_window_anchor(window_x, window_y);
    if (visible) then
        render_active_tabs();
    end
    imgui.End();
    pop_window_style();
end

local function render_valor_window()
    if (state.valor_enabled[1] ~= true
        or state.pov_active ~= true
        or state.valor_visible[1] ~= true
        or state.pov_run == nil) then
        return;
    end

    imgui.SetNextWindowPos(
        { state.settings.valor_window_x, state.settings.valor_window_y },
        IMGUI.cond_first_use);
    imgui.SetNextWindowSize(
        { state.settings.valor_window_width, state.settings.valor_window_height },
        IMGUI.cond_first_use);
    push_display_window_style(state.valor_opacity);
    local flags = bit.bor(IMGUI.window_no_title_bar, IMGUI.window_no_collapse);
    local visible = imgui.Begin('Pages of Valor###AshitaGuideValor', state.valor_visible, flags);
    capture_window_geometry(
        'valor_window_x',
        'valor_window_y',
        'valor_window_width',
        'valor_window_height',
        220,
        600,
        80,
        400);
    if (visible) then
        render_pov_panel(state.pov_run);
    end
    imgui.End();
    pop_window_style();
end

local function casket_candidate_map()
    local map = {};
    for _, candidate in ipairs((state.casket or {}).candidates or {}) do
        map[candidate] = true;
    end
    return map;
end

local function render_casket_code_cell(value, possible, best)
    local button_color = COLORS.casket_impossible;
    local hover_color = COLORS.casket_impossible_hover;
    local active_color = COLORS.casket_impossible_hover;
    local text_color = COLORS.muted;

    if (best == true) then
        button_color = COLORS.casket_best;
        hover_color = COLORS.casket_best_hover;
        active_color = COLORS.casket_best_hover;
        text_color = COLORS.casket_dark_text;
    elseif (possible == true) then
        button_color = COLORS.casket_possible;
        hover_color = COLORS.casket_possible_hover;
        active_color = COLORS.casket_possible_hover;
        text_color = COLORS.casket_dark_text;
    end

    imgui.PushStyleColor(IMGUI.col_button, button_color);
    imgui.PushStyleColor(IMGUI.col_button_hovered, hover_color);
    imgui.PushStyleColor(IMGUI.col_button_active, active_color);
    imgui.PushStyleColor(IMGUI.col_text, text_color);
    imgui.Button(string.format('%02d##ashitaguide_casket_code_%02d', value, value), { 36, 22 });
    imgui.PopStyleColor(4);
end

local function render_casket_grid(analysis)
    local possible = casket_candidate_map();
    for row = 1, 9 do
        for column = 0, 9 do
            local value = (row * 10) + column;
            render_casket_code_cell(value, possible[value] == true, analysis.best == value);
            if (column < 9) then
                imgui.SameLine(0, 4);
            end
        end
    end
end

local function render_casket_hints()
    local clues = (state.casket or {}).clues or {};
    if (#clues == 0) then
        imgui.TextColored(COLORS.muted, 'No hints yet.');
        return;
    end

    local child_open, child_visible = begin_child(
        '##ashitaguide_casket_hints',
        { state.settings.casket_window_width - 26, 118 },
        true);
    if (child_visible) then
        for index, clue in ipairs(clues) do
            text_wrapped(string.format('%d. %s', index, clue.message or 'hint'));
        end
    end
    if (child_open) then
        imgui.EndChild();
    end
end

local function render_casket_window()
    if (state.casket_enabled[1] ~= true
        or state.casket == nil
        or state.casket.active ~= true
        or state.casket_visible[1] ~= true) then
        return;
    end

    imgui.SetNextWindowPos(
        { state.settings.casket_window_x, state.settings.casket_window_y },
        IMGUI.cond_first_use);
    imgui.SetNextWindowSize(
        { state.settings.casket_window_width, state.settings.casket_window_height },
        IMGUI.cond_first_use);
    push_display_window_style(state.casket_opacity);
    local flags = bit.bor(IMGUI.window_no_title_bar, IMGUI.window_no_collapse);

    local visible = imgui.Begin('Casket Helper###AshitaGuideCasket', state.casket_visible, flags);
    capture_window_geometry(
        'casket_window_x',
        'casket_window_y',
        'casket_window_width',
        'casket_window_height',
        430,
        900,
        280,
        800);
    if (visible) then
        local analysis = casket_analyze(state.casket);
        imgui.TextColored(COLORS.header, 'Brown Casket');
        imgui.SameLine(0, 12);
        if (imgui.Button('Reset##ashitaguide_casket_reset', { 86, 0 })) then
            reset_casket_inactive();
        else
            imgui.Text(casket_best_summary(analysis));
            imgui.Text(string.format('Possible: %d', analysis.count));
            imgui.Separator();
            render_casket_grid(analysis);
            imgui.Separator();
            imgui.TextColored(COLORS.header, 'Hints');
            render_casket_hints();
        end
    end
    imgui.End();
    pop_window_style();
end

local function render_config_window()
    if (state.config_visible[1] ~= true) then
        return;
    end

    imgui.SetNextWindowPos(
        { state.settings.config_window_x, state.settings.config_window_y },
        IMGUI.cond_first_use);
    imgui.SetNextWindowSize(
        { state.settings.config_window_width, state.settings.config_window_height },
        IMGUI.cond_first_use);
    push_config_window_style();
    local visible = imgui.Begin('Guide Config###AshitaGuideConfig', state.config_visible, IMGUI.window_no_collapse);
    capture_window_geometry(
        'config_window_x',
        'config_window_y',
        'config_window_width',
        'config_window_height',
        260,
        600,
        320,
        1000);
    if (visible) then
        if (state.config_error ~= nil) then
            text_colored_wrapped(COLORS.warning, 'Config warning: ' .. state.config_error);
            imgui.Separator();
        end
        if (type(imgui.BeginTabBar) == 'function'
            and type(imgui.BeginTabItem) == 'function'
            and type(imgui.EndTabItem) == 'function'
            and type(imgui.EndTabBar) == 'function') then
            if (imgui.BeginTabBar('##ashitaguide_config_tabs')) then
                if (imgui.BeginTabItem('Guides##ashitaguide_config_guides')) then
                    render_guide_selector();
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Decision Window##ashitaguide_config_decision')) then
                    decision.render_config();
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('AI Guides##ashitaguide_config_ai_guides')) then
                    render_ai_guide_config();
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Auction Sales##ashitaguide_config_auction_sales')) then
                    render_auction_sale_config();
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Valor##ashitaguide_config_valor')) then
                    render_valor_config();
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Casket##ashitaguide_config_casket')) then
                    render_casket_config();
                    imgui.EndTabItem();
                end
                imgui.EndTabBar();
            end
        else
            render_guide_selector();
            imgui.Separator();
            decision.render_config();
            imgui.Separator();
            render_ai_guide_config();
            imgui.Separator();
            render_auction_sale_config();
            imgui.Separator();
            render_valor_config();
            imgui.Separator();
            render_casket_config();
        end
    end
    imgui.End();
    pop_window_style();
end

local function args_tail(args, start_index)
    local parts = {};
    for index = start_index, #args do
        if (args[index] ~= nil) then
            table.insert(parts, tostring(args[index]));
        end
    end
    return table.concat(parts, ' ');
end

local function print_help()
    log_info('Commands:');
    log_info('/agguide show | hide | toggle');
    log_info('/agguide config [show | hide | toggle]');
    log_info('/agguide start <guide> | stop <guide> | select <guide>');
    log_info('/agguide next [guide] | back [guide]');
    log_info('/agguide list | status | mapdebug | reload');
end

local function print_list()
    for index, guide in ipairs(state.guides) do
        local active = state.active[guide.key] ~= nil and 'active' or 'available';
        log_info(string.format('%d. %s (%s) [%s]', index, guide.name, guide.key, active));
    end
end

local function print_status()
    log_info(string.format(
        'visible=%s configVisible=%s guides=%d active=%d selected=%s textEvents=%d logEvents=%d',
        tostring(state.visible[1]),
        tostring(state.config_visible[1]),
        #state.guides,
        #state.active_order,
        tostring(state.selected_active_key or 'none'),
        state.observed_text_events,
        state.observed_log_events));
end

local function print_minimap_debug()
    local debug = state.minimap.debug;
    if (debug == nil) then
        log_warn('Minimap debug is unavailable; show an active guide step with a map destination first.');
        return;
    end
    log_info(string.format(
        'MapDebug world: player=(%.3f,%.3f) yaw=%.4f target=(%.3f,%.3f) index=%d delta=(%.3f,%.3f).',
        debug.player_x,
        debug.player_y,
        debug.player_yaw,
        debug.target_x,
        debug.target_y,
        debug.target_index,
        debug.delta_x,
        debug.delta_y));
    log_info(string.format(
        'MapDebug live: runtime=%s center=(%.2f,%.2f) zoom=%.3f scale=(%.3f,%.3f) mask=(%.1f,%.1f) mapScaleByte=%d rotateMap=%s rotateFrame=%s.',
        tostring(debug.runtime_address or 'none'),
        debug.center_x,
        debug.center_y,
        debug.zoom,
        debug.scale_x,
        debug.scale_y,
        debug.mask_width,
        debug.mask_height,
        debug.map_scale_raw,
        tostring(debug.rotate_map),
        tostring(debug.rotate_frame)));
    log_info(string.format(
        'MapDebug pixels: transformed=(%.3f,%.3f) pxPerYalm=(%.3f,%.3f) marker=(%.2f,%.2f).',
        debug.transformed_x,
        debug.transformed_y,
        debug.pixels_per_yalm_x,
        debug.pixels_per_yalm_y,
        debug.marker_x,
        debug.marker_y));
end

local function handle_command(e)
    local args = e.command:args();
    local name = args[1] and args[1]:lower() or '';
    if (commands[name] ~= true) then
        return;
    end

    e.blocked = true;
    local action = args[2] and args[2]:lower() or 'help';

    if (action == 'show') then
        state.visible[1] = true;
        return;
    elseif (action == 'hide') then
        state.visible[1] = false;
        return;
    elseif (action == 'toggle') then
        state.visible[1] = not state.visible[1];
        return;
    elseif (action == 'config') then
        local mode = args[3] and args[3]:lower() or 'toggle';
        if (mode == 'show') then
            state.config_visible[1] = true;
        elseif (mode == 'hide') then
            state.config_visible[1] = false;
        elseif (mode == 'toggle') then
            state.config_visible[1] = not state.config_visible[1];
        else
            log_warn('Usage: /agguide config [show | hide | toggle]');
        end
        return;
    elseif (action == 'start' or action == 'add') then
        local guide = find_guide(args_tail(args, 3));
        if (guide == nil) then
            log_warn('Guide not found. Use /agguide list.');
            return;
        end
        start_guide(guide);
        log_info('Started ' .. guide.name .. '.');
        return;
    elseif (action == 'stop' or action == 'remove') then
        local run = current_run(args_tail(args, 3));
        if (run == nil) then
            log_warn('Active guide not found.');
            return;
        end
        stop_guide(run.key);
        log_info('Stopped ' .. run.guide.name .. '.');
        return;
    elseif (action == 'select' or action == 'focus') then
        local guide = find_guide(args_tail(args, 3));
        if (guide == nil or state.active[guide.key] == nil) then
            log_warn('Active guide not found.');
            return;
        end
        state.selected_active_key = guide.key;
        state.selected_guide_key = guide.key;
        return;
    elseif (action == 'next') then
        local run = current_run(args_tail(args, 3));
        next_step(run);
        return;
    elseif (action == 'back' or action == 'prev' or action == 'previous') then
        local run = current_run(args_tail(args, 3));
        previous_step(run);
        return;
    elseif (action == 'list') then
        print_list();
        return;
    elseif (action == 'status') then
        print_status();
        return;
    elseif (action == 'mapdebug') then
        print_minimap_debug();
        return;
    elseif (action == 'reload') then
        load_config();
        seed_chat_log();
        log_info('Reloaded ashitaguide_config.lua.');
        if (state.config_error ~= nil) then
            log_warn('Config warning: ' .. state.config_error);
        end
        return;
    elseif (action == 'help') then
        print_help();
        return;
    end

    print_help();
end

local function handle_text_in(e)
    if (e.blocked or e.injected == true) then
        return;
    end

    local candidates = {
        e.message,
        e.message_modified,
        e.modified_message,
    };
    local seen = {};
    for _, message in ipairs(candidates) do
        local text = clean_message(message);
        if (text ~= '' and seen[text] ~= true) then
            seen[text] = true;
            process_observed_text(text, 'text', e.mode, e.mode_modified);
        end
    end
end

ashita.events.register('load', 'load_cb', function ()
    load_config();
    seed_chat_log();
    if (state.decision_hide_native_chat[1] == true and not decision.find_legacy_chat_windows()) then
        log_warn('Native chat hiding is unavailable: ' .. state.native_chat_pointer_error .. '.');
    end
    log_info('Loaded. Use /agguide show and /agguide list.');
    if (state.config_error ~= nil) then
        log_warn('Config warning: ' .. state.config_error);
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    state.save_pov_state_if_needed(true);
    save_settings_if_needed(true);
    state.visible[1] = false;
    state.config_visible[1] = false;
end);

ashita.events.register('command', 'command_cb', function (e)
    handle_command(e);
end);

ashita.events.register('text_in', 'text_in_cb', function (e)
    handle_text_in(e);
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    state.restore_persisted_pov_state_if_needed();
    poll_chat_log();
    poll_ai_guides_file();
    poll_auction_sale_guide_file();
    update_npc_step_auto_advance();
    update_level_step_auto_advance();
    decision.update();
    decision.pin_legacy_chat_closed();
    render_minimap_destination_marker();
    render_guide_window();
    decision.render();
    render_valor_window();
    render_casket_window();
    render_config_window();
    state.save_pov_state_if_needed(false);
    save_settings_if_needed(false);
end);
