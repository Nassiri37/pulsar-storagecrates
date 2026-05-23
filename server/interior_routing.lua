-- Interior-aware routing for storage crates.
-- apartment_id / property_id are permanent placement references; routing bucket is runtime-only.

InteriorRouting = InteriorRouting or {}

local function NormalizeSid(v)
    if v == nil then return nil end
    local s = tostring(v)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

function InteriorRouting.NormalizeSid(v)
    return NormalizeSid(v)
end

function InteriorRouting.SidEquals(a, b)
    local sa, sb = NormalizeSid(a), NormalizeSid(b)
    if not sa or not sb then return false end
    if sa == sb then return true end
    local na, nb = tonumber(sa), tonumber(sb)
    return na ~= nil and nb ~= nil and na == nb
end

function InteriorRouting.BuildApartmentId(inApartment)
    if not inApartment or inApartment.type == nil or inApartment.id == nil then
        return nil
    end
    return ("apt:%s:%s"):format(tostring(inApartment.type), tostring(inApartment.id))
end

function InteriorRouting.ParseApartmentId(apartmentId)
    if not apartmentId or apartmentId == "" then
        return nil, nil
    end
    local aptType, ownerSid = apartmentId:match("^apt:(%d+):(.+)$")
    if aptType then
        return tonumber(aptType), ownerSid
    end
    return nil, nil
end

function InteriorRouting.GetApartmentBucket(apartmentId)
    local aptType, _ = InteriorRouting.ParseApartmentId(apartmentId)
    if not aptType then
        return nil
    end

    local aptData = GlobalState[("Apartment:%s"):format(aptType)]
    if not aptData or not aptData.buildingName or aptData.floor == nil then
        return nil
    end

    local routeName = ("Apartment:Floor:%s:%s"):format(aptData.buildingName, aptData.floor)
    local ok, routeId = pcall(function()
        return exports["pulsar-core"]:RequestRouteId(routeName, false)
    end)

    if ok and routeId then
        return tonumber(routeId)
    end

    return nil
end

function InteriorRouting.GetPropertyBucket(propertyId)
    if not propertyId or propertyId == "" then
        return nil
    end

    local ok, routeId = pcall(function()
        return exports["pulsar-core"]:RequestRouteId("Properties:" .. tostring(propertyId), false)
    end)

    if ok and routeId then
        return tonumber(routeId)
    end

    return nil
end

function InteriorRouting.ResolveCrateBucket(crate)
    if not crate then
        return 0
    end

    local bucket

    if crate.apartmentId and crate.apartmentId ~= "" then
        bucket = InteriorRouting.GetApartmentBucket(crate.apartmentId)
    elseif crate.propertyId and crate.propertyId ~= "" then
        bucket = InteriorRouting.GetPropertyBucket(crate.propertyId)
    end

    if not bucket then
        bucket = tonumber(crate.lastBucket) or tonumber(crate.route) or 0
    end

    return bucket
end

function InteriorRouting.GetPlayerInteriorContext(source)
    local bucket = GetPlayerRoutingBucket(source) or 0
    local char = exports["pulsar-characters"]:FetchCharacterSource(source)
    local ownerSid = char and NormalizeSid(char:GetData("SID")) or nil

    local apartmentId = nil
    local propertyId = nil

    local player = Player(source)
    if player and player.state then
        apartmentId = InteriorRouting.BuildApartmentId(player.state.inApartment)
    end

    local prop = GlobalState[("%s:Property"):format(source)]
    if prop ~= nil and prop ~= "" then
        propertyId = tostring(prop)
    end

    return {
        bucket = bucket,
        ownerSid = ownerSid,
        apartmentId = apartmentId,
        propertyId = propertyId,
    }
end

function InteriorRouting.CrateMatchesContext(crate, ctx)
    if not crate or not ctx then
        return false
    end

    if crate.apartmentId and crate.apartmentId ~= "" then
        return ctx.apartmentId ~= nil and crate.apartmentId == ctx.apartmentId
    end

    if crate.propertyId and crate.propertyId ~= "" then
        return ctx.propertyId ~= nil and crate.propertyId == ctx.propertyId
    end

    local crateBucket = tonumber(crate.lastBucket) or tonumber(crate.route) or 0
    return crateBucket == (ctx.bucket or 0)
end

function InteriorRouting.FilterCratesForPlayer(ctx)
    local filtered = {}
    for crateId, crate in pairs(_activeCrates) do
        if InteriorRouting.CrateMatchesContext(crate, ctx) then
            InteriorRouting.ApplyResolvedRoute(crate)
            filtered[crateId] = crate
        end
    end
    return filtered
end

function InteriorRouting.SendCrateToInterestedPlayers(eventName, crate, crateId, data)
    if not crate then
        return
    end

    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target then
            local ctx = InteriorRouting.GetPlayerInteriorContext(target)
            if InteriorRouting.CrateMatchesContext(crate, ctx) then
                TriggerClientEvent(eventName, target, crateId, data)
            end
        end
    end
end

function InteriorRouting.MigrateLegacyCratesForContext(source, ctx)
    if not ctx or not ctx.ownerSid then
        return
    end

    local player = Player(source)
    local inApt = player and player.state and player.state.inApartment

    if ctx.apartmentId and inApt and InteriorRouting.SidEquals(inApt.id, ctx.ownerSid) then
        MySQL.Sync.execute(
            "UPDATE storage_crates SET apartment_id = ? WHERE owner_sid = ? AND apartment_id IS NULL AND property_id IS NULL AND (last_bucket IS NOT NULL AND last_bucket > 0)",
            { ctx.apartmentId, ctx.ownerSid }
        )

        for _, crate in pairs(_activeCrates) do
            if InteriorRouting.SidEquals(crate.ownerSid, ctx.ownerSid)
                and (not crate.apartmentId or crate.apartmentId == "")
                and (not crate.propertyId or crate.propertyId == "")
                and (tonumber(crate.lastBucket) or 0) > 0
            then
                crate.apartmentId = ctx.apartmentId
                InteriorRouting.ApplyResolvedRoute(crate)
            end
        end
    elseif ctx.propertyId then
        MySQL.Sync.execute(
            "UPDATE storage_crates SET property_id = ? WHERE owner_sid = ? AND apartment_id IS NULL AND property_id IS NULL AND (last_bucket IS NOT NULL AND last_bucket > 0)",
            { ctx.propertyId, ctx.ownerSid }
        )

        for _, crate in pairs(_activeCrates) do
            if InteriorRouting.SidEquals(crate.ownerSid, ctx.ownerSid)
                and (not crate.apartmentId or crate.apartmentId == "")
                and (not crate.propertyId or crate.propertyId == "")
                and (tonumber(crate.lastBucket) or 0) > 0
            then
                crate.propertyId = ctx.propertyId
                InteriorRouting.ApplyResolvedRoute(crate)
            end
        end
    end
end

function InteriorRouting.SyncPlayerInteriorBuckets(source)
    local ctx = InteriorRouting.GetPlayerInteriorContext(source)
    if not ctx.ownerSid then
        return
    end

    InteriorRouting.MigrateLegacyCratesForContext(source, ctx)

    if ctx.apartmentId then
        MySQL.Sync.execute(
            "UPDATE storage_crates SET last_bucket = ? WHERE owner_sid = ? AND apartment_id = ?",
            { ctx.bucket, ctx.ownerSid, ctx.apartmentId }
        )

        for _, crate in pairs(_activeCrates) do
            if InteriorRouting.SidEquals(crate.ownerSid, ctx.ownerSid) and crate.apartmentId == ctx.apartmentId then
                crate.lastBucket = ctx.bucket
                crate.route = ctx.bucket
            end
        end
    elseif ctx.propertyId then
        MySQL.Sync.execute(
            "UPDATE storage_crates SET last_bucket = ? WHERE owner_sid = ? AND property_id = ?",
            { ctx.bucket, ctx.ownerSid, ctx.propertyId }
        )

        for _, crate in pairs(_activeCrates) do
            if InteriorRouting.SidEquals(crate.ownerSid, ctx.ownerSid) and crate.propertyId == ctx.propertyId then
                crate.lastBucket = ctx.bucket
                crate.route = ctx.bucket
            end
        end
    end
end

function InteriorRouting.GetPlacementContext(source)
    local ctx = InteriorRouting.GetPlayerInteriorContext(source)
    return {
        bucket = ctx.bucket,
        ownerSid = ctx.ownerSid,
        apartmentId = ctx.apartmentId,
        propertyId = ctx.propertyId,
    }
end

function InteriorRouting.ApplyResolvedRoute(crate)
    if not crate then
        return
    end
    crate.route = InteriorRouting.ResolveCrateBucket(crate)
end
