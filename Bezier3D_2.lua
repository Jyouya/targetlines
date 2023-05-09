local function normalize(vec3)
    local u = (vec3[1] ^ 2 + vec3[2] ^ 2 + vec3[3] ^ 2) ^ (-0.5);
    return { vec3[1] * u, vec3[2] * u, vec3[3] * u };
end

local Bezier2 = {};
function Bezier2:sample(t)
    -- ? Is cacheing this even a performance gain?
    local t2 = t ^ 2;
    return {
        self.MP0[1] + t * self.MP1[1] + t2 * self.MP2[1],
        self.MP0[2] + t * self.MP1[2] + t2 * self.MP2[2],
        self.MP0[3] + t * self.MP1[3] + t2 * self.MP2[3],
    };
end

function Bezier2:tangent(t)
    return {
        self.M[1] * t + self.B[1],
        self.M[2] * t + self.B[2],
        self.M[3] * t + self.B[3],
    };
end

function Bezier2:normal(t)
    local tangent = self:tangent(t);

    return normalize {
        self.C[2] * tangent[3] - self.C[3] * tangent[2],
        self.C[3] * tangent[1] - self.C[1] * tangent[3],
        self.C[1] * tangent[2] - self.C[2] * tangent[1]
    };
end

function Bezier2:testCoefficients(mx, my, mz, mw, res)
    local a = self.MP2[1] * mx + self.MP2[2] * my + self.MP2[3] * mz;
    local b = self.MP1[1] * mx + self.MP1[2] * my + self.MP1[3] * mz;
    local c = self.MP0[1] * mx + self.MP0[2] * my + self.MP0[3] * mz + mw;

    local term2 = b ^ 2 - 4 * a * c;
    if (term2 == 0) then
        -- One real solution
        local t = { -b / a * 0.5 };
        if (t >= 0 and t <= 1) then
            res:insert(t);
        end
    elseif (term2 > 0) then
        -- Two real solutions
        local root = math.sqrt(term2);

        local t = 0.5 * (-b + root) / a;
        if (t >= 0 and t <= 1) then
            res:insert(t);
        end

        t = 0.5 * (-b - root) / a;
        if (t >= 0 and t <= 1) then
            res:insert(t);
        end
    end
    return res;
end

function Bezier2:solveZeros(viewProj)
    local zeros = T {};
    -- x == 1
    do
        local mx = viewProj._11 - viewProj._14;
        local my = viewProj._21 - viewProj._24;
        local mz = viewProj._31 - viewProj._34;
        local mw = viewProj._41 - viewProj._44;

        self:testCoefficients(mx, my, mz, mw, zeros);
    end

    -- x == -1
    do
        local mx = viewProj._11 + viewProj._14;
        local my = viewProj._21 + viewProj._24;
        local mz = viewProj._31 + viewProj._34;
        local mw = viewProj._41 + viewProj._44;

        self:testCoefficients(mx, my, mz, mw, zeros);
    end

    -- y == 1
    do
        local mx = viewProj._12 - viewProj._14;
        local my = viewProj._22 - viewProj._24;
        local mz = viewProj._32 - viewProj._34;
        local mw = viewProj._42 - viewProj._44;

        self:testCoefficients(mx, my, mz, mw, zeros);
    end

    -- y == -1
    do
        local mx = viewProj._12 + viewProj._14;
        local my = viewProj._22 + viewProj._24;
        local mz = viewProj._32 + viewProj._34;
        local mw = viewProj._42 + viewProj._44;

        self:testCoefficients(mx, my, mz, mw, zeros);
    end

    -- z == 1
    do
        local mx = viewProj._13 - viewProj._14;
        local my = viewProj._23 - viewProj._24;
        local mz = viewProj._33 - viewProj._34;
        local mw = viewProj._43 - viewProj._44;

        self:testCoefficients(mx, my, mz, mw, zeros);
    end

    -- z == -1
    do
        local mx = viewProj._13 + viewProj._14;
        local my = viewProj._23 + viewProj._24;
        local mz = viewProj._33 + viewProj._34;
        local mw = viewProj._43 + viewProj._44;

        self:testCoefficients(mx, my, mz, mw, zeros);
    end

    local min = 1;
    local max = 0;

    if (#zeros == 0) then
        return;
    end

    for _, v in ipairs(zeros) do
        if (v < min) then
            min = v;
        end

        if (v > max) then
            max = v;
        end
    end
    return min, max;
end

function Bezier2:subdivide(t)
    -- P0, lerp(t, P0, P1), sample(t)
    -- sample(t), lerp(t, P1, P2), P2

    local midpoint = self:sample(t);

    local C0x = self.P0[1] + (self.P1[1] - self.P0[1]) * t;
    local C0y = self.P0[2] + (self.P1[2] - self.P0[2]) * t;
    local C0z = self.P0[3] + (self.P1[3] - self.P0[3]) * t;

    local C1x = self.P1[1] + (self.P2[1] - self.P1[1]) * t;
    local C1y = self.P1[2] + (self.P2[2] - self.P1[2]) * t;
    local C1z = self.P1[3] + (self.P2[3] - self.P1[3]) * t;

    return {
        {
            { self.P0[1], self.P0[2], self.P0[3] },
            { C0x,        C0y,        C0z },
            midpoint,
        },
        {
            midpoint,
            { C1x,        C1y,        C1z },
            { self.P2[1], self.P2[2], self.P2[3] },
        }
    };
end

function Bezier2:new(controlPoints)
    local res = {};

    self.P0 = controlPoints[1];
    self.P1 = controlPoints[2];
    self.P2 = controlPoints[3];

    local P0 = self.P0;
    local P1 = self.P1;
    local P2 = self.P2;

    -- Cache the polynomial coefficients
    res.MP0 = {
        P0[1],
        P0[2],
        P0[3]
    };
    res.MP1 = {
        -2 * P0[1] + 2 * P1[1],
        -2 * P0[2] + 2 * P1[2],
        -2 * P0[3] + 2 * P1[3]
    };
    res.MP2 = {
        P0[1] - 2 * P1[1] + P2[1],
        P0[2] - 2 * P1[2] + P2[2],
        P0[3] - 2 * P1[3] + P2[3]
    };

    -- Cache m and b for derivative
    res.M = {
        2 * (P0[1] + P2[1] - P1[1] * 2),
        2 * (P0[2] + P2[2] - P1[2] * 2),
        2 * (P0[3] + P2[3] - P1[3] * 2),
    };

    res.B = {
        2 * (P1[1] - P0[1]),
        2 * (P1[2] - P0[2]),
        2 * (P1[3] - P0[3]),
    };

    -- (P2 - P0) x (P1 - P0)
    self.C = normalize({
        (P2[2] - P0[2]) * (P1[3] - P0[3]) - (P2[3] - P0[3]) * (P1[2] - P0[2]),
        (P2[3] - P0[3]) * (P1[1] - P0[1]) - (P2[1] - P0[1]) * (P1[3] - P0[3]),
        (P2[1] - P0[1]) * (P1[2] - P0[2]) - (P2[2] - P0[2]) * (P1[1] - P0[1]),
    });

    -- self.C = normalize({
    --     -P2[3] + P0[3], P2[2] - P0[2], -P0[1] + P2[1]
    -- });

    return setmetatable(res, { __index = Bezier2 });
end

return Bezier2;
