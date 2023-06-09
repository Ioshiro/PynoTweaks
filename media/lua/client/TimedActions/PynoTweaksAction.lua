require "TimedActions/ISBaseTimedAction"

PynoTweaksAction = ISBaseTimedAction:derive("PynoTweaksAction")

function PynoTweaksAction:isValid()
    return self.vehicle and not self.vehicle:isRemovedFromWorld()
end

function PynoTweaksAction:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function PynoTweaksAction:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
    self.item:setJobDelta(self:getJobDelta())
    self.item:setJobType(getText("ContextMenu_PynoTweaks_RemoveVehicle"))

    if not self.character:getEmitter():isPlaying(self.sound) then
        self.sound = self.character:playSound("BlowTorch")
    end
end

function PynoTweaksAction:start()
    self.item = self.character:getPrimaryHandItem()
    self:setActionAnim("BlowTorch")
    self:setOverrideHandModels(self.item, nil)
    self.sound = self.character:playSound("BlowTorch")
end

function PynoTweaksAction:stop()
    if self.item then
        self.item:setJobDelta(0)
    end
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function PynoTweaksAction:perform()
    if self.item then
        self.item:setJobDelta(0)
    end
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end

    -- Vehicle
    local vehicleName = self.vehicle:getScript():getName()
    local vehicleType = self.vehicle:getScript():getMechanicType()

    -- Basic outcome
    local metalSheet = math.floor(self.vArea / 14)
    local metalSheetSmall = math.floor((self.vArea - metalSheet) / 3)
    local metalBar = math.floor(self.vArea - metalSheet - metalSheetSmall)
    -- Other elements
    local metalPipe = 0
    local metalScrap = 1
    local metalUnusable = ZombRand(1)
    local electronicsScrap = 0
    local electricWire = ZombRand(1)
    local amplifiers = 0
    local fabric = 0
    local lightsItems = {}
    local tires = {}
    -- Items left in the vehicle
    local junk = {}

    -- Special vehicles and trailers
    if vehicleName == "VanRadio" or vehicleName == "VanAmbulance" then
        electronicsScrap = electronicsScrap + 1
        electricWire = electricWire + 1
    elseif PynoTweaks.Utils.isTrailer(self.vehicle) then
        electronicsScrap = 0
        electricWire = 1
    end

    if PynoTweaks.Utils.isBurnt(self.vehicle) then
        metalPipe = 1
        electronicsScrap = 0
        electricWire = 0
    end

    for i = 1, self.vehicle:getPartCount() do
        local part = self.vehicle:getPartByIndex(i - 1)
        local partId = part:getId()
        local partCondition = part:getCondition()

        local partItem = part:getInventoryItem()
        if partItem then
            -- The part is installed
            local partItemCondition = partItem:getCondition()
            local partItemType = partItem:getType()

            -- Collect items from all containers
            if part:isContainer() and not part:getContainerContentType() then
                local container = part:getItemContainer()
                for j = 1, container:getItems():size() do
                    local item = container:getItems():get(j - 1)
                    table.insert(junk, { item = item, area = part:getArea() })
                end
            end

            -- Don't give anything useful for brakes
            if partId:find("Brake") then
                metalUnusable = metalUnusable + 1
            end

            -- Give something for other parts
            if partItemCondition > 30 then
                if partId:find("Door") then
                    if partItemCondition > 70 then
                        metalSheet = metalSheet + 1
                    else
                        metalSheetSmall = metalSheetSmall + 1
                    end
                elseif partId:find("GasTank") then
                    if partItemCondition > 70 then
                        if partItemType:find("^Small") then
                            metalSheetSmall = metalSheetSmall + 1
                        elseif partItemType:find("^Normal") then
                            metalSheet = metalSheetSmall + 2
                        elseif partItemType:find("^Big") then
                            metalSheet = metalSheet + 1
                        end
                    end
                elseif partId:find("Muffler") then
                    if partItemCondition > 70 then
                        metalPipe = metalPipe + 1
                    else
                        metalPipe = metalPipe + 1
                    end
                elseif partId:find("Suspension") then
                    metalPipe = metalPipe + 1
                elseif partId:find("Tire") then
                    table.insert(tires, { item = partItem, area = part:getArea() })
                elseif partId:find("Headlight") then
                    table.insert(lightsItems, partItem)
                elseif partId:find("Radio") then
                    electronicsScrap = electronicsScrap + 1
                    electricWire = electricWire + 1
                elseif partId:find("Seat") then
                    fabric = fabric + 1
                end
            else
                -- The part item's condition is too bad to give anything useful
                if partId:find("Door") or partId:find("GasTank") or partId:find("Muffler") or partId:find("Suspension") then
                    metalUnusable = metalUnusable + 1
                end
            end
        else
            -- The part is not replaceable or part item is uninstalled
            if partId:find("lightbar") then
                electronicsScrap = electronicsScrap + 1
                amplifiers = amplifiers + 2
                -- Create light bulbs and amplifiers
                for _ = 1, 2 do
                    local lightBulb = InventoryItemFactory.CreateItem("Base.LightBulb")
                    lightBulb:setCondition(partCondition)
                    table.insert(lightsItems, lightBulb)
                end
            end
        end
    end

    -- Reduce output for smashed vehicles
    if PynoTweaks.Utils.isSmashed(self.vehicle) then
        metalSheet = math.floor(metalSheet * 0.5 + 0.2)
        metalSheetSmall = math.floor(metalSheetSmall * 0.4 + 0.2)
        metalBar = math.floor(metalBar * 0.5 + 0.2)
    end

    -- Create items and drop them on the ground
    local totalXp = 2

    -- Drop junk
    --if PynoTweaksOptions.dropJunk then
    for _, data in ipairs(junk) do
        self:dropItemInArea(data.item, data.area)
    end
    --end
    -- Drop the key from the player's inventory if exists
    local key = self.character:getInventory():haveThisKeyId(self.vehicle:getKeyId())
    if key then
        --if PynoTweaksOptions.dropJunk then
        self:dropItem(key)
        --else
        --    key:getContainer():Remove(key)
        --end
    end

    -- Metal
    for _ = 1, metalSheet do
        if self:checkDropItem("Base.SheetMetal") then
            totalXp = totalXp + 1
        else
            metalSheetSmall = metalSheetSmall + 1
        end
    end
    for _ = 1, metalSheetSmall do
        if self:checkDropItem("Base.SmallSheetMetal") then
            totalXp = totalXp + 1
        else
            metalScrap = metalScrap + 1
        end
    end
    for _ = 1, metalBar do
        if self:checkDropItem("Base.MetalBar") then
            totalXp = totalXp + 1
        else
            metalScrap = metalScrap + 1
        end
    end
    for _ = 1, metalPipe do
        if self:checkDropItem("Base.MetalPipe") then
            totalXp = totalXp + 1
        else
            metalScrap = metalScrap + 1
        end
    end
    -- Do after all metal items
    for _ = 1, metalScrap do
        if self:checkDropItem("Base.ScrapMetal") then
            totalXp = totalXp + 1
        else
            metalUnusable = metalUnusable + 1
        end
    end
    metalUnusable = math.floor(metalUnusable * 0.3)
    for _ = 1, metalUnusable do
        self:dropItem("Base.UnusableMetal")
    end

    -- Tires
    for _, data in ipairs(tires) do
        if ZombRand(140) < self.chance then
            local item = self:dropItemInArea(data.item, data.area)
            item:setCondition(ZombRand(10, item:getCondition()))
        end
    end

    -- Electrics
    for _ = 1, electricWire do
        if ZombRand(140) < self.chance then
            self:dropItem("Radio.ElectricWire")
        end
    end
    for _ = 1, electronicsScrap do
        if ZombRand(140) < self.chance then
            self:dropItem("Base.ElectronicsScrap")
        end
    end
    for _ = 1, amplifiers do
        if ZombRand(140) < self.chance then
            self:dropItem("Base.Amplifier")
        end
    end
    for i = 1, #lightsItems do
        if ZombRand(140) < self.chance then
            local lightBulb = self:dropItem(lightsItems[i])
            lightBulb:setCondition(ZombRand(10, lightBulb:getCondition()))
        end
    end

    -- Fabric
    for _ = 1, fabric do
        if ZombRand(140) < self.chance then
            -- Leather for sport cars, ripped sheets for the other types
            if vehicleType == 3 then
                self:dropItem("Base.LeatherStrips")
            else
                self:dropItem("Base.RippedSheets")
            end
        end
    end

    -- Use BlowTorch
    for _ = 1, self.propaneNeeded do
        self.item:Use()
    end

    -- Award with XP
    self.character:getXp():AddXP(Perks.MetalWelding, totalXp)
    -- Remove the vehicle
    sendClientCommand(self.character, "vehicle", "remove", { vehicle = self.vehicle:getId() })

    -- Remove the Timed Action from stack
    ISBaseTimedAction.perform(self)
end

function PynoTweaksAction:checkDropItem(item)
    if ZombRand(140) < self.chance then
        self:dropItem(item)
        return true
    end
    return false
end

function PynoTweaksAction:dropItem(item)
    return self.vehicle:getSquare():AddWorldInventoryItem(item, ZombRandFloat(0, 0.9), ZombRandFloat(0, 0.9), 0.0)
end

function PynoTweaksAction:dropItemInArea(item, area)
    local areaCenter = self.vehicle:getAreaCenter(area)
    if areaCenter then
        local x, y = areaCenter:getX(), areaCenter:getY()
        local square = getCell():getGridSquare(x, y, self.vehicle:getZ())
        return square:AddWorldInventoryItem(item, ZombRandFloat(0, 0.9), ZombRandFloat(0, 0.9), 0.0)
    else
        return self:dropItem(item)
    end
end

function PynoTweaksAction:new(character, vehicle, propaneNeeded)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.stopOnWalk = true
    o.stopOnRun = true
    o.character = character
    o.vehicle = vehicle
    o.propaneNeeded = propaneNeeded
    o.vArea = PynoTweaks.Utils.getBaseArea(vehicle)
    o.weldingLvl = character:getPerkLevel(Perks.MetalWelding)
    o.chance = 20 + o.weldingLvl * 7
    o.maxTime = o.vArea * 60 - o.weldingLvl * o.vArea * 1.2
    o.maxTime = o.maxTime * SandboxVars.PynoTweaks.ActionTimeMultiplier

    if character:isTimedActionInstant() then o.maxTime = 10 end
    --if ISVehicleMechanics.cheat then
    --    o.maxTime = 1
    --end
    return o
end