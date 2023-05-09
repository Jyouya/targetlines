addon.name    = 'targetlines';
addon.author  = 'Jyouya';
addon.version = '1.1';
addon.desc    = 'FFXII style target lines';

require('common');

local drawArc     = require('drawArc');
local arcs        = require('tracker');
local helpers     = require('helpers');

local color       = T {
    player = 0xFF0088FF,
    enemy = 0xFFFF1133,
    playerFriendly = 0xFF00FF66,
    enemyFriendly = 0xFFFF8800
};
-- pet color 0xFFFF00AA

local timeouts    = T {
    player = 10,
    enemy = 10,
    playerFriendly = 5,
    enemyFriendly = 5
};

ashita.events.register('load', 'load_cb', function()
    ashita.events.register('d3d_present', 'present_cb', function()
        for src, v in pairs(arcs) do
            local dTime = os.clock() - v.clock;
            local timeout = timeouts[v.color];

            local dFirstTime = v.firstClock and os.clock() - v.firstClock;

            local lineType = arcs[src].color;

            if (dTime > timeout) then
                arcs[src] = nil;
            elseif (lineType == 'player' and dFirstTime and dFirstTime > 2.5) then
                local entity = AshitaCore:GetMemoryManager():GetEntity();

                local srcPointer = entity:GetActorPointer(src);
                local x2, y2, z2 = helpers.getBone(srcPointer, 2);
                z2 = (ashita.memory.read_float(srcPointer + 0x67C) + z2) / 2;

                local dstPointer = entity:GetActorPointer(v.dst);

                local x1, y1, z1 = helpers.getBone(dstPointer, 2);
                z1 = (ashita.memory.read_float(dstPointer + 0x67C) + z1) / 2;

                local t = math.max((3- dFirstTime) * 2, 0);

                if (t > 0) then
                    drawArc(x1, y1, z1, x2, y2, z2, color[v.color], t);
                end
            elseif (dTime > timeout - 0.5) then
                local entity = AshitaCore:GetMemoryManager():GetEntity();

                local srcPointer = entity:GetActorPointer(src);
                local x2, y2, z2 = helpers.getBone(srcPointer, 2);
                z2 = (ashita.memory.read_float(srcPointer + 0x67C) + z2) / 2;

                local dstPointer = entity:GetActorPointer(v.dst);

                local x1, y1, z1 = helpers.getBone(dstPointer, 2);
                z1 = (ashita.memory.read_float(dstPointer + 0x67C) + z1) / 2;

                local t = math.min(1 - (0.5 - math.min(timeout - dTime, 1)) * 2, 1);

                drawArc(x1, y1, z1, x2, y2, z2, color[v.color], t);
            else
                local entity = AshitaCore:GetMemoryManager():GetEntity();

                local srcPointer = entity:GetActorPointer(src);
                local x1, y1, z1 = helpers.getBone(srcPointer, 2);
                z1 = (ashita.memory.read_float(srcPointer + 0x67C) + z1) / 2;

                local dstPointer = entity:GetActorPointer(v.dst);

                local x2, y2, z2 = helpers.getBone(dstPointer, 2);
                z2 = (ashita.memory.read_float(dstPointer + 0x67C) + z2) / 2;

                local t = math.min(1 - (0.5 - math.min(dTime, 1)) * 2, 1);

                drawArc(x1, y1, z1, x2, y2, z2, color[v.color], t, true);
            end
        end
    end);
end);
