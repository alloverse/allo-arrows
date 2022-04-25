local mat4 = require('modules.mat4')
local vec3 = require('modules.vec3')
-- a Client is used to connect this app to a Place. arg[2] is the URL of the place to
-- connect to, which Assist sets up for you.
local client = Client(
    arg[2], 
    "allo-arrows"
)

local pp = require('pl.pretty').dump

-- App manages the Client connection for you, and manages the lifetime of the
-- your app.
local app = App(client)

-- Assets are files (images, glb models, videos, sounds, etc...) that you want to use
-- in your app. They need to be published so that user's headsets can download them
-- before you can use them. We make `assets` global so you can use it throughout your app.
local assets = {
    crosshairs = ui.Asset.File("images/crosshairs.png"),
    quit = ui.Asset.File("images/quit.png"),
}
app.assetManager:add(assets)

-- mainView is the main UI for your app. Set it up before connecting.
-- 0, 1.2, -2 means: put the app centered horizontally; 1.2 meters up from the floor; and 2 meters into the room, depth-wise
-- 1, 0.5, 0.01 means 1 meter wide, 0.5 meters tall, and 1 cm deep.
-- It's a surface, so the depth should be close to zero.
local mainView = ui.Surface(ui.Bounds(0, 1.2, -2,   6, 5, 0.01))
mainView.material.color = {0.7, 0.7, 1.0, 0.2}
mainView.hasCollider = true
mainView.material.hasTransparency = true

local quitButton = mainView:addSubview(ui.Button(
    ui.Bounds{size=ui.Size(0.12,0.12,0.05)}
        :move( mainView.bounds.size:getEdge("top", "right", "front") )
))
quitButton:setDefaultTexture(assets.quit)
quitButton.onActivated = function()
    app:quit()
end

local crosshairs = ui.Surface(ui.Bounds(0, 0, 0.1,  0.3, 0.3, 0.3))
crosshairs.color = {1, 0, 0, 1}
crosshairs.grabbable = false
crosshairs.texture = assets.crosshairs
crosshairs.hasTransparency = true

pp(crosshairs:specification())
mainView:addSubview(crosshairs)

-- matix to transform points from world to mainView space
local toViewLocal = mat4.new(mainView.bounds.pose.transform)
toViewLocal:invert(toViewLocal)

local aim = {
    from = vec3(),
    to = vec3()
}

local function updateHit(target, hit)
    if target.hit == hit then
        return
    end
    target.hit = hit
    if hit then 
        target:setColor({0, 1, 0, 0.5})
    else 
        target:setColor({1, 0, 0, 0.8})
    end
end


local targets = {}
for i = 1, 5 do
    local pos = vec3.new(-10 + i * 2,1.7,-10 - i*2)
    local target = ui.Surface(ui.Bounds(pos.x, pos.y, pos.z,  2,2,2))
    target.pos = pos
    target.hasTransparency = true
    updateHit(target, false)
    table.insert(targets, target)
    mainView:addSubview(target)
end

local bullets = {}

local function shoot()
    local p = toViewLocal * aim.from
    local bullet = Surface(ui.Bounds(p.x, p.y, p.z,  0.1, 0.1, 0.1))
    bullet.color = {1, 1, 0, 1}
    -- initial velocity
    bullet.v = (aim.to - aim.from) * 4
    mainView:addSubview(bullet)
    while #bullets > 2 do
        bullets[1]:removeFromSuperview()
        table.remove(bullets, 1)
    end
    table.insert(bullets, bullet)
end


mainView.onInteraction = function (self, inter, body, sender)
    View.onInteraction(self, inter, body, sender)
    if body[1] == "point" then 
        
        local p = vec3.new(table.unpack(body[3]))
        local mp = toViewLocal * p
        
        crosshairs.bounds.pose.transform[13] = mp.x
        crosshairs.bounds.pose.transform[14] = mp.y
        crosshairs.bounds.pose.transform[15] = mp.z

        aim = {
            from = vec3.new(table.unpack(body[2])),
            to = vec3.new(table.unpack(body[3]))
        }
        
    end
    if body[1] == "poke" and body[2] == true then
        shoot()
        
        crosshairs:setBounds()
        mainView:setBounds()
    end
end

local function blink(t, hit)
    app:scheduleAction(t, false, function()
        for _, target in ipairs(targets) do
            updateHit(target, hit)
        end
    end)
end

-- Add a little bit of animation
local animate = true
local gameOver = false
local dt = 0.03
app:scheduleAction(dt, true, function()
    if app.connected and animate then
        -- update the crosshairs
        crosshairs:setBounds()
        for i, bullet in ipairs(bullets) do
            -- update bullet position
            bullet.bounds.pose:move(bullet.v.x*dt, bullet.v.y*dt, bullet.v.z*dt)

            -- get the bullet position to check against targets
            local pos = vec3.new(
                bullet.bounds.pose.transform[13],
                bullet.bounds.pose.transform[14],
                bullet.bounds.pose.transform[15]
            )

            -- Check if it is below the ground, remove it if it is
            if pos.y < -3 then
                bullet:removeFromSuperview()
                table.remove(bullets, i)
            else
                -- Otherwise update bullets velocirt; add gravity
                bullet.v.y = bullet.v.y - 9.82 * 0.03
                bullet:setBounds()

                -- Did it hit anything?
                for _, target in ipairs(targets) do
                    if vec3.dist(target.pos, pos) < 1 then 
                        updateHit(target, true)
                    end
                end
            end
        end

        local hitCount = 0
        if not gameOver then
            for _, target in ipairs(targets) do
                hitCount = hitCount + (target.hit and 1 or 0)
            end
            if not gameOver and hitCount == #targets then 
                gameOver = true
                local d = 0.3
                blink(d, false)
                blink(d*2, true)
                blink(d*3, false)
                blink(d*4, true)
                blink(d*5, false)
                app:scheduleAction(d*10, false, function()
                    gameOver = false
                end)
            end 
        end
    end
end)

-- Tell the app that mainView is the primary UI for this app
app.mainView = mainView

-- Connect to the designated remote Place server
app:connect()
-- hand over runtime to the app! App will now run forever,
-- or until the app is shut down (ctrl-C or exit button pressed).
app:run()
