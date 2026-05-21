local function hasStorageCrateAdminPermission(source)
    if IsPlayerAceAllowed(source, 'command.storagecrates') then
        return true
    end

    local player = exports['pulsar-core']:FetchSource(source)
    if player and player.Permissions then
        return player.Permissions:IsAdmin() or player.Permissions:GetLevel() >= 90
    end

    return false
end

local function getAdminLogContext(source)
    local player = exports['pulsar-core']:FetchSource(source)
    if not player then
        return 'Unknown', 'Unknown'
    end

    return player:GetData('Name') or 'Unknown', tostring(player:GetData('AccountID') or 'Unknown')
end

local function logStorageCrateAction(source, message)
    exports['pulsar-core']:LoggerWarn(
        'Admin',
        message,
        {
            console = true,
            file = false,
            database = true,
            discord = {
                embed = true,
                type = 'error',
                webhook = GetConvar('discord_admin_webhook', ''),
            },
        }
    )
end

local function getOwnerNamesBySid(ownerSids)
    local names = {}
    local unique = {}

    for _, sid in ipairs(ownerSids) do
        if sid and not unique[sid] then
            unique[sid] = true
        end
    end

    local sidList = {}
    for sid in pairs(unique) do
        sidList[#sidList + 1] = sid
    end

    if #sidList == 0 then
        return names
    end

    local placeholders = {}
    local params = {}

    for i = 1, #sidList do
        placeholders[i] = ('@sid%s'):format(i)
        params[('@sid%s'):format(i)] = sidList[i]
    end

    local query = ('SELECT SID, First, Last FROM characters WHERE SID IN (%s)'):format(table.concat(placeholders, ', '))
    local rows = MySQL.Sync.fetchAll(query, params)

    if rows then
        for _, row in ipairs(rows) do
            local first = row.First or ''
            local last = row.Last or ''
            local fullName = (('%s %s'):format(first, last)):gsub('^%s+', ''):gsub('%s+$', '')

            if fullName == '' then
                fullName = nil
            end

            names[tostring(row.SID)] = fullName
        end
    end

    for _, sid in ipairs(sidList) do
        if not names[sid] then
            local onlineChar = exports['pulsar-characters']:FetchBySID(sid)
            if onlineChar then
                local first = onlineChar:GetData('First') or ''
                local last = onlineChar:GetData('Last') or ''
                local fullName = (('%s %s'):format(first, last)):gsub('^%s+', ''):gsub('%s+$', '')
                if fullName ~= '' then
                    names[sid] = fullName
                end
            end
        end
    end

    return names
end

local function formatCrateRow(crateRow, activeCrate)
    local coordsData = {}
    local status = 'database_only'

    local success, decoded = pcall(json.decode, crateRow.coords)
    if success and decoded and decoded.x then
        coordsData = {
            x = decoded.x,
            y = decoded.y,
            z = decoded.z,
            route = tonumber(decoded.route) or 0,
        }
    end

    if activeCrate then
        status = 'active'
        coordsData = {
            x = activeCrate.coords.x,
            y = activeCrate.coords.y,
            z = activeCrate.coords.z,
            route = activeCrate.route or 0,
        }
    elseif coordsData.x then
        status = 'database_only'
    end

    return {
        id = crateRow.id,
        crateId = crateRow.crate_id,
        ownerSid = crateRow.owner_sid,
        tier = crateRow.tier,
        model = crateRow.model,
        coords = coordsData,
        heading = crateRow.heading or 0.0,
        hasPassword = crateRow.has_password == true or crateRow.has_password == 1 or crateRow.has_password == '1',
        createdAt = crateRow.created_at,
        stashId = 'crate:' .. crateRow.crate_id,
        status = status,
        inUse = activeCrate and exports['pulsar-storagecrates']:IsCrateInUse(crateRow.crate_id) or false,
    }
end

function RegisterStorageCrateCallbacks()
    exports['pulsar-core']:RegisterServerCallback('Admin:GetStorageCrates', function(source, data, cb)
        if not hasStorageCrateAdminPermission(source) then
            return cb(false)
        end

        if GetResourceState('pulsar-storagecrates') ~= 'started' then
            return cb({})
        end

        if data and data.reload == true then
            exports['pulsar-storagecrates']:ReloadAllCrates()
        end

        MySQL.query('SELECT * FROM storage_crates ORDER BY created_at DESC', {}, function(results)
            if not results or type(results) ~= 'table' then
                return cb({})
            end

            local ownerSids = {}
            for i = 1, #results do
                ownerSids[#ownerSids + 1] = results[i].owner_sid
            end

            local ownerNames = getOwnerNamesBySid(ownerSids)
            local formatted = {}

            for i = 1, #results do
                local row = results[i]
                local activeCrate = exports['pulsar-storagecrates']:GetCrateInfo(row.crate_id)
                local formattedRow = formatCrateRow(row, activeCrate)

                formattedRow.ownerName = ownerNames[tostring(row.owner_sid)]
                formatted[#formatted + 1] = formattedRow
            end

            cb(formatted)
        end)
    end)

    exports['pulsar-core']:RegisterServerCallback('Admin:GetStorageCrateById', function(source, data, cb)
        if not hasStorageCrateAdminPermission(source) then
            return cb(false)
        end

        if GetResourceState('pulsar-storagecrates') ~= 'started' then
            return cb(false)
        end

        local crateId = data and (data.crateId or data.id)
        if not crateId then
            return cb(false)
        end

        MySQL.query('SELECT * FROM storage_crates WHERE crate_id = ? LIMIT 1', { crateId }, function(result)
            if not result or not result[1] then
                return cb(false)
            end

            local activeCrate = exports['pulsar-storagecrates']:GetCrateInfo(crateId)
            local formattedRow = formatCrateRow(result[1], activeCrate)
            local ownerNames = getOwnerNamesBySid({ result[1].owner_sid })
            formattedRow.ownerName = ownerNames[tostring(result[1].owner_sid)]

            cb(formattedRow)
        end)
    end)

    exports['pulsar-core']:RegisterServerCallback('Admin:DeleteStorageCrate', function(source, data, cb)
        if not hasStorageCrateAdminPermission(source) then
            return cb({ success = false, message = 'No permission' })
        end

        if GetResourceState('pulsar-storagecrates') ~= 'started' then
            return cb({ success = false, message = 'pulsar-storagecrates is not running' })
        end

        local crateId = data and data.crateId
        if not crateId then
            return cb({ success = false, message = 'Missing crate ID' })
        end

        local crate = exports['pulsar-storagecrates']:GetCrateInfo(crateId)
        local ownerSid = crate and crate.ownerSid or 'unknown'
        local coords = crate and crate.coords or nil

        if not coords then
            local row = MySQL.Sync.fetchAll('SELECT owner_sid, coords FROM storage_crates WHERE crate_id = ? LIMIT 1', { crateId })
            if row and row[1] then
                ownerSid = row[1].owner_sid or ownerSid
                local success, decoded = pcall(json.decode, row[1].coords)
                if success and decoded then
                    coords = decoded
                end
            end
        end

        local ok, err = exports['pulsar-storagecrates']:AdminDeleteCrate(crateId)
        if not ok then
            return cb({ success = false, message = err or 'Failed to delete crate' })
        end

        local adminName, adminId = getAdminLogContext(source)
        local coordStr = coords and ('%.2f, %.2f, %.2f'):format(coords.x or 0, coords.y or 0, coords.z or 0) or 'unknown'

        logStorageCrateAction(
            source,
            ('%s [%s] deleted storage crate %s (owner SID: %s, coords: %s)'):format(
                adminName,
                adminId,
                crateId,
                ownerSid,
                coordStr
            )
        )

        TriggerClientEvent('pulsar-hud:Notification', source, 'success', 'Storage crate deleted', 3000)
        cb({ success = true, message = 'Storage crate deleted' })
    end)

    exports['pulsar-core']:RegisterServerCallback('Admin:RemoveStorageCrateEntity', function(source, data, cb)
        if not hasStorageCrateAdminPermission(source) then
            return cb({ success = false, message = 'No permission' })
        end

        if GetResourceState('pulsar-storagecrates') ~= 'started' then
            return cb({ success = false, message = 'pulsar-storagecrates is not running' })
        end

        local crateId = data and data.crateId
        if not crateId then
            return cb({ success = false, message = 'Missing crate ID' })
        end

        local ok, err = exports['pulsar-storagecrates']:AdminRemoveCrateEntity(crateId)
        if not ok then
            return cb({ success = false, message = err or 'Failed to remove crate entity' })
        end

        local adminName, adminId = getAdminLogContext(source)
        logStorageCrateAction(
            source,
            ('%s [%s] removed storage crate entity %s'):format(adminName, adminId, crateId)
        )

        TriggerClientEvent('pulsar-hud:Notification', source, 'success', 'Crate entity removed from world', 3000)
        cb({ success = true, message = 'Crate entity removed' })
    end)

    exports['pulsar-core']:RegisterServerCallback('Admin:TeleportToStorageCrate', function(source, data, cb)
        if not hasStorageCrateAdminPermission(source) then
            return cb({ success = false, message = 'No permission' })
        end

        local crateId = data and data.crateId
        local coords = data and data.coords

        if not coords and crateId and GetResourceState('pulsar-storagecrates') == 'started' then
            local crate = exports['pulsar-storagecrates']:GetCrateInfo(crateId)
            if crate and crate.coords then
                coords = {
                    x = crate.coords.x,
                    y = crate.coords.y,
                    z = crate.coords.z,
                }
            end
        end

        if not coords and crateId then
            local row = MySQL.Sync.fetchAll('SELECT coords, owner_sid FROM storage_crates WHERE crate_id = ? LIMIT 1', { crateId })
            if row and row[1] then
                local success, decoded = pcall(json.decode, row[1].coords)
                if success and decoded then
                    coords = decoded
                end
            end
        end

        if not coords or not coords.x or not coords.y or not coords.z then
            return cb({ success = false, message = 'Invalid crate coordinates' })
        end

        local ped = GetPlayerPed(source)
        SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 1.0, false, false, false, false)

        local adminName, adminId = getAdminLogContext(source)
        logStorageCrateAction(
            source,
            ('%s [%s] teleported to storage crate %s (coords: %.2f, %.2f, %.2f)'):format(
                adminName,
                adminId,
                crateId or 'unknown',
                coords.x,
                coords.y,
                coords.z
            )
        )

        TriggerClientEvent('pulsar-hud:Notification', source, 'success', 'Teleported to storage crate', 3000)
        cb({ success = true, message = 'Teleported to crate' })
    end)
end
