RegisterNUICallback('GetStorageCrates', function(data, cb)
    exports['pulsar-core']:ServerCallback('Admin:GetStorageCrates', data, cb)
end)

RegisterNUICallback('GetStorageCrateById', function(data, cb)
    exports['pulsar-core']:ServerCallback('Admin:GetStorageCrateById', data, cb)
end)

RegisterNUICallback('DeleteStorageCrate', function(data, cb)
    exports['pulsar-core']:ServerCallback('Admin:DeleteStorageCrate', data, function(result)
        if result and result.success then
            cb({ success = true, message = result.message or 'Storage crate deleted' })
        else
            cb({ success = false, message = (result and result.message) or 'Failed to delete storage crate' })
        end
    end)
end)

RegisterNUICallback('RemoveStorageCrateEntity', function(data, cb)
    exports['pulsar-core']:ServerCallback('Admin:RemoveStorageCrateEntity', data, function(result)
        if result and result.success then
            cb({ success = true, message = result.message or 'Crate entity removed' })
        else
            cb({ success = false, message = (result and result.message) or 'Failed to remove crate entity' })
        end
    end)
end)

RegisterNUICallback('TeleportToStorageCrate', function(data, cb)
    exports['pulsar-core']:ServerCallback('Admin:TeleportToStorageCrate', data, function(result)
        if result and result.success then
            cb({ success = true, message = result.message or 'Teleported to crate' })
        else
            cb({ success = false, message = (result and result.message) or 'Failed to teleport' })
        end
    end)
end)

RegisterNUICallback('SetStorageCrateWaypoint', function(data, cb)
    if not data or not data.coords or not data.coords.x or not data.coords.y then
        cb({ success = false, message = 'Invalid coordinates' })
        return
    end

    SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
    cb({ success = true, message = 'Waypoint set' })
end)
