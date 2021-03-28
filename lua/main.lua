local mat4 = require('modules.mat4')
local vec3 = require('modules.vec3')
local pp = require('pl.pretty').dump
local ECS = require 'ecs'

-- a Client is used to connect this app to a Place. arg[2] is the URL of the place to
-- connect to, which Assist sets up for you.
local client = Client(
    arg[2], 
    "allo-arrows"
)

local ecs = ECS()

local assets = {
    crosshairs = ui.Asset.File("images/crosshairs.png"),
    gun = ui.Asset.File("images/gun.glb"),
    bullet = ui.Asset.File("images/bullet.glb"),
    target = ui.Asset.File("images/target.glb"),
}
local assetManager = ui.Asset.Manager(client.client)
assetManager:add(assets)

client.updateState = function (self, state)
    ecs:setState(state)
    ecs:update(1/20)
end

local function entityWorldTransform(ent)
    local t = mat4.new()
    while ent do
        t = mat4.new(ent.components.transform.matrix) * t
        ent = ent.components.relationships and ent.components.relationships.parent
        ent = ent and ecs:withId(ent)
    end
    return t
end

ecs:system({"bullet"}, function (entity, dt)
    local m = mat4.new(entity.components.transform.matrix)
    m:translate(m, vec3.new(entity.components.bullet.speed) * dt)
    m._m = nil
    entity.components.transform.matrix = m

    local owner_ent = ecs:withId(entity.components.bullet.owner)
    local om = entityWorldTransform(owner_ent)
    local bullet_pos = vec3.new(m[13], m[14], m[15])
    local owner_pos = vec3.new(om[13], om[14], om[15])
    local dist = vec3.dist(bullet_pos, owner_pos)
    if dist > 50 then 
        client:despawn(entity.id)
    else
        local hit_target = nil
        ecs:forEach({"target"}, function (target)
            local tm = target.components.transform.matrix
            local target_pos = vec3.new(tm[13], tm[14], tm[15])
            local dist = vec3.dist(bullet_pos, target_pos)
            if dist < target.components.target.size then
                hit_target = target
            end
        end)

        if hit_target then
            client:despawn(entity.id)
            hit_target.components.target.hit_at = os.time()
            client:update(hit_target)
            local gun_ent = ecs:withId(entity.components.bullet.gun)
            gun_ent.components.gun.score = (gun_ent.components.gun.score or 0) + 1
            client:update(gun_ent)
        else
            client:update(entity)
        end
    end
end)

ecs:system({"hitCounter"}, function (counter, dt)
    local gun = ecs:withId(counter.components.hitCounter.gun)
    if not gun then return end
    if counter.components.text.string ~=  "" .. gun.components.gun.score then 
        counter.components.text.string = "" .. gun.components.gun.score
        client:update(counter)
    end
end)

ecs:system({"target"}, function (entity, dt)
    local m = mat4.new(entity.components.transform.matrix)
    m:translate(m, vec3.new(entity.components.target.speed) * dt)
    m._m = nil
    entity.components.transform.matrix = m

    if entity.components.target.hit_at then
        local delta = os.time() - entity.components.target.hit_at
        local pos = vec3(m[13], m[14], m[15])
        m:translate(m, -pos)
        m:scale(m, vec3.new(0.8))
        m:translate(m, pos)
        if delta > 0.2 then
            client:despawn(entity.id)
            client:spawn(MakeTarget())
        else
            client:update(entity)
        end
    else
        if m[14] < 1.5 then 
            entity.components.material.color[4] = m[14] - 0.5
        elseif m[14] > 11 then 
            client:despawn(entity.id)
            client:spawn(MakeTarget())
        elseif m[14] > 10 then
            entity.components.material.color[4] = 1 - (m[14] - 10)/1.0
        else
            entity.components.material.color[4] = 1
        end
        client:update(entity)
    end
end)

client.update = function (self, entity, components)
    components = components or entity.components
    self:sendInteraction({
        sender_entity_id = entity.id,
        receiver_entity_id = "place",
        body = {
            "change_components",
            entity.id,
            "add_or_change", components,
            "remove", {}
        }
    }, function (r)
        -- pp(r)
    end)
end

client.spawn = function (self, spec, callback)
    self:sendInteraction({
        receiver_entity_id = "place",
        body = {
            "spawn_entity",
            spec,
        }
    }, function (inter, body)
        if callback then 
            callback(body[2])
        else
            pp(inter)
        end
    end)
end

client.despawn = function (self, entity_id, callback)
    self:sendInteraction({
        sender_entity_id = entity_id,
        receiver_entity_id = "place",
        body = {
            "remove_entity",
            entity_id
        }
    }, function ()
        
    end)
end

function MakeTarget(random_height)
    local size = 0.6 + math.random()*0.4
    local function r(s) return math.random() * s - s*0.5 end
    local m = mat4.new()
    m:translate(m, vec3.new(0, 0, 0))
    m:translate(m, vec3.new(r(30), random_height and math.random(0, 10) or 0, r(30)))
    m:scale(m, vec3.new(size))
    m._m = nil
    return {
        target = {
            speed = { 0, math.random(), 0 },
            size = size,
        },
        transform = {
            matrix = m
        },
        geometry = {
            type = "asset",
            name = assets.target:id(),
        },
        material = {
            shader_name = "pbr",
            color = { math.random()*0.4+0.4, math.random()*0.4 + 0.4, math.random()*0.4+0.4, 0.0 },
        },
    }
end

function MakeHitCounter(gun_ent_id)
    local m = mat4.new()
    m:rotate(m, -math.pi/2, vec3.new(0, 0, 1))
    m:rotate(m, -0.07, vec3.new(0, 1, 0))
    m:translate(m, vec3.new(0.24, 0, 0.1875))
    m._m = nil
    return {
        hitCounter = {
            gun = gun_ent_id,
        },
        transform = {
            matrix = m,
        },
        text = {
            string = "42",
            height = 0.1,
            wrap = false,
            halign = "center",
        },
        relationships = {
            parent = gun_ent_id,
        },
    }
end

function MakeGun(parent_entity_id)
    local hand = ecs:withId(parent_entity_id).components.intent.actuate_pose
    local m = mat4.new()
    m:rotate(m, -math.pi*0.5, vec3.new(1, 0, 0))
    m:rotate(m, math.pi*0.5, vec3.new(0, 1, 0))
    m:scale(m, vec3.new(0.4))
    m:translate(m, vec3.new(0, 0.04, 0.01))
    if hand:match("left") then
        m:translate(m, vec3.new(0.02, 0, 0))
    else
        m:translate(m, vec3.new(-0.02, 0, 0))
    end
    m._m = nil
    return {
        gun = { 
            score = 0
        },
        geometry = {
            type = "asset",
            name = assets.gun:id()
        },
        transform = {
            matrix = m,
        },
        relationships = {
            parent = parent_entity_id
        },
        collider = {
            type = "box",
            width = 0.001,
            height = 0.1,
            depth = 0.1,
            x = 1.5,
        }
    }
end

function MakeBullet(t, owner_id, gun_id)
    local m = mat4.new()
    m:rotate(m, math.pi, vec3.new(0,1,0))
    m:scale(m, vec3.new(0.02))
    m:translate(m, vec3.new(0,0.08,-0.25))
    local hand = ecs:withId(owner_id).components.intent.actuate_pose
    if hand:match("left") then
        m:translate(m, vec3.new(0.02, 0, 0))
    else
        m:translate(m, vec3.new(-0.02, 0, 0))
    end
    m = t * m
    local q = mat4.new(t)
    q[13] = 0
    q[14] = 0
    q[15] = 0
    local forward = q * vec3.new(0, 0, -20)
    m._m = nil
    return {
        bullet = {
            owner = owner_id,
            gun = gun_id,
            speed = {forward.x, forward.y, forward.z}
        },
        geometry = {
            type = "asset",
            name = assets.bullet:id(),
        },
        transform = {
            matrix = m,
        },
        material = {
            shader_name = "pbr",
        }
    }
end

local Bullets = {
    bullets = {},
    requiredComponents = {"bullet"},
    forEachEntity = function (self, ent)

    end
}

local Guns = {
    guns = {},
    requiredComponents = {"intent"},
    forEachEntity = function (self, ent)
        if not ent.components.intent.actuate_pose:match("hand") then
            return
        end
        local guns = self.guns[ent.id]
        if not guns then
            self.guns[ent.id] = {}
            client:spawn(MakeGun(ent.id), function (gunEntityId)
                self.guns[ent.id].entity_id = gunEntityId
                client:spawn(MakeHitCounter(gunEntityId))
            end)
        end
    end
}

client.delegates.onInteraction = function (inter, body)
    -- if it's a poke and it's the start of the poke
    if body[1] == "poke" and body[2] then
        -- sender is the hand
        local gun = Guns.guns[inter.sender_entity_id]
        local gun_ent = ecs:withId(gun.entity_id)
        local t = mat4.new()
        local ent = ecs:withId(gun_ent.components.relationships.parent)
        while ent do
            t = mat4.new(ent.components.transform.matrix) * t
            ent = ent.components.relationships and ent.components.relationships.parent
            ent = ent and ecs:withId(ent)
            print("parent?", ent)
        end
        client:spawn(MakeBullet(t, inter.sender_entity_id, gun.entity_id))
        -- body = [=[["poke", true]]=],
        -- receiver_entity_id = "dwajcukmgi",
        -- request_id = "nhak5eLjQZ73yhAy",
        -- respond = "function: 0x02126658",
        -- sender_entity_id = "meslawuivh",
        -- type = "request"
    end
end

ecs:addSystem(Guns)

client.delegates.onConnected = function ()
    print("CONNEC")
    if #ecs:withComponents({"target"}) == 0 then 
        for i = 1, 12 do
            client:spawn(MakeTarget(true))
        end
    end
end

local deltaTime = 1/20
local m = mat4.new()
m._m = nil
local running = client:connect({dummy = {}})

while running do
    client:poll(deltaTime)
end
