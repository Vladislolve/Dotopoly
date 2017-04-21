
-- "Rent" payment
function StPass(currentPos, pID)
	local kv = GameRules.kvStreets

	local owner = Monopoly:GetToken(pID):GetOwner()
	local building = Entities:FindByName(nil, ("street"..currentPos))
	local name = building:GetName()

	local rent = kv[name].Rent
	
	-- Building not owned by anyone
	-- If the building is not bought it should be
	-- immediately auctioned
	if building:GetOwner() == nil then
		building:SetOwner(owner)
		building:SetControllableByPlayer(pID, false)
		building:SetTeam(owner:GetTeamNumber())
		-- Building owned by another player (pay rent)
		-- TODO: has to check if houses are built in the street
	else
		--[[
			Check if the street doesn't need houses
			else it goes to the standard check of the entire set
		]]
		if kv[name].NoHouses == 1 then
			rent = GetRentValue(building)
		elseif IsSetOwnedByPlayer(building,building:GetPlayerOwnerID()) == true then
			rent = GetStreetHouseValue(building)
		end

		-- Player pays if it's not his estate
		if building:GetOwner() ~= owner then
			PlayerResource:ModifyGold(pID,-rent,false,0)
		end
		
	end

end

-- Check whether its a dice throw or an order to
-- jump to a certain location (ex. to jail)
function MoveToken(rand1,rand2, pID, jumpToLocation)
	local nMovements = rand1 + rand2
	local token = Monopoly:GetToken(pID)
	local nextPos

	if jumpToLocation == false then
		nextPos = CheckForFinish(pID,nMovements)

		ExecuteOrderFromTable{
		UnitIndex = token:entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
		Position = Entities:FindByName(nil,"path"..nextPos):GetAbsOrigin(),
		Queue = false}
	elseif jumpToLocation == true then
		nextPos = nMovements

		ExecuteOrderFromTable{
		UnitIndex = token:entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
		Position = Entities:FindByName(nil,"path"..nextPos):GetAbsOrigin(),
		Queue = false}
	end
	-- Update token position and last dice thrown
	Monopoly:SetCurrentPos(nextPos,pID)
	Monopoly:SetLastDiceThrown(rand1+rand2,pID)

	local movement_data = {pID = pID, nStreet = nextPos}
	CustomGameEventManager:Send_ServerToAllClients( "monopoly_movement_notification",movement_data)

	CheckEvent(nextPos,pID)
end

-- Check if token is moving over 39
-- reset to 0 + the number of dice
function CheckForFinish(pID, nMovements)
	local nextPos = Monopoly:GetCurrentPos(pID) + nMovements

	if nextPos <= 39 then
		return nextPos
	elseif nextPos > 39 then
		return nMovements - 1
	end

end

-- Checks for player position and what function to call
function CheckEvent(pos, pID)
	local kvStreet = GameRules.kvStreets
	-- Find the name of the street
	local name = kvStreet["street"..pos]
	local functionName

	-- Check whether the street is a "special" one, or standard
	if name["Special"] == nil then
		StPass(pos,pID)
	else
		functionName = name["Special"]
		--[[ Throws specific event depending in which street
			the player landed on ]]
		SPECIAL_EVENT_CODES[functionName](pos,pID)
	end

end
