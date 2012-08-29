-------------------------------------------------
-- HÄTE game objects
-------------------------------------------------

-- pay no attention to this code ... it's stuff that I probably won't be using
--[[
-- prototype-oriented programming code
function clone( base_object, clone_object )
  if type( base_object ) ~= "table" then
    return clone_object or base_object 
  end
  clone_object = clone_object or {}
  clone_object.__index = base_object
  return setmetatable(clone_object, clone_object)
end

function isa( clone_object, base_object )
  local clone_object_type = type(clone_object)
  local base_object_type = type(base_object)
  if clone_object_type ~= "table" and base_object_type ~= table then
    return clone_object_type == base_object_type
  end
  local index = clone_object.__index
  local _isa = index == base_object
  while not _isa and index ~= nil do
    index = index.__index
    _isa = index == base_object
  end
  return _isa
end
--]]

-- Vector class
-- it is handy to write a class for vectors because we don't want to do a bunch
-- of redundant (and perhaps buggy) math in many separate places
Vector = {
  x = 0,
  y = 0
}

function Vector:new(x,y)
    local object = {x=x, y=y}
    setmetatable(object, { __index = Vector })  -- Inheritance
    return object
end

-- get a normalized version of this vector
function Vector:normalized()
    local total = distance(0.0, 0.0, self.x, self.y)
    return Vector:new( self.x / total, self.y / total)
end

-- calculate squared distance
-- this is a handy optimization if you want to merely compare two distances
-- to see which is bigger; you don't need to know the precise distances
-- so we can skip the square root (sqrt) operation, which is "slow"
-- when done many hundreds/thousands of times per second
function distance2(x1,y1, x2,y2)
    local xdiff = x2 - x1
    local ydiff = y2 - y1
    return (xdiff * xdiff) + (ydiff * ydiff)
end

-- calculate real distance
function distance(x1,y1, x2,y2)
    local dist2 = distance2(x1,y1, x2,y2)
    return math.sqrt(dist2)
end

-- /Vector class


-- GameObject class
GameObject = {
    position = Vector:new(0,0,0),
    velocity = Vector:new(0,0,0),
    -- width + height for collision detection
    -- this should actually be half the width and height of the sprite,
    -- because it starts from the center
    -- a 16x16 square sprite has width 8, height 8
    width = 8,
    height = 8
}

function GameObject:new(x,y)
    local object = {x = x, y = y}
    setmetatable(object, { __index = GameObject })  -- Inheritance
    return object
end

-- does this GameObject collide with GameObject "other"?
function GameObject:collideWith(other)
    -- do AABB collision
    local x1, y1, w1, h1 = self.position.x, self.position.y, self.width, self.height
    local x2, y2, w2, h2 = other.position.x, other.position.y, other.width, other.height
    
    -- look up "Separating Axis Theorem" for more details
    if ((w1 + w2) >= math.abs(x2 - x1)) and
        ((h1 + h2) >= math.abs(y2 - y1)) then
        return true
    end
    
    -- guess we didn't collide!
    return false
end

-- /GameObject class


-- dude class
Dude = {
    speed = 100,
    width = 8,
    height = 8,
    rate = 0.2,
    cooldown = 0.0,
}
setmetatable(Dude, { __index = GameObject })  -- Dude inherits from GameObject

function Dude:new(x,y)
    local object = {position = Vector:new(x,y,0)}
    setmetatable(object, { __index = Dude })  -- Inheritance
    return object
end

function Dude:update(dt)
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end
end

-- move this dude to a given point at whatever speed the dude is able to move
function Dude:goto(dt, x, y)
    -- this is for convenience, so I don't have to keep typing "self.position"
    -- pos holds the same reference as self.position, so changing pos will
    -- also change self.position
    local pos = self.position
    
    -- replace with vector normalization
    local v = Vector:new(x - pos.x, y - pos.y)
    local normal_dest = v:normalized()
    
    pos.x = pos.x + (normal_dest.x * dt * self.speed)
    pos.y = pos.y + (normal_dest.y * dt * self.speed)
end

-- shoot a bullet at the given position
function Dude:shootAt(dt, x, y)
    -- only shoot if we're cooled down!
    if self.cooldown > 0 then
        return nil
    end

    -- create bullet at the dude's position
    local newb = Bullet:new(self.position.x, self.position.y)
    
    -- set velocity of new bullet so it flies towards the aim point
    local normalized = Vector:new(x - self.position.x, y - self.position.y):normalized()
    newb.velocity = Vector:new(normalized.x * newb.speed, normalized.y * newb.speed)
    
    -- reset cooldown
    self.cooldown = self.cooldown + self.rate
    
    -- return the new bullet so callers can handle the bullet
    return newb
end

-- /dude class


-- bullet class
Bullet = {
    position = Vector:new(0,0,0),
    velocity = Vector:new(0,0,0),
    speed = 500,
    width = 4,
    height = 4
}
setmetatable(Bullet, { __index = GameObject })  -- Bullet inherits from GameObject

function Bullet:new(x,y)
    local object = {position = Vector:new(x,y,0)}
    setmetatable(object, { __index = Bullet })  -- Inheritance
    return object
end

-- move this bullet along whatever path it's going
function Bullet:update(dt)
    self.position.x = self.position.x + (self.velocity.x * dt)
    self.position.y = self.position.y + (self.velocity.y * dt)
end

-- /bullet class


-- spawner class

Spawner = {
    rate = 3.0,
    cooldown = 0.0
}

function Spawner:new(rate)
    local object = {rate = rate}
    setmetatable(object, { __index = Spawner })  -- Inheritance
    return object
end

-- attempt to spawn an enemy from this spawner
-- this should be called once per game update from the love.update function
function Spawner:trySpawn(dt)
    -- tick the cooldown timer
    self.cooldown = self.cooldown - dt
    
    -- if our cooldown is finished
    if self.cooldown <= 0 then
        -- reset the cooldown; here we are adding just in case cooldown is < 0
        -- INSTEAD of setting it directly to the cooldown rate so that we don't
        -- "lose" any time
        self.cooldown = self.cooldown + self.rate
        
        -- actually perform the spawn and return the spawned enemy
        return self.doSpawn()
    end
    
    -- spawning failed; return nothing
    return nil
end

-- perform enemy spawn
function Spawner:doSpawn()
    local resx = 800
    local resy = 600
    
    -- here we choose one of four sides of the map to spawn the enemy from
    local side = math.random(1,4)
    local spawnx = 0
    local spawny = 0    
    -- up
    if side == 1 then
        spawnx = math.random(0,resx)
        spawny = 0
    -- right
    elseif side == 2 then
        spawnx = resx
        spawny = math.random(0,resy)
    -- down
    elseif side == 3 then
        spawnx = math.random(0,resx)
        spawny = resy
    -- left
    elseif side == 4 then
        spawnx = 0
        spawny = math.random(0,resy)
    end
    
    -- now perform actual spawn
    local nme = Dude:new(spawnx, spawny)
    return nme
end

-- /spawner class
