local json = assert(loadfile("json.lua"))()
local fmt = string.format

local function test(name, func)
    xpcall(function()
        func()
        print( fmt("[pass] %s", name) )
    end, function(err)
        print( fmt("[fail] %s : %s", name, err) )
    end)
end


local function equal(a, b)
    -- Handle table
    if type(a) == "table" and type(b) == "table" then
        for k in pairs(a) do
            if not equal(a[k], b[k]) then
                return false
            end
        end
        for k in pairs(b) do
            if not equal(b[k], a[k]) then
                return false
            end
        end
        return true
    end
    -- Handle scalar
    return a == b
end


test("numbers", function()
    local t = {
        [ "123.456"       ] = 123.456,
        [ "-123"          ] = -123,
        [ "-567.765"      ] = -567.765,
        [ "12.3"          ] = 12.3,
        [ "0"             ] = 0,
        [ "0.10000000012" ] = 0.10000000012,
    }
    if _VERSION == "Lua 5.3" then
        t["183163344413760794"] = 183163344413760794
    end
    for k, v in pairs(t) do
        local res = json.decode(k)
        assert( res == v, fmt("expected '%s', got '%s'", k, res) )
        res = json.encode(v)
        assert( res == k, fmt("expected '%s', got '%s'", v, res) )
    end
    assert( json.decode("13e2") == 13e2 )
    assert( json.decode("13E+2") == 13e2 )
    assert( json.decode("13e-2") == 13e-2 )
end)


test("literals", function()
    assert( json.decode("true") == true )
    assert( json.encode(true) == "true" )
    assert( json.decode("false") == false )
    assert( json.encode(false) == "false" )
    assert( json.decode("null") == nil )
    assert( json.encode(nil) == "null")
end)


test("strings", function()
    local s = "Hello world"
    assert( s == json.decode( json.encode(s) ) )
    s = "\0 \13 \27"
    assert( s == json.decode( json.encode(s) ) )
end)


test("unicode", function()
    local s = "こんにちは世界"
    assert( s == json.decode( json.encode(s) ) )
end)

test("unicode escaping", function()
    assert( json.decode([["\uD834\uDD1E"]]) == "𝄞")
    assert( json.decode([["\u2605"]]) == "★")
end)

test("arrays", function()
    local t = { "cat", "dog", "owl" }
    assert( equal( t, json.decode( json.encode(t) ) ) )
end)


test("objects", function()
    local t = { x = 10, y = 20, z = 30 }
    assert( equal( t, json.decode( json.encode(t) ) ) )
end)

test("decode invalid", function()
    local t = {
        '',
        ' ',
        '{',
        '[',
        '{"x" : ',
        '{"x" : 1',
        '{"x" : z }',
        '{"x" : 123z }',
        '{x : 123 }',
        '{10 : 123 }',
        '{]',
        '[}',
        '"a',
    }
    for _, v in ipairs(t) do
        local status = pcall(json.decode, v)
        assert( not status, fmt("'%s' was parsed without error", v) )
    end
end)


test("decode invalid string", function()
    local t = {
        [["\z"]],
        [["\1"]],
        [["\u000z"]],
        [["\ud83d\ude0q"]],
        '"x\ny"',
        '"x\0y"',
    }
    for _, v in ipairs(t) do
        local status = pcall(json.decode, v)
        assert( not status, fmt("'%s' was parsed without error", v) )
    end
end)


test("decode escape", function()
    local t = {
        [ [["\u263a"]]        ] = '☺',
        [ [["\ud83d\ude02"]]  ] = '😂',
        [ [["\r\n\t\\\""]]    ] = '\r\n\t\\"',
        [ [["\\"]]            ] = '\\',
        [ [["\\\\"]]          ] = '\\\\',
        [ [["\/"]]            ] = '/',
    }
    for k, v in pairs(t) do
        local res = json.decode(k)
        assert( res == v, fmt("expected '%s', got '%s'", v, res) )
    end
end)


test("decode empty", function()
    local t = {
        [ '[]' ] = {},
        [ '{}' ] = {},
        [ '""' ] = "",
    }
    for k, v in pairs(t) do
        local res = json.decode(k)
        assert( equal(res, v), fmt("'%s' did not equal expected", k) )
    end
end)


test("decode collection", function()
    local t = {
        [ '[1, 2, 3, 4, 5, 6]'            ] = {1, 2, 3, 4, 5, 6},
        [ '[1, 2, 3, "hello"]'            ] = {1, 2, 3, "hello"},
        [ '{ "name": "test", "id": 231 }' ] = {name = "test", id = 231},
        [ '{"x":1,"y":2,"z":[1,2,3]}'     ] = {x = 1, y = 2, z = {1, 2, 3}},
    }
    for k, v in pairs(t) do
        local res = json.decode(k)
        assert( equal(res, v), fmt("'%s' did not equal expected", k) )
    end
end)


test("encode invalid", function()
    local t = {
        { [ function() end ] = 12 },
        { [ true ]  = 42 },
        { x = 10, [{}] = 5 },
    }
    for i, v in ipairs(t) do
        local status = pcall(json.encode, v)
        assert( not status, fmt("encoding idx %d did not result in an error", i) )
    end
end)


test("encode sparse", function()
    local t = {
        [ { [1000] = "b" } ] = { ["1000"] = "b" },
        [ { nil, 2, 3, 4 } ] = { ["2"] = 2, ["3"] = 3, ["4"] = 4 },
        [ { x = 10, [1] = 2 } ] = { x = 10, ["1"] = 2 },
        [ { [1] = "a", [3] = "b" } ] = { ["1"] = "a", ["3"] = "b" },
        [ { x = 10, [4] = 5 } ] = { x = 10, ["4"] = 5 },
    }
    for k, v in pairs(t) do
        local res = json.decode(json.encode(k))
        assert( equal(res, v), fmt("encoding of '%s' failed", json.encode(k, false)) )
    end
end)


test("encode invalid number", function()
    local t = {
        math.huge,      -- inf
        -math.huge,     -- -inf
        math.huge * 0,  -- NaN
    }
    for _, v in ipairs(t) do
        local status = pcall(json.encode, v)
        assert( not status, fmt("encoding '%s' did not result in an error", v) )
    end
end)


test("encode escape", function()
    local t = {
        [ '"x"'       ] = [["\"x\""]],
        [ 'x\ny'      ] = [["x\ny"]],
        [ 'x\0y'      ] = [["x\u0000y"]],
        [ 'x\27y'     ] = [["x\u001by"]],
        [ '\r\n\t\\"' ] = [["\r\n\t\\\""]],
    }
    for k, v in pairs(t) do
        local res = json.encode(k)
        assert( res == v, fmt("'%s' was not escaped properly", k) )
    end
end)
