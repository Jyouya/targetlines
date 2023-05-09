local d3d8dev        = require('d3d8').get_device();
local ffi            = require('ffi');
local C              = ffi.C;

local helpers        = require('helpers');
local rotateVector16 = helpers.rotateVector16;
local normalize      = helpers.normalize;
local matrixMultiply = helpers.matrixMultiply;
local vec4Transform  = helpers.vec4Transform;
local worldToScreen  = helpers.worldToScreen;
local width          = helpers.width;
local height         = helpers.height;
local getTexture     = helpers.getTexture;

local Bezier3D_2     = require('Bezier3D_2');

ffi.cdef [[
    #pragma pack(1)
    struct VertFormatFFFFUFF
    {
        float x;
        float y;
        float z;
        float rhw;
        unsigned int diffuse;
        float u;
        float v;
    };
]]

local vertFormatMask  = bit.bor(C.D3DFVF_XYZRHW, C.D3DFVF_DIFFUSE, C.D3DFVF_TEX1);
local vertFormat      = ffi.new('struct VertFormatFFFFUFF');

local _, vertexBuffer = d3d8dev:CreateVertexBuffer(
    200 * ffi.sizeof(vertFormat),
    C.D3DUSAGE_WRITEONLY,
    vertFormatMask,
    C.D3DPOOL_MANAGED);

local arcTex, orbTex;
local function drawArc(x1, y1, z1, x2, y2, z2, color, progress, orb)
    local _, world = d3d8dev:GetTransform(C.D3DTS_WORLD);
    local _, view = d3d8dev:GetTransform(C.D3DTS_VIEW);
    local _, projection = d3d8dev:GetTransform(C.D3DTS_PROJECTION)

    local _, ptr = vertexBuffer:Lock(0, 0, 0);
    local vdata = ffi.cast('struct VertFormatFFFFUFF*', ptr);

    local zoom = (2.8 - projection._11) * 0.47619047619;

    local P1x, P1y, P1z = (x1 + x2) / 2, (z1 + z2) / 2 - 2, (y1 + y2) / 2;

    P1y = P1y - 2 * zoom;

    local midpoint = vec4Transform(ffi.new('D3DXVECTOR4', { P1x, P1y, P1z, 1 }), view);
    local p1Distance = math.sqrt(midpoint.x ^ 2 + midpoint.y ^ 2 + midpoint.z ^ 2)

    P1y = P1y + math.max(6 - p1Distance, 0) / 2 + progress

    local P0x, P0y, P0z = x1, z1, y1;
    local P2x, P2y, P2z = x2, z2, y2;

    local P1 = rotateVector16(
        normalize({ P2x - P0x, P2y - P0y, P2z - P0z }),
        { P1x - P0x, P1y - P0y, P1z - P0z },
        not orb
    );
    P1x, P1y, P1z = P1[1] + P0x, P1[2] + P0y, P1[3] + P0z;

    local bcurve = Bezier3D_2:new({
        { P0x, P0y, P0z },
        { P1x, P1y, P1z },
        { P2x, P2y, P2z }
    });

    local viewProj = matrixMultiply(view, projection);

    local wx0, wy0, wz0 = worldToScreen(P0x, P0y, P0z, view, projection, world);
    local wx2, wy2, wz2 = worldToScreen(P2x, P2y, P2z, view, projection, world);

    if (
            (wz0 > 1 and wz2 > 1) or
            (wz0 < 0 and wz2 < 0) or
            ((wx0 > width or wx0 < 0) and (wx2 > width or wx2 < 0)) or
            ((wy0 > height or wy0 < 0) and (wy2 > height or wy2 < 0))
        ) then
        return;
    end

    local p1, p2, p3;

    local tMin = 0;
    local tMax = 1;
    if (wx0 > width or wx0 < 0 or wy0 > height or wy0 < 0 or wz0 > 1 or wz0 < 0) then
        -- local zeros = bcurve:solveZeros(viewProj);
        local _, tZero = bcurve:solveZeros(viewProj);

        if (not tZero) then return; end

        tMin = tZero;
        p1, p2, p3 = table.unpack(bcurve:subdivide(tZero)[2]);
    elseif (wx2 > width or wx2 < 0 or wy2 > height or wy2 < 0 or wz2 > 1 or wz2 < 0) then
        -- local zeros = bcurve:solveZeros(viewProj);
        local tZero = bcurve:solveZeros(viewProj);
        if (not tZero) then return; end

        tMax = tZero;
        p1, p2, p3 = table.unpack(bcurve:subdivide(tZero)[1]);
    else
        p1 = { P0x, P0y, P0z };
        p2 = { P1x, P1y, P1z };
        p3 = { P2x, P2y, P2z };
    end

    -- Project new control points to screen
    P0x, P0y, P0z = worldToScreen(p1[1], p1[2], p1[3], view, projection, world);
    P1x, P1y, P1z = worldToScreen(p2[1], p2[2], p2[3], view, projection, world);
    P2x, P2y, P2z = worldToScreen(p3[1], p3[2], p3[3], view, projection, world);

    -- Create new bezier curve with new control points
    bcurve = Bezier3D_2:new({
        { P0x, P0y, P0z },
        { P1x, P1y, P1z },
        { P2x, P2y, P2z }
    });

    local vertices = T {};

    if (progress < tMin) then
        return;
    end

    local tSize = 1 / (tMax - tMin);
    local tAdjusted = (progress - tMin) * tSize;
    local tEnd = math.min(tAdjusted, 1);
    local tInterval = 0.95 * (tEnd) / 38;

    local lineWidth = 3;
    local t = 0;
    do
        local p = bcurve:sample(t);
        local n = bcurve:normal(t);
        local nx = n[1] * lineWidth;
        local ny = n[2] * lineWidth;


        -- local x, y = screenToNDC(P0x, P0y)
        local u;
        if (tMin > 0) then
            u = 0.25;
        else
            u = 0;
        end

        vertices:insert({ p[1] + nx, p[2] + ny, p[3], 1, color, u, 0 });
        vertices:insert({ p[1] - nx, p[2] - ny, p[3], 1, color, u, 0.5 });
    end


    -- First and last samples are always the same length
    t = 0.025;
    for i = 2, 78, 2 do
        local p = bcurve:sample(t);
        local n = bcurve:normal(t);
        local nx = n[1] * lineWidth;
        local ny = n[2] * lineWidth;

        local u = 0.25 + t / 2
        vertices:insert({ p[1] + nx, p[2] + ny, p[3], 1, color, u, 0 });
        vertices:insert({ p[1] - nx, p[2] - ny, p[3], 1, color, u, 0.5 });

        t = t + tInterval;
    end

    t = t + 0.025 - tInterval;
    do
        local p = bcurve:sample(t);
        local n = bcurve:normal(t);
        local nx = n[1] * lineWidth;
        local ny = n[2] * lineWidth;

        local u;
        if (tMax < tAdjusted) then
            u = 0.75;
        else
            u = 1;
        end

        vertices:insert({ p[1] + nx, p[2] + ny, p[3], 1, color, u, 0 });
        vertices:insert({ p[1] - nx, p[2] - ny, p[3], 1, color, u, 0.5 });

        if (tMax >= tAdjusted and progress < 1) then
            orb = orb and true;
            vertices:insert({ p[1] - 10, p[2] - 10, p[3], 1, color, 0, 0 });
            vertices:insert({ p[1] + 10, p[2] - 10, p[3], 1, color, 1, 0 });
            vertices:insert({ p[1] - 10, p[2] + 10, p[3], 1, color, 0, 1 });
            vertices:insert({ p[1] + 10, p[2] + 10, p[3], 1, color, 1, 1 });
        else
            orb = false;
        end
    end


    if (P2z > P0z) then
        for i = 0, 81 do
            vdata[i] = ffi.new('struct VertFormatFFFFUFF', vertices[82 - i]);
        end
    else
        for i = 0, 81 do
            vdata[i] = ffi.new('struct VertFormatFFFFUFF', vertices[i + 1]);
        end
    end

    if (orb) then
        for i = 82, 85 do
            vdata[i] = ffi.new('struct VertFormatFFFFUFF', vertices[i + 1]);
        end
    end

    vertexBuffer:Unlock();
    arcTex = arcTex or getTexture(addon.path .. 'assets/beam.png');

    d3d8dev:SetStreamSource(0, vertexBuffer, ffi.sizeof(vertFormat));

    d3d8dev:SetTexture(0, arcTex);

    d3d8dev:SetTextureStageState(0, C.D3DTSS_COLOROP, C.D3DTOP_BLENDTEXTUREALPHA);
    d3d8dev:SetTextureStageState(0, C.D3DTSS_COLORARG1, C.D3DTA_TEXTURE);
    d3d8dev:SetTextureStageState(0, C.D3DTSS_COLORARG2, C.D3DTA_DIFFUSE);
    d3d8dev:SetTextureStageState(0, C.D3DTSS_ALPHAOP, C.D3DTOP_SELECTARG1);
    d3d8dev:SetTextureStageState(0, C.D3DTSS_ALPHAARG1, C.D3DTA_TEXTURE);

    d3d8dev:SetRenderState(C.D3DRS_ZENABLE, 0);
    d3d8dev:SetRenderState(C.D3DRS_ALPHABLENDENABLE, 1);
    d3d8dev:SetRenderState(C.D3DRS_SRCBLEND, C.D3DBLEND_SRCALPHA);
    d3d8dev:SetRenderState(C.D3DRS_DESTBLEND, C.D3DBLEND_INVSRCALPHA);

    d3d8dev:SetVertexShader(vertFormatMask);

    d3d8dev:DrawPrimitive(C.D3DPT_TRIANGLESTRIP, 0, 80);

    if (orb) then
        orbTex = orbTex or getTexture(addon.path .. 'assets/orb.png');
        d3d8dev:SetTexture(0, orbTex);
        d3d8dev:DrawPrimitive(C.D3DPT_TRIANGLESTRIP, 82, 2);
    end
end

return drawArc;
