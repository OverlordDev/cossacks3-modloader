-- Проверка api/20_objects.lua на подставной памяти: TObj записан по заданной раскладке, калибровка должна её найти.
--   lua tools/api_test/objects_test.lua <папка репозитория> <float 4|8> <bool 1|4> <align 1|4|8> <base 0..12>
local root = arg[1]
dofile(root .. "/api/00_schema.lua")
local T = GAME_SCHEMA.types
local truth = { float = tonumber(arg[2]), bool = tonumber(arg[3]), align = tonumber(arg[4]), base = tonumber(arg[5]) }

-- независимый упаковщик: записывает значения полей в буфер
local mem_buf = {}  -- addr -> byte string
local function size(node)
  if node.array then return (node.array[2]-node.array[1]+1)*size(node.of) end
  local t=node.type
  if t=="int" or t=="string" or t=="Pointer" then return 4 elseif t=="float" then return truth.float
  elseif t=="bool" then return truth.bool elseif t=="Byte" then return 1 elseif t=="Word" then return 2 end
  if T[t] then local s=0 for _,f in ipairs(T[t]) do s=s+size(f) end
    if truth.align>1 then s=math.ceil(s/truth.align)*truth.align end return s end
  return 4
end
local values = {}  -- path -> value, for game.eval
local seed = 0
local function pack(typeName, prefix, parts)
  for _,f in ipairs(T[typeName]) do
    local path = prefix .. f.name
    local function one(node, p)
      local t=node.type
      if node.array then for i=node.array[1],node.array[2] do one(node.of, p.."["..i.."]") end return end
      seed = seed + 1
      if t=="int" then local v=(seed*7919)%100000 if p:match("^baseid$") then v=1 end values[p]=v parts[#parts+1]=string.pack("<i4",v)
      elseif t=="float" then local v=(seed%500)/4 values[p]=v parts[#parts+1]=truth.float==4 and string.pack("<f",v) or string.pack("<d",v)
      elseif t=="bool" then local v=seed%3==0 values[p]=v parts[#parts+1]=string.pack(truth.bool==1 and "<I1" or "<I4", v and 1 or 0)
      elseif T[t] and t~="int" then local sub={} pack(t, p..".", sub) local s=table.concat(sub)
        local want=size(node) parts[#parts+1]=s..string.rep("\0", want-#s)
      else parts[#parts+1]=string.rep("\0", size(node)) end
    end
    one(f, path)
  end
end
local parts = { string.rep("\0", truth.base) }
pack("TObj", "", parts)
local buf = table.concat(parts)
local ADDR = 0x10000000
mem = {}
local function rd(fmt,n) return function(a,o) local i=a+(o or 0)-ADDR+1 if i<1 or i+n-1>#buf then return nil end return (string.unpack(fmt,buf,i)) end end
mem.i32=rd("<i4",4) mem.u32=rd("<I4",4) mem.u8=rd("<I1",1) mem.u16=rd("<I2",2) mem.i16=rd("<i2",2) mem.f32=rd("<f",4) mem.f64=rd("<d",8) mem.str=function() return "" end
native = { GetGameObjectStateMachineHandle=function(h) return h==5 and 77 or 0 end,
  StateMachineGetArgDataByInd=function(sm) return sm==77 and ADDR or 0 end,
  GetPlayerHandleByIndex=function(i) return i==0 and 1 or 0 end, GetPlayerGameObjectsCountByHandle=function() return 1 end,
  GetGameObjectHandleByIndex=function() return 5 end }
game = { eval=function(e)
  local out={}
  for piece in (e.."+#1+"):gmatch("(.-)%+#1%+") do
    local fn, path = piece:match("^(%a+)%(TObj%(_unit_GetTObj%(%d+%)%)%.(.-)%)$")
    local v = values[path]
    if fn=="BoolToStr" then out[#out+1]= v and "True" or "False" elseif fn=="FloatToStr" then out[#out+1]=(tostring(v):gsub("%.",",")) else out[#out+1]=tostring(math.tointeger(v) or v) end
  end
  return table.concat(out,"\1") end }
log = { info=print, warn=print }
state = { get=function() error("slow path used") end }
dofile(root .. "/api/20_objects.lua")
local ok, why = objects.calibrate(5)
local m, p = objects.status()
print("calibrate:", ok, why, m, p and (p.float.."/"..p.bool.."/"..p.align.."/"..p.base))
local bad=0
for path, v in pairs(values) do
  local got = objects.get(5, path)
  local eq = (type(v)=="number" and math.abs(got - v) < 1e-4) or got == v
  if not eq then bad=bad+1 if bad<5 then print("MISMATCH", path, v, got) end end
end
print("checked fields:", (function() local n=0 for _ in pairs(values) do n=n+1 end return n end)(), "mismatches:", bad)
local r = objects.read(5); print("read hp:", r.hp, values.hp, "TObj size", size({type="TObj"}))
