-------------------------------------------------
-- HÄTE
-------------------------------------------------

require "objects.lua"

-- player control structure
-- use this to set / query controls
-- so that control logic can be cleanly separated in control-specific functions
controls = {
    fire = false,
    xaxis = 0.0,
    yaxis = 0.0
}

resolution = {
    x = 800,
    y = 600,
}


function love.load()
	-- The amazing music.
	music = love.audio.newSource("prondisk.xm")
	music:setLooping(true)
	
	-- The various images used.
    -- I prefer to keep loaded image objects in a table so they are easy to access later
    media = {
        dudicus_maximus = love.graphics.newImage("happycube.png"),
        enemy = love.graphics.newImage("angrycube.png"),
        boom = love.graphics.newImage("boom_blocky.png"),
        crosshairs = love.graphics.newImage("crosshairs_open.png"),
        bullet = love.graphics.newImage("bullet.png"),
    }

	love.graphics.setBackgroundColor(0x30, 0x30, 0x30)
	
    -- set up the player's object
    dood = Dude:new(resolution.x / 2, resolution.y / 2)
    -- the player is faster than a default dude, if we set it after creating a new dude
    -- then only our player dude will have the faster speed
    dood.speed = 300
    
    -- set up any enemies or other NPCs/objects that should exist at startup
    -- we store enemies and spawners in tables so we can easily tell from
    -- any piece of our code what objects currently exist in the game
    enemies = {}
    spawners = {}
    bullets = {}
    
    table.insert(spawners, Spawner:new(1.0))
    
    -- set up score and other counters / UI stuff
    gameover = false
    gamePaused = false
    kills = 0
    spawner_rate_decrease = 0.01
    
    -- final steps before starting the game
    love.mouse.setVisible(false) -- hide mouse because we draw crosshairs
	love.audio.play(music)
	love.audio.setVolume(0.5)
end


-- this is the main game logic function
-- it is called by the engine once per update cycle
-- dt is "delta time", the seconds (in a decimal) that have passed since the last
-- game logic update
-- by performing actions every cycle and scaling these actions by dt,
-- we get smooth, predictable action in the game
function love.update(dt)
    -- when paused or gameover, game logic does not occur!
    if gamePaused == true or gameover == true then
        return
    end

    -- handle controls in a separate function
    handle_controls(dt)
    
    -- player behavior
    dood:update(dt)
    
    -- spawner behavior
    for key, s in pairs(spawners) do
        -- for each spawner, see if we can spawn an enemy
        newguy = s:trySpawn(dt)
        
        -- if so, go ahead and spawn!
        if newguy ~= nil then
            print("spawning dude!")
            -- keep a copy of our newly-spawned dude
            table.insert(enemies, newguy)
        end
        
        -- make the spawners gradually faster!
        s.rate = s.rate - (spawner_rate_decrease * dt)
    end
    
    -- enemy AI
    for key, nme in pairs(enemies) do
        -- each enemy should move directly towards the player!
        nme:goto(dt, dood.position.x, dood.position.y)
        
        -- game ends when the player collides with an enemy!
        if nme:collideWith(dood) then
            On_gameover()
        end
    end
    
    -- bullet collisions
    for b_key, b in pairs(bullets) do
        b:update(dt)
        for nme_key, nme in pairs(enemies) do
            if b:collideWith(nme) then
                -- destroy enemy and bullet
                table.remove(enemies, nme_key)
                table.remove(bullets, b_key)
                
                -- increment kill counter
                kills = kills + 1
            end
        end
        
        -- destroy bullets that venture outside of the game area
        if b.position.x > resolution.x + 50 or b.position.x < -50
            or b.position.y > resolution.y + 50 or b.position.y < -50 then
            table.remove(bullets, b_key)
        end
    end
end


-- this is the main rendering function
-- called by the engine every cycle, or as often as it is able to
-- you should put ALL of your graphics functions here
-- keeping logic and rendering separate is IMPORTANT
-- and should generally be a one-way street
-- logic decides the state of the game world
-- rendering reads this state and draws it
-- iy does NOT modify logic or game data
function love.draw()
    -- draw our player
    love.graphics.draw(media.dudicus_maximus, dood.position.x, dood.position.y, 0, 1, 1, dood.width, dood.height)
    
    -- use our list of enemies to determine where we should draw the sprites
    -- for this frame
    for key, nme in pairs(enemies) do
        love.graphics.draw(media.enemy, nme.position.x, nme.position.y, 0, 1, 1, nme.width, nme.height)
    end
    
    -- draw bullets
    for key, b in pairs(bullets) do
        love.graphics.draw(media.bullet, b.position.x, b.position.y, 0, 1, 1, b.width, b.height)
    end
        
    -- if the game is over, draw the gameover message
    if gameover == true then
        love.graphics.print("GAME OVER\nYour Kills: " .. kills, resolution.x/2, resolution.y/2)
        love.graphics.print("Press spacebar to restart!", resolution.x/2, resolution.y * 0.75)
    else
        -- if not, draw the User Interface
        love.graphics.print("Kills: " .. kills, 20, 20)
        love.graphics.print("Controls: \n WASD : move \n hold left click: Fire!", resolution.x - 150, 20)
        
        -- draw crosshairs at the mouse location
        local mousex, mousey = love.mouse.getPosition()
        love.graphics.draw(media.crosshairs, mousex, mousey)
    end
end




function handle_controls(dt)
    -- movement
    local pos = dood.position
    motion = Vector:new(
        controls['xaxis'] * dood.speed * dt,
        controls['yaxis'] * dood.speed * dt
    )
    -- make sure the player isn't running off of the screen
    if pos.x + motion.x < resolution.x - dood.width and pos.x + motion.x > 0 then
        pos.x = pos.x + motion.x
    end
    if pos.y - motion.y < resolution.y - dood.height and pos.y - motion.y > 0 then
        pos.y = pos.y - motion.y
    end
    
    -- attack
    if controls['fire'] == true then
        local mousex, mousey = love.mouse.getPosition()
        newbullet = dood:shootAt(dt, mousex, mousey)
        if newbullet ~= nil then
            table.insert(bullets, newbullet)
        end
    end
    
    -- pause
end

-- GAME OVER, MAN! GAME OVER!
function On_gameover()
    gameover = true
end


function love.mousepressed(x, y, button)
   if button == 'l' then
      controls['fire'] = true
   end
end

function love.mousereleased(x, y, button)
   if button == 'l' then
      controls['fire'] = false
   end
end


function love.keypressed(key, unicode)
    -- set control axes for player movement
   if key == 'a' then
      controls['xaxis'] = -1.0
   elseif key == 'd' then
      controls['xaxis'] = 1.0
   elseif key == 's' then
      controls['yaxis'] = -1.0
   elseif key == 'w' then
      controls['yaxis'] = 1.0
   
   elseif key == ' ' and gameover then
        -- this effectively restarts the game
        love.load("main.lua")
   end
end

function love.keyreleased(key, unicode)
   -- reset the control axes
   -- but make sure they don't "overrule" one another
   if (key == 'a' and controls['xaxis'] < 0.0) or
        (key == 'd' and controls['xaxis'] > 0.0) then
      controls['xaxis'] = 0.0
   end
   if (key == 's' and controls['yaxis'] < 0.0) or
        (key == 'w' and controls['yaxis'] > 0.0) then
      controls['yaxis'] = 0.0
   end
end

function love.focus(f)
    gamePaused = not f
end