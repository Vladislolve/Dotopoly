
-- Used for building the house next to the path
-- and the street
function BuildHouse( pathName, streetName, pID )
	local path = Entities:FindByName(nil, pathName)
	local street = Entities:FindByName(nil, streetName)
	local owner = street:GetOwner()
	local unitOwner = street:GetPlayerOwner()
	local teamNumber = street:GetTeamNumber()

	local pathOrigin = path:GetAbsOrigin()
	local streetFv = street:GetForwardVector()
	local origin =  pathOrigin + streetFv * -400

	local house = CreateUnitByName("npc_monopoly_house", origin, true, owner, unitOwner, teamNumber)
	house:SetForwardVector(streetFv)

end

--[[
	Checks if a set of streets are owned
	by the same player
	and adds options to buy houses and hotels
]]
function CheckForSet(kv, estate, pID)
	local name = estate:GetName()

	-- Does the entity have the ability already? TODO: Used in one or two times for this, make another function
	if estate:FindAbilityByName("buy_house") then
		return true
	end       

	local set = FindStreetSet(estate)
	local bFullOwnership = IsSetOwnedByPlayer(estate,pID)

	for k,v in pairs(set) do
		if bFullOwnership == true then
			v:AddAbility("buy_house"):SetLevel(1)
		else
			return false
		end
	end

	return false
end

-- True if the player owwns all streets from the set
function IsSetOwnedByPlayer(entEstate, pID)
	local set = FindStreetSet(entEstate)
	for k,v in pairs(set) do
		if v:GetPlayerOwnerID() ~= pID then
			return false
		end
	end
	return true
end

function IsStreetOwnedByPlayer(sName, pID)
	local streets = Monopoly:GetPlayerStreets(pID)

		for k,v in pairs(streets) do
			if v == sName then
				return true
			end
		end
	return false

end

-- Check how much the player has to pay
-- when placed in a specific street
function GetStreetHouseValue(estate)
	local kv = GameRules.kvStreets
	local ability = estate:FindAbilityByName("buy_house")
	local level = ability:GetLevel() - 1
	local rent = kv[estate:GetName()]["House"..level]

	if rent == nil then
		rent = kv[estate:GetName()].Rent * 2
	end
	
	return rent
end

-- Delete all the house from the street
--[[ Very bug prone. Only checks if its
an npc_dota_creature in the radius, so no other
entities of the same class allowed ]]
function DeleteHouses(streetName)
	local street = Entities:FindByName(nil, streetName)
	local pathName = "path"..Utilities:GetLastChar(streetName)
	local path = Entities:FindByName(nil, pathName)

	local pathOrigin = path:GetAbsOrigin()
	local streetFv = street:GetForwardVector()
	local origin =  pathOrigin + streetFv * -400

	local ability = street:FindAbilityByName("buy_house")
	if ability == nil then
		print("This street doesn't have houses")
		return
	end

	local abilityLevel = ability:GetLevel()
	local house = Entities:FindByNameWithin(nil,"npc_dota_creature",origin,300)
	local entHouse = house

	for i=1,abilityLevel - 1 do
		UTIL_Remove(entHouse)
		house = Entities:FindByNameWithin(Entities:Next(house),"npc_dota_creature",origin,300)
		entHouse = house
	end
	ability:SetLevel(1)

end

-- Returns streets that are of the same set of the argument, else returns empty set
-- estate: Entity
function FindStreetSet(estate)
	local kv = GameRules.kvStreets

	local name = estate:GetName()
	local number = Utilities:GetLastChar(name)
	local set = {}
	set["street"..number] = estate

	for i=1, 10 do 
		local link = kv[name]["Link"..i]
		local linkEstate = Entities:FindByName(nil,link)
		if linkEstate ~= nil then
			set[link] = linkEstate
			else if i == 1 then
				return {}
			else
				return set
			end
		end
	end

end

-- Gets the rent from estates/heroes where their rent increases based on
-- how many heroes of the set they have, without the need to buy houses
function GetRentValue(entEstate)
	local kv = GameRules.kvStreets
	local set = FindStreetSet(entEstate)
	local pID = entEstate:GetPlayerOwnerID()
	local name = entEstate:GetName()
	local mult = 0
	local rent = 0
	
	-- How many streets of the set the player has
	for k,v in pairs(set) do
		if IsStreetOwnedByPlayer(k,pID) then
			mult = mult + 1
		end
	end
	
	-- Find the appropiate rent in the kv
	rent = kv[name]["Rent"..mult]
	return rent
end

-- Swap street from one pID to another
function SwapStreets(oldPID,newPID,streetName)
	local owner = Monopoly:GetToken(newPID):GetOwner()
	local entStreet = Entities:FindByName(nil,streetName)
	local streetSet = FindStreetSet(entStreet)

	RemoveSetCondition(entStreet)
	Monopoly:RemoveStreetFromPlayer(streetName,oldPID)

	entStreet:SetOwner(owner)
	entStreet:SetControllableByPlayer(newPID, false)
	entStreet:SetTeam(owner:GetTeamNumber())
	CheckForSet(kvStreets,entStreet,newPID)
	Monopoly:AddStreetToPlayer(streetName,newPID)
end

-- Removes 'buy_house' ability from the entire set
-- and deletes all houses from the set
function RemoveSetCondition(entStreet)
	local streetSet = FindStreetSet(entStreet)

	for k,v in pairs(streetSet) do
		DeleteHouses(k) -- Delete houses fist, as it relies on 'buy_house' ability
		v:RemoveAbility("buy_house")
	end

end