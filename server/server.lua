
_activeCrates = _activeCrates or {} 
_cratesInUse = _cratesInUse or {} 


local function GetCharacter(source)
    return exports['pulsar-characters']:FetchCharacterSource(source)
end

local function NormalizeSid(v)
    if v == nil then return nil end
    local s = tostring(v)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function SidEquals(a, b)
    local sa, sb = NormalizeSid(a), NormalizeSid(b)
    if not sa or not sb then return false end
    if sa == sb then return true end
    local na, nb = tonumber(sa), tonumber(sb)
    return na ~= nil and nb ~= nil and na == nb
end

local function ToBool(v)
    if v == nil then return false end
    if v == true then return true end
    if v == false then return false end
    if type(v) == 'number' then return v == 1 end
    if type(v) == 'string' then
        local s = v:lower()
        if s == 'true' then return true end
        if s == 'false' then return false end
        return tonumber(v) == 1
    end
    return false
end

local function GetRoute(source)
    return GetPlayerRoutingBucket(source) or 0
end

local function SendCrateToRoute(eventName, route, crateId, data)
    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)

        if target and (GetPlayerRoutingBucket(target) or 0) == route then
            TriggerClientEvent(eventName, target, crateId, data)
        end
    end
end

local function ClearCrateStash(crateId)
    local stashId = "crate:" .. crateId

    local cleared = pcall(function()
        exports.ox_inventory:ClearInventory(stashId)
    end)

    if cleared then
        return
    end

    local items = exports.ox_inventory:GetInventoryItems(stashId)
    if not items then
        return
    end

    for _, slot in pairs(items) do
        if slot and slot.name and (slot.count or 0) > 0 then
            pcall(function()
                exports.ox_inventory:RemoveItem(stashId, slot.name, slot.count)
            end)
        end
    end
end

local function FilterCratesForRoute(route)
    local filtered = {}
    for crateId, crate in pairs(_activeCrates) do
        if (crate.route or 0) == route then
            filtered[crateId] = crate
        end
    end
    return filtered
end


local function PrepareCratesForClient(crates)
    local prepared = {}
    for crateId, crate in pairs(crates) do
        prepared[crateId] = {
            id = crate.id,
            crateId = crate.crateId,
            ownerSid = crate.ownerSid,
            tier = crate.tier,
            model = crate.model,
            route = crate.route or 0,
            coords = {
                x = crate.coords.x,
                y = crate.coords.y,
                z = crate.coords.z
            },
            heading = crate.heading,
            hasPassword = crate.hasPassword,
            passwordHash = crate.passwordHash,
        }
    end
    return prepared
end


local function InitDatabase()
    MySQL.Sync.execute([[
        CREATE TABLE IF NOT EXISTS `storage_crates` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `crate_id` VARCHAR(50) NOT NULL UNIQUE,
            `owner_sid` VARCHAR(50) NOT NULL,
            `tier` VARCHAR(50) NOT NULL,
            `model` VARCHAR(100) NOT NULL,
            `coords` TEXT NOT NULL,
            `heading` FLOAT NOT NULL,
            `has_password` BOOLEAN NOT NULL DEFAULT FALSE,
            `password_hash` VARCHAR(255) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `owner_sid` (`owner_sid`),
            KEY `crate_id` (`crate_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    CreateThread(function()
        Wait(1000)
        LoadAllCrates()
    end)
end)


function LoadAllCrates()
    print("[STORAGE-CRATES] Loading crates from database...")
    _activeCrates = {}
    
    local crates = MySQL.Sync.fetchAll('SELECT * FROM storage_crates', {})
    
    if crates and #crates > 0 then
        print("[STORAGE-CRATES] Found " .. #crates .. " crates in database")
        
        for _, crate in ipairs(crates) do
            local success, coords = pcall(json.decode, crate.coords)
            if not success or not coords or not coords.x then
                goto continue
            end
            
            local crateId = crate.crate_id
            if not crateId then
                print("[STORAGE-CRATES] ERROR: Crate missing crate_id, skipping")
                goto continue
            end
            
            _activeCrates[crateId] = {
                id = crate.id,
                crateId = crateId,
                ownerSid = NormalizeSid(crate.owner_sid),
                tier = crate.tier,
                model = tonumber(crate.model) or crate.model,
                coords = vector3(coords.x, coords.y, coords.z),
                route = tonumber(coords.route) or 0,
                heading = crate.heading or 0.0,
                hasPassword = ToBool(crate.has_password),
                passwordHash = crate.password_hash,
            }
            exports[GetCurrentResourceName()]:EnsureStashExists(crateId, crate.tier)
            ::continue::
        end
        
        local loadedCount = 0
        for _ in pairs(_activeCrates) do loadedCount = loadedCount + 1 end
        Wait(2000) 
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local source = tonumber(playerId)
            if source then
                local route = GetRoute(source)
                local filtered = FilterCratesForRoute(route)
                local preparedCrates = PrepareCratesForClient(filtered)
                print(("[STORAGE-CRATES] Sending %d crates to player %d (restart route=%d)"):format(
                    (function(t) local c=0 for _ in pairs(t) do c=c+1 end return c end)(filtered),
                    source, route
                ))
                TriggerLatentClientEvent('StorageCrates:Client:SetupCrates', source, 50000, preparedCrates)
            end
        end
    else
        print("[STORAGE-CRATES] No crates found in database")
    end
end

function EnsureStashExists(crateId, tier)
    local tierConfig = Config.CrateTiers[tier]
    if not tierConfig then 
        return 
    end
    local stashId = "crate:" .. crateId
    local success, err = pcall(function()
        exports.ox_inventory:RegisterStash(stashId, tierConfig.label, tierConfig.maxSlots, tierConfig.maxWeight)
    end)
    
    if not success then
        pcall(function()
            exports.ox_inventory:CreateTemporaryStash({
                id = stashId,
                label = tierConfig.label,
                slots = tierConfig.maxSlots,
                maxWeight = tierConfig.maxWeight,
            })
        end)
    end
end

function GetCrateInfo(crateId)
    return _activeCrates[crateId]
end


function IsCrateInUse(crateId)
    return _cratesInUse[crateId] ~= nil
end


function SetCrateInUse(crateId, source)
    if source then
        _cratesInUse[crateId] = source
    else
        _cratesInUse[crateId] = nil
    end
end


AddEventHandler('ox_inventory:closedInventory', function(playerId, inventoryId)
    if type(inventoryId) ~= 'string' then return end
    if inventoryId:sub(1, 6) ~= 'crate:' then return end

    local crateId = inventoryId:sub(7)
    if crateId and _cratesInUse[crateId] == playerId then
        SetCrateInUse(crateId, nil)
    end
end)

RegisterNetEvent('StorageCrates:Server:RequestCrateInfo', function()
    local source = source
    local char = GetCharacter(source)
    if not char then return end
    
    local ownerSid = NormalizeSid(char:GetData("SID"))
    local crateInfos = {}
    local route = GetRoute(source)
    
    for crateId, crate in pairs(_activeCrates) do
        if (crate.route or 0) == route then
            crateInfos[crateId] = {
                isOwner = SidEquals(crate.ownerSid, ownerSid),
                hasPassword = crate.hasPassword,
            }
        end
    end

    if ownerSid and next(_activeCrates) then
        for crateId, crate in pairs(_activeCrates) do
            if not SidEquals(crate.ownerSid, ownerSid) then
                break
            end
        end
    end
    
    TriggerClientEvent('StorageCrates:Client:ReceiveCrateInfo', source, crateInfos)
end)


exports['pulsar-core']:MiddlewareAdd("Characters:Spawning", function(source)
    if _activeCrates and next(_activeCrates) then
        local route = GetRoute(source)
        local filtered = FilterCratesForRoute(route)
        local preparedCrates = PrepareCratesForClient(filtered)
        TriggerLatentClientEvent('StorageCrates:Client:SetupCrates', source, 50000, preparedCrates)
    end
end, 1)


RegisterNetEvent('StorageCrates:Server:RequestCrates', function()
    local source = source
    if not _activeCrates or next(_activeCrates) == nil then
        LoadAllCrates()
        Wait(500) 
    end
    
    if _activeCrates and next(_activeCrates) then
        local route = GetRoute(source)
        local filtered = FilterCratesForRoute(route)
        local crateCount = 0
        for _ in pairs(filtered) do crateCount = crateCount + 1 end
        local preparedCrates = PrepareCratesForClient(filtered)
        TriggerLatentClientEvent('StorageCrates:Client:SetupCrates', source, 50000, preparedCrates)
    else
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    for crateId, userId in pairs(_cratesInUse) do
        if userId == source then
            SetCrateInUse(crateId, nil)
        end
    end
end)


RegisterNetEvent('StorageCrates:Server:InventoryClosed', function()
    local source = source
    for crateId, userId in pairs(_cratesInUse) do
        if userId == source then
            SetCrateInUse(crateId, nil)
        end
    end
end)

function AdminRemoveCrateEntity(crateId)
    local crate = GetCrateInfo(crateId)
    if not crate then
        return false, "Crate not found in active cache"
    end

    local snap = {
        coords = {
            x = crate.coords.x,
            y = crate.coords.y,
            z = crate.coords.z,
        },
        heading = crate.heading or 0.0,
        model = crate.model,
    }

    SendCrateToRoute("StorageCrates:Client:RemoveCrate", crate.route or 0, crateId, snap)
    return true
end

function AdminDeleteCrate(crateId)
    local crate = GetCrateInfo(crateId)
    local route = crate and (crate.route or 0) or 0
    local snap

    if crate then
        snap = {
            coords = {
                x = crate.coords.x,
                y = crate.coords.y,
                z = crate.coords.z,
            },
            heading = crate.heading or 0.0,
            model = crate.model,
        }

        if IsCrateInUse(crateId) then
            SetCrateInUse(crateId, nil)
        end

        SendCrateToRoute("StorageCrates:Client:RemoveCrate", route, crateId, snap)
    else
        local row = MySQL.Sync.fetchAll(
            "SELECT coords, heading, model FROM storage_crates WHERE crate_id = ? LIMIT 1",
            { crateId }
        )

        if row and row[1] then
            local success, coords = pcall(json.decode, row[1].coords)

            if success and coords and coords.x then
                route = tonumber(coords.route) or 0
                snap = {
                    coords = {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                    },
                    heading = row[1].heading or 0.0,
                    model = tonumber(row[1].model) or row[1].model,
                }
                SendCrateToRoute("StorageCrates:Client:RemoveCrate", route, crateId, snap)
            end
        end
    end

    ClearCrateStash(crateId)

    local deletedRows = MySQL.Sync.execute("DELETE FROM storage_crates WHERE crate_id = ?", { crateId })
    local deleteOk = (type(deletedRows) == "number" and deletedRows >= 1) or deletedRows == true

    if not deleteOk then
        if crate and snap then
            SendCrateToRoute("StorageCrates:Client:SpawnCrate", route, crateId, {
                model = snap.model,
                coords = snap.coords,
                heading = snap.heading,
            })
        end
        return false, "Failed to remove crate from database"
    end

    _activeCrates[crateId] = nil
    SetCrateInUse(crateId, nil)

    return true
end

exports('GetCrateInfo', GetCrateInfo)
exports('IsCrateInUse', IsCrateInUse)
exports('SetCrateInUse', SetCrateInUse)
exports('EnsureStashExists', EnsureStashExists)
exports('AdminDeleteCrate', AdminDeleteCrate)
exports('AdminRemoveCrateEntity', AdminRemoveCrateEntity)
exports('ReloadAllCrates', LoadAllCrates)
