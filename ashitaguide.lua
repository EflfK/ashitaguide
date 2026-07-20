addon.name    = 'ashitaguide';
addon.author  = 'EflfK';
addon.version = '0.14.0';
addon.desc    = 'Manual configuration-driven quest and page guide helper for Ashita.';

require('common');

local chat  = require('chat');
local imgui = require('imgui');
local ffi   = require('ffi');
local d3d8  = require('d3d8');
local d3d8_device = d3d8.get_device();

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

local DEFAULT_SETTINGS = {
    visible = true,
    window_x = 420,
    window_y = 160,
    window_width = 560,
    window_height = 540,
    guide_show_step_list = true,
    guide_map_size = 160,
    guide_opacity = 92,
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
    chat_log_seed_lines = 700,
    poll_chat_log = true,
    default_active_guides = {},
};

local commands = {
    ['/agguide'] = true,
    ['/ashitaguide'] = true,
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
    guide_opacity = T{ 92 },
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
    pov_run = nil,
    pov_active = false,
    casket = nil,
    settings_observed_text = nil,
    settings_saved_text = nil,
    settings_pending_at = 0,
    settings_last_poll = 0,
    settings_save_error = nil,
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

local function log_info(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function log_warn(message)
    print(chat.header(addon.name):append(chat.warning(message)));
end

local function text_wrapped(text)
    text = tostring(text or '');
    if (type(imgui.TextWrapped) == 'function') then
        imgui.TextWrapped(text);
        return;
    end
    if (type(imgui.PushTextWrapPos) == 'function' and type(imgui.PopTextWrapPos) == 'function') then
        imgui.PushTextWrapPos(0.0);
        imgui.Text(text);
        imgui.PopTextWrapPos();
        return;
    end
    imgui.Text(text);
end

local function text_colored_wrapped(color, text)
    if (type(imgui.PushTextWrapPos) == 'function' and type(imgui.PopTextWrapPos) == 'function') then
        imgui.PushTextWrapPos(0.0);
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

local function matrix_multiply(left, right)
    return ffi.new('D3DXMATRIX', {
        left._11 * right._11 + left._12 * right._21 + left._13 * right._31 + left._14 * right._41,
        left._11 * right._12 + left._12 * right._22 + left._13 * right._32 + left._14 * right._42,
        left._11 * right._13 + left._12 * right._23 + left._13 * right._33 + left._14 * right._43,
        left._11 * right._14 + left._12 * right._24 + left._13 * right._34 + left._14 * right._44,
        left._21 * right._11 + left._22 * right._21 + left._23 * right._31 + left._24 * right._41,
        left._21 * right._12 + left._22 * right._22 + left._23 * right._32 + left._24 * right._42,
        left._21 * right._13 + left._22 * right._23 + left._23 * right._33 + left._24 * right._43,
        left._21 * right._14 + left._22 * right._24 + left._23 * right._34 + left._24 * right._44,
        left._31 * right._11 + left._32 * right._21 + left._33 * right._31 + left._34 * right._41,
        left._31 * right._12 + left._32 * right._22 + left._33 * right._32 + left._34 * right._42,
        left._31 * right._13 + left._32 * right._23 + left._33 * right._33 + left._34 * right._43,
        left._31 * right._14 + left._32 * right._24 + left._33 * right._34 + left._34 * right._44,
        left._41 * right._11 + left._42 * right._21 + left._43 * right._31 + left._44 * right._41,
        left._41 * right._12 + left._42 * right._22 + left._43 * right._32 + left._44 * right._42,
        left._41 * right._13 + left._42 * right._23 + left._43 * right._33 + left._44 * right._43,
        left._41 * right._14 + left._42 * right._24 + left._43 * right._34 + left._44 * right._44,
    });
end

local function transform_vector(vector, matrix)
    return ffi.new('D3DXVECTOR4', {
        matrix._11 * vector.x + matrix._21 * vector.y + matrix._31 * vector.z + matrix._41 * vector.w,
        matrix._12 * vector.x + matrix._22 * vector.y + matrix._32 * vector.z + matrix._42 * vector.w,
        matrix._13 * vector.x + matrix._23 * vector.y + matrix._33 * vector.z + matrix._43 * vector.w,
        matrix._14 * vector.x + matrix._24 * vector.y + matrix._34 * vector.z + matrix._44 * vector.w,
    });
end

local function world_to_screen(x, z, y)
    if (d3d8_device == nil) then
        return nil;
    end
    local _, view = d3d8_device:GetTransform(ffi.C.D3DTS_VIEW);
    local _, projection = d3d8_device:GetTransform(ffi.C.D3DTS_PROJECTION);
    local _, viewport = d3d8_device:GetViewport();
    if (view == nil or projection == nil or viewport == nil) then
        return nil;
    end

    local camera = transform_vector(
        ffi.new('D3DXVECTOR4', { x, z, y, 1 }),
        matrix_multiply(view, projection));
    if (camera.w == 0) then
        return nil;
    end
    local reciprocal = 1 / camera.w;
    local ndc_x = camera.x * reciprocal;
    local ndc_y = camera.y * reciprocal;
    local ndc_z = camera.z * reciprocal;
    local screen_x = math.floor((ndc_x + 1) * 0.5 * viewport.Width);
    local screen_y = math.floor((1 - ndc_y) * 0.5 * viewport.Height);
    if (ndc_z < 0 or ndc_z > 1
        or screen_x < 0 or screen_x > viewport.Width
        or screen_y < 0 or screen_y > viewport.Height) then
        return nil;
    end
    return screen_x, screen_y;
end

local function current_chat_log_path()
    local memory = safe_read(function () return AshitaCore:GetMemoryManager(); end, nil);
    local party = memory ~= nil and safe_read(function () return memory:GetParty(); end, nil) or nil;
    local character = party ~= nil and clean_message(safe_read(function () return party:GetMemberName(0); end, '')) or '';
    if (character == '') then
        return nil;
    end

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
        advance_on_target = bounded_boolean(
            source.advance_on_target or source.auto_advance_on_target,
            false),
    };
end

local function normalize_guide(source, index)
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
        window_width = bounded_number(source.window_width, DEFAULT_SETTINGS.window_width, 520, 1400),
        window_height = bounded_number(source.window_height, DEFAULT_SETTINGS.window_height, 360, 1000),
        guide_show_step_list = bounded_boolean(source.guide_show_step_list, DEFAULT_SETTINGS.guide_show_step_list),
        guide_map_size = bounded_number(source.guide_map_size, DEFAULT_SETTINGS.guide_map_size, 120, 260),
        guide_opacity = bounded_number(source.guide_opacity, legacy_opacity, 0, 100),
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
        chat_log_seed_lines = bounded_number(source.chat_log_seed_lines, DEFAULT_SETTINGS.chat_log_seed_lines, 0, 5000),
        poll_chat_log = bounded_boolean(source.poll_chat_log, DEFAULT_SETTINGS.poll_chat_log),
        default_active_guides = copy_array(source.default_active_guides or DEFAULT_SETTINGS.default_active_guides),
    };
end

local function guide_is_configurable(guide)
    return guide ~= nil and guide.type ~= 'pages_of_valor';
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

local function casket_parse_message(message)
    local original = clean_message(message);
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

local function process_casket_text(text, source)
    if (state.casket_enabled[1] ~= true or source == 'seed') then
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

    casket_apply_event(state.casket, event);
    state.casket.active = true;
    state.casket.updated_at = now;
    state.casket.last_event = event;
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
    run.step_index = bounded_number(run.step_index, 1, 1, #guide.steps);
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
end

local function previous_step(run)
    if (run == nil) then
        return;
    end
    run.step_index = math.max(1, (tonumber(run.step_index) or 1) - 1);
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
    state.config_error = config_error or settings_error;
    state.settings = normalize_settings(merge_tables(config.settings, persisted_settings));
    state.visible[1] = state.settings.visible;
    state.config_visible[1] = state.settings.config_visible;
    state.valor_enabled[1] = state.settings.valor_enabled;
    state.valor_show_zone[1] = state.settings.valor_show_zone;
    state.valor_show_totals[1] = state.settings.valor_show_totals;
    state.casket_enabled[1] = state.settings.casket_enabled;
    state.guide_show_step_list[1] = state.settings.guide_show_step_list;
    state.guide_map_size[1] = state.settings.guide_map_size;
    state.guide_opacity[1] = state.settings.guide_opacity;
    state.valor_opacity[1] = state.settings.valor_opacity;
    state.casket_opacity[1] = state.settings.casket_opacity;
    state.casket_stale_seconds[1] = state.settings.casket_stale_seconds;
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
            local guide = normalize_guide(source, index);
            guides_by_key[guide.key] = guide;
            table.insert(guides, guide);
        end
    end

    if (type(config.guides) == 'table') then
        for index, source in ipairs(config.guides) do
            local guide = normalize_guide(source, index + #guides);
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

    state.guides = guides;
    state.guide_by_key = guides_by_key;
    state.categories = category_catalog(guides);
    state.active = {};
    state.active_order = {};

    local desired_order = #previous_order > 0 and previous_order or state.settings.default_active_guides;
    for _, key in ipairs(desired_order) do
        local guide = state.guide_by_key[key];
        if (guide ~= nil and guide.type ~= 'pages_of_valor') then
            start_guide(guide, previous_active[key]);
        end
    end

    local pov_guide = state.guide_by_key.pages_of_valor;
    if (pov_guide ~= nil) then
        state.pov_run = create_run(pov_guide, previous_pov_run);
    else
        state.pov_run = nil;
    end

    state.selected_active_key = previous_selected_active;
    if (state.selected_active_key == nil or state.active[state.selected_active_key] == nil) then
        state.selected_active_key = state.active_order[1];
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

local function settings_text()
    local values = state.settings;
    local lines = {
        'return {',
        string.format('    visible = %s,', lua_boolean(state.visible[1])),
        string.format('    window_x = %d,', bounded_number(values.window_x, DEFAULT_SETTINGS.window_x, 0, 10000)),
        string.format('    window_y = %d,', bounded_number(values.window_y, DEFAULT_SETTINGS.window_y, 0, 10000)),
        string.format('    window_width = %d,', bounded_number(values.window_width, DEFAULT_SETTINGS.window_width, 520, 1400)),
        string.format('    window_height = %d,', bounded_number(values.window_height, DEFAULT_SETTINGS.window_height, 360, 1000)),
        string.format('    guide_show_step_list = %s,', lua_boolean(state.guide_show_step_list[1])),
        string.format('    guide_map_size = %d,', bounded_number(state.guide_map_size[1], DEFAULT_SETTINGS.guide_map_size, 120, 260)),
        string.format('    guide_opacity = %d,', bounded_number(state.guide_opacity[1], DEFAULT_SETTINGS.guide_opacity, 0, 100)),
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
        string.format('    chat_log_seed_lines = %d,', bounded_number(values.chat_log_seed_lines, DEFAULT_SETTINGS.chat_log_seed_lines, 0, 5000)),
        string.format('    poll_chat_log = %s,', lua_boolean(values.poll_chat_log)),
        string.format('    default_active_guides = %s,', lua_string_list(state.active_order)),
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

local function update_designated_progress(run, current, total)
    local pov = run.pov;
    local page = current_pov_page(run);
    if (page == nil) then
        return;
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
    local defeated_name = text:match('defeats the ([^%.]+)%.');
    if (defeated_name ~= nil) then
        pov.last_defeated_name = trim_string(defeated_name);
        pov.last_defeated_time = os.clock();
    end
    local area = extract_area(text);
    if (area ~= '') then
        pov.zone = area;
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

local function process_observed_text(text, source)
    local cleaned = clean_message(text);
    if (cleaned == '') then
        return false;
    end

    local handled = process_casket_text(cleaned, source);
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
    imgui.Checkbox('Show step list##ashitaguide_guide_show_step_list', state.guide_show_step_list);
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
        if (imgui.Button('Reset##ashitaguide_casket_reset', { 86, 0 })) then
            reset_casket_inactive();
        end
        local analysis = casket_analyze(state.casket);
        imgui.SameLine(0, 8);
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
        imgui.TextColored(COLORS.muted, table.concat(parts, '  |  '));
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
    return { x = x, y = y, yaw = yaw, zone = zone_name, entity = entity };
end

local function find_navigation_target(entity, npc)
    local lookup = lower_string(npc);
    if (entity == nil or lookup == '') then
        return nil;
    end

    local now = os.clock();
    local cached = state.navigation_targets[lookup];
    if (cached ~= nil and now - cached.checked_at < 0.25) then
        return cached;
    end

    local result = { checked_at = now };
    local count = tonumber(safe_read(function () return entity:GetEntityMapSize(); end, 0)) or 0;
    for index = 0, count - 1 do
        local name = clean_message(safe_read(function () return entity:GetName(index); end, ''));
        if (name ~= '' and name:lower() == lookup) then
            local x = tonumber(safe_read(function () return entity:GetLocalPositionX(index); end, nil));
            local y = tonumber(safe_read(function () return entity:GetLocalPositionY(index); end, nil));
            local z = tonumber(safe_read(function () return entity:GetLocalPositionZ(index); end, nil));
            if (x ~= nil and y ~= nil) then
                result.x = x;
                result.y = y;
                result.z = z;
                result.index = index;
                result.rendered = bit.band(
                    tonumber(safe_read(function () return entity:GetRenderFlags0(index); end, 0)) or 0,
                    0x200) == 0x200;
                result.name = name;
                break;
            end
        end
    end
    state.navigation_targets[lookup] = result;
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
    local sub_active = safe_read(function () return target:GetIsSubTargetActive(); end, false);
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

local function render_npc_world_marker()
    local run = state.active[state.selected_active_key];
    local step = run ~= nil and run.guide.steps[run.step_index] or nil;
    if (step == nil or step.npc == '') then
        return;
    end

    local player = current_navigation_player();
    if (player == nil
        or (step.zone ~= '' and lower_string(player.zone) ~= lower_string(step.zone))) then
        return;
    end
    local target = find_navigation_target(player.entity, step.npc);
    if (target == nil or target.rendered ~= true or target.z == nil) then
        return;
    end

    local screen_x, screen_y = world_to_screen(target.x, target.z - 2.5, target.y);
    if (screen_x == nil or screen_y == nil) then
        return;
    end

    local marker_width = 64;
    local marker_height = 58;
    local bob = math.sin(os.clock() * 4) * 3;
    local tip_y = screen_y - 2 + bob;
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
    imgui.SetNextWindowPos({ screen_x - (marker_width / 2), screen_y - marker_height }, 0);
    imgui.SetNextWindowSize({ marker_width, marker_height }, 0);
    if (type(imgui.SetNextWindowBgAlpha) == 'function') then
        imgui.SetNextWindowBgAlpha(0.0);
    end
    if (imgui.Begin('##ashitaguide_npc_world_marker', true, flags)) then
        local draw_list = imgui.GetWindowDrawList();
        local shadow = imgui.GetColorU32({ 0.02, 0.02, 0.02, 0.78 });
        local color = imgui.GetColorU32(COLORS.header);
        draw_list:AddTriangleFilled(
            { screen_x + 2, tip_y + 2 },
            { screen_x - 9, tip_y - 15 },
            { screen_x + 13, tip_y - 15 },
            shadow);
        draw_list:AddTriangleFilled(
            { screen_x, tip_y },
            { screen_x - 11, tip_y - 17 },
            { screen_x + 11, tip_y - 17 },
            color);
    end
    imgui.End();
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

    local live_target = find_navigation_target(player.entity, step.npc);
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
    local world_radius = math.max(20, distance * 1.15);
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
    local height = math.min(132, 12 + (#run.guide.steps * 20));
    local child_open, child_visible = begin_child('##ashitaguide_step_list_' .. run.key, { 0, height }, true);
    if (child_visible) then
        for index, step in ipairs(run.guide.steps) do
            local prefix = index == run.step_index and '> ' or '  ';
            local label = step.title ~= '' and step.title or step.text;
            if (index == run.step_index) then
                imgui.TextColored(COLORS.accent, string.format('%s%d. %s', prefix, index, label));
            else
                imgui.TextColored(COLORS.muted, string.format('%s%d. %s', prefix, index, label));
            end
        end
    end
    if (child_open) then
        imgui.EndChild();
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
        stop_guide(key);
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

local function render_guide_window()
    if (state.visible[1] ~= true) then
        return;
    end

    imgui.SetNextWindowPos({ state.settings.window_x, state.settings.window_y }, IMGUI.cond_first_use);
    imgui.SetNextWindowSize({ state.settings.window_width, state.settings.window_height }, IMGUI.cond_first_use);
    push_display_window_style(state.guide_opacity);
    local flags = bit.bor(IMGUI.window_no_title_bar, IMGUI.window_no_collapse);
    local visible = imgui.Begin(string.format('Guides v%s###AshitaGuideGuides', addon.version), state.visible, flags);
    capture_window_geometry('window_x', 'window_y', 'window_width', 'window_height', 520, 1400, 360, 1000);
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
        imgui.Text(casket_best_summary(analysis));
        imgui.Text(string.format('Possible: %d', analysis.count));
        imgui.Separator();
        render_casket_grid(analysis);
        imgui.Separator();
        imgui.TextColored(COLORS.header, 'Hints');
        render_casket_hints();
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
    log_info('/agguide list | status | reload');
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
            process_observed_text(text, 'text');
        end
    end
end

ashita.events.register('load', 'load_cb', function ()
    load_config();
    seed_chat_log();
    log_info('Loaded. Use /agguide show and /agguide list.');
    if (state.config_error ~= nil) then
        log_warn('Config warning: ' .. state.config_error);
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
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
    poll_chat_log();
    update_npc_step_auto_advance();
    render_npc_world_marker();
    render_guide_window();
    render_valor_window();
    render_casket_window();
    render_config_window();
    save_settings_if_needed(false);
end);
