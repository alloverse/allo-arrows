
local pp = require('pl.pretty').dump

local Class = require 'pl.class'

local ECS = Class.ECS()
function ECS:_init()
    self.systems = {}
    self.state = {
        entities = {}
    }
end

function ECS:withComponents(components)
    -- todo: iterators!
    --todo track entities in component => entitites maps for lookup speeds
    local list = {}
    for _, entity in pairs(self.state.entities) do
        local has_all = true
        for _, component in ipairs(components) do
            if not entity.components[component] then
                has_all = false
                break
            end
        end
        if has_all then
            table.insert(list, entity)
        end
    end
    return list
end

function ECS:forEach(components, func)
    local entities = self:withComponents(components)
    for _, ent in ipairs(entities) do
        func(ent)
    end
end

function ECS:withId(id)
    return self.state.entities[id]
end

--- Implement a system by applying a function to each entity that has a component
function ECS:system(components, onUpdate, onDraw)
    -- TODO: threading
    -- Note: must have parenting checks to make sure the parent processes first and on same thread as child
    table.insert(self.systems, System(components, onUpdate, onDraw))
end

function ECS:addSystem(system)
    table.insert(self.systems, system)
end

function ECS:setState(state)
    self.state = state
end

function ECS:update(deltaTime)
    for _, system in ipairs(self.systems) do
        if system.update or system.forEachEntity then
            assert(system.requiredComponents, "no components in system " .. (system._name or ""))
            local entities = self:withComponents(system.requiredComponents)
            if system.update then
                system:update(entities, deltaTime)
            end
            if system.forEachEntity then 
                for _, ent in ipairs(entities) do
                    system:forEachEntity(ent)
                end
            end
        end
    end
end

System = Class.System()
function System:_init(components, onUpdate, onDraw)
    assert(components, "no components")
    self.requiredComponents = components
    if onUpdate then
        self.update = function (self, entities, deltaTime)
            for _, entity in ipairs(entities) do
                self.onUpdate(entity, deltaTime)
            end
        end
    end
    if onDraw then
        self.draw = function (self, entities)
            for _, entity in ipairs(entities) do
                self.onDraw(entity)
            end
        end
    end
    self.onUpdate = onUpdate
    self.onDraw = onDraw
end

return ECS