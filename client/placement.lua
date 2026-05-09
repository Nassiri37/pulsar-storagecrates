local Callbacks = {}
function Callbacks:ServerCallback(name, data, cb)
    exports["pulsar-core"]:ServerCallback(name, data, cb)
end

RegisterNetEvent('StorageCrates:Client:StartPlacement', function(tier, slot)
    print("[STORAGE-CRATES CLIENT] StartPlacement event received, tier:", tier, "slot:", slot)
    
    if not Config or not Config.CrateTiers then
        print("[STORAGE-CRATES CLIENT] ERROR: Config not loaded")
        exports['pulsar-hud']:Notification("error", "Configuration not loaded", 5000)
        return
    end
    local tierConfig = Config.CrateTiers[tier]
    if not tierConfig then
        print("[STORAGE-CRATES CLIENT] ERROR: Invalid tier:", tier)
        exports['pulsar-hud']:Notification("error", "Invalid crate tier: " .. tostring(tier), 5000)
        return
    end
    print("[STORAGE-CRATES CLIENT] Tier config found:", json.encode(tierConfig))
    local model = tierConfig.model
    print("[STORAGE-CRATES CLIENT] Model before conversion:", model, "type:", type(model))
    
    if type(model) == "string" then
        model = GetHashKey(model)
    end
    print("[STORAGE-CRATES CLIENT] Model hash:", model)
    if not exports['pulsar-objects'] or not exports['pulsar-objects'].PlacerStart then
        print("[STORAGE-CRATES CLIENT] ERROR: pulsar-objects PlacerStart not found!")
        exports['pulsar-hud']:Notification("error", "Placement system not available", 5000)
        return
    end
    
    print("[STORAGE-CRATES CLIENT] Calling PlacerStart with model:", model)
    local success, err = pcall(function()
        exports['pulsar-objects']:PlacerStart(model, 'StorageCrates:Client:FinishPlacement', { tier = tier, slot = slot }, true)
    end)
    if not success then
        print("[STORAGE-CRATES CLIENT] ERROR calling PlacerStart:", err)
        exports['pulsar-hud']:Notification("error", "Failed to start placement: " .. tostring(err), 5000)
    else
        print("[STORAGE-CRATES CLIENT] PlacerStart called successfully")
    end
end)


AddEventHandler('StorageCrates:Client:FinishPlacement', function(data, endCoords)
    if not data or not data.tier then
        exports['pulsar-hud']:Notification("error", "Invalid placement data", 5000)
        return
    end
    local tier = data.tier
    local slot = data.slot
    local tierConfig = Config.CrateTiers[tier]
    if not tierConfig then
        exports['pulsar-hud']:Notification("error", "Invalid crate tier", 5000)
        return
    end
    TaskTurnPedToFaceCoord(PlayerPedId(), endCoords.coords.x, endCoords.coords.y, endCoords.coords.z, 0.0)
    Wait(1000)
    exports['pulsar-hud']:Progress({
        name = 'storage_crate_place',
        duration = 5000,
        label = 'Placing Storage Crate',
        useWhileDead = false,
        canCancel = true,
        ignoreModifier = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            task = 'CODE_HUMAN_MEDIC_KNEEL',
        },
    }, function(wasCancelled)
        if not wasCancelled then
            Callbacks:ServerCallback("StorageCrates:PlaceCrate", {
                tier = tier,
                coords = endCoords.coords,
                heading = endCoords.heading or 0.0,
                slot = slot,
            }, function(success, errorMsg)
                if success then
                    exports['pulsar-hud']:Notification("success", "Crate placed successfully!", 5000)
                else
                    exports['pulsar-hud']:Notification("error", errorMsg or "Failed to place crate", 5000)
                end
            end)
        end
    end)
end)
