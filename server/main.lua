ESX 				= nil
local vehicle_data 		= {}

TriggerEvent("esx:getSharedObject", function(library) 
	ESX = library 
end)

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		getvehiclesList()
	end
end)

RegisterServerEvent('shorty_slocks:getLockStatus')
AddEventHandler('shorty_slocks:getLockStatus', function(plate, doorangle, modelHash, lockstatus, class, call)
	local plateStripped = string.gsub(plate, "%s+", "")
	local _source = source
	local Cclass = class

	if call == 'outside' then
		if not vehicle_data[plateStripped] then
			getlockStatus(plate, class, doorangle, modelHash, lockstatus)
			setvehicleLocks(plate, plateStripped, call)
		else
			setvehicleLocks(plate, plateStripped, call)
		end
	elseif call == 'inside' then
		if not vehicle_data[plateStripped] then
			getlockStatus(plate, Cclass, doorangle, modelHash, lockstatus)
			setvehicleLocks(plate, plateStripped, call)
		else
			if vehicle_data[plateStripped].lockstatus == true then 
				vehicle_data[plateStripped].lockstatus = 4
			elseif vehicle_data[plateStripped].lockstatus == 4 then 
				vehicle_data[plateStripped].lockstatus = false
			elseif vehicle_data[plateStripped].lockstatus == false then
				vehicle_data[plateStripped].lockstatus = true
			end

			setvehicleLocks(plate, plateStripped, call)
		end
	elseif call == 'exiting'  then
		if not vehicle_data[plateStripped] then
			getlockStatus(plate, Cclass, doorangle, modelHash, lockstatus)

			if vehicle_data[plateStripped].lockstatus == true or vehicle_data[plateStripped].lockstatus == 4 then
				vehicle_data[plateStripped].lockstatus = false
				setvehicleLocks(plate, plateStripped, call)
			end
		else
			if vehicle_data[plateStripped].lockstatus == true or vehicle_data[plateStripped].lockstatus == 4 then
				vehicle_data[plateStripped].lockstatus = false
				setvehicleLocks(plate, plateStripped, call)
			end
			setvehicleLocks(plate, plateStripped, call)
		end
	elseif call == 'remote' then
		if not vehicle_data[plateStripped] then
			getlockStatus(plate, Cclass, doorangle, modelHash, lockstatus)

			if isAuthorised(plate) then
				setvehicleLocks(plate, plateStripped, call)
			else
				setvehicleLocks(nil, nil, 'notauth')
			end
		else
			if isAuthorised(plate) then
				vehicle_data[plateStripped].lockstatus = not vehicle_data[plateStripped].lockstatus
				setvehicleLocks(plate, plateStripped, call)
			else
				setvehicleLocks(nil, nil, 'notauth')			
			end
		end
	end
end)

getvehiclesList = function()
	MySQL.Async.fetchAll('SELECT owner, plate FROM owned_vehicles', {}, function(result)
		if #result > 0 then
			for i = 1, #result do
				local plateStripped = string.gsub(result[i].plate, "%s+", "")
				vehicle_data[plateStripped] = { owner = result[i].owner, lockstatus = Config.defLock }
			end
		end
	end)
end

getlockStatus = function(plate, class, doorangle, modelHash, lockstatus)
	local plateStripped = string.gsub(plate, "%s+", "")

	if vehicle_data[plateStripped] then
		return(vehicle_data[plateStripped].lockstatus)
	else

		if Config.lockNPC == true then
			LockChance = lockChance(doorangle, modelHash, lockstatus)
		else
			LockChance = false
		end
		vehicle_data[plateStripped] = {owner = class, lockstatus = LockChance}		
		return(vehicle_data[plateStripped].lockstatus)
	end
end

setvehicleLocks = function(plate, plateStripped, call)
	local _source = source

	if call == 'notauth' then
		TriggerClientEvent('shorty_slocks:setvehicleLock', _source, nil, nil, call, false)
		return
	end

	local players = nil
	local players = GetPlayers()

	TriggerClientEvent('shorty_slocks:setvehicleLock', _source, plate, vehicle_data[plateStripped].lockstatus, call, true)
	
	for _,player in pairs(players) do
		if _source ~= tonumber(player) then
			TriggerClientEvent('shorty_slocks:setvehicleLock', player, plate, vehicle_data[plateStripped].lockstatus, call, false)
		end
	end
end

lockChance = function(doorangle, modelHash, lockstatus)
	local chance = math.random(100)

	if Config.lChance > 100 then
		Config.lChance = 100
	elseif Config.lChance < 0 then
		Config.lChance = 0
	end
	
	if doorangle > 0.0 then
		return false
	end

	if lockstatus == 7 then
		if chance > Config.lChance then
			return true
		else
			return lockstatus
		end
	end

	for k,v in pairs(Config.blacklist) do
		if modelHash == GetHashKey(v) then
			return true
		end
	end

	return (chance > Config.lChance)
end

isAuthorised = function(plate)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local identifier = xPlayer.identifier
	local plateStripped = string.gsub(plate, "%s+", "")
	local playerJob = xPlayer.getJob()

	if vehicle_data[plateStripped].owner == identifier then
		return true
	end

	if vehicle_data[plateStripped].owner == 18 then
		for i=1, #Config.emergencyJob do
			if playerJob.name == Config.emergencyJob[i] then
				return true
			end
		end
	end

	for i=1, #Config.JobsandPlates do
		if vehicle_data[plateStripped] then		
			jobPlate = string.gsub(plateStripped, "[0-9]", "")
			jobplateStripped = string.gsub(jobPlate, "%s+", "")
			if Config.JobsandPlates[i].job == playerJob.name and Config.JobsandPlates[i].plate == jobplateStripped then
				return true
			end
		end
	end

end
