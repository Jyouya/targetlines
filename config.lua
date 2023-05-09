local imgui = require('imgui');
local settings = require('settings');

local defaultSettings = T {
    filter = 'All'
};

local s = settings.load(defaultSettings);

local filters = T {
    'All',
    'Alliance',
    'Party'
};

local showConfig = { false };
local config = T {};

config.drawWindow = function()
    if (showConfig[1]) then
        imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0.06, .16, .9 });
        imgui.PushStyleColor(ImGuiCol_TitleBg, { 0, 0.06, .16, .7 });
        imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0, 0.06, .16, .9 });
        imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, { 0, 0.06, .16, .5 });
        imgui.PushStyleColor(ImGuiCol_Header, { 0, 0.06, .16, .7 });
        imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0, 0.06, .16, .9 });
        imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0, 0.06, .16, 1 });
        imgui.PushStyleColor(ImGuiCol_FrameBg, { 0, 0.06, .16, 1 });
        imgui.SetNextWindowSize({ 400, 150 }, ImGuiCond_FirstUseEver);

        if (imgui.Begin(('Targetlines Config'):fmt(addon.version), showConfig, bit.bor(ImGuiWindowFlags_NoSavedSettings))) then
            imgui.BeginChild("Config Options", { 0, 0 }, true);
            if (imgui.BeginCombo('Filters', s.filter)) then
                for i = 1, 3 do
                    local isSelected = i == s.filter;

                    if (imgui.Selectable(filters[i], isSelected) and filters[i] ~= s.filter) then
                        s.filter = filters[i];
                        settings.save();
                    end

                    if (isSelected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            imgui.EndChild();
        end
    end
end

ashita.events.register('command', 'command_cb', function(e)
    -- Parse the command arguments
    local command_args = e.command:lower():args()
    if table.contains({ '/targetlines' }, command_args[1]) then
        -- Toggle the config menu
        showConfig[1] = not showConfig[1];
        e.blocked = true;
    end
end);

ashita.events.register('d3d_present', 'config_cb', function()
    config.drawWindow();
end);

return config;
