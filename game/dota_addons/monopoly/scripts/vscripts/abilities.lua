--[[ All functions in abilities.lua are linked to a specific ability
     in npc_abilities_custom.txt.
     In every function it specifies which ability is using it. ]]

-- spawn_token
function SpawnToken(event)
	print("--SpawnToken called--")

	local building = event.caster
	local unit = event.unit
	local hero = unit:GetPlayerOwner()
	local pID = building:GetPlayerID()

	local player = PlayerResource:GetPlayer(pID)
	-- Select a token to represent and delete it
	local target = event.target
	local tName = target:GetName()
	target:RemoveSelf()

	-- Create unit in front of the building
	local origin = building:GetAbsOrigin()
	local fv = building:GetForwardVector()
	local position = Entities:FindByName(nil, "path0"):GetAbsOrigin()
	print("Spawn position of token for playerID '"..pID.."'",position)

	-- Create token from the unit select before
	local token = CreateUnitByName(tName, position, true, building, hero, hero:GetTeamNumber())
	token:SetOwner(building)
	token:SetBaseMoveSpeed(1000) -- Doesn't do jack shit right now

	-- Link chosen token with the playerID
	Monopoly:SetTokenToPlayerID(token, pID)

end

-- throw_dice
--[[ This function creates 2 random numbers simulating a dice throw by
     the player and call MoveToken() in order to move the players token.
     It returns false whenever the player throws the dice 3 times with the same
     values in each individual function call and sends it to jail. ]]
function ThrowDice(event)
	local rand1 = RandomInt(1,6)
	local rand2 = RandomInt(1,6)
	local player = event.caster
	local pID = player:GetPlayerID()
	local currentTurn = Monopoly:GetCurrentTurn()

	-- Check if both dices have the same number
	-- TODO: Panorama notification
	if rand1 == rand2 then
		Monopoly:IncreaseComboThrow()
		Utilities:SetTimer("Combo throw",Utilities:GetTimer()+30)
		player:AddAbility("throw_dice"):SetLevel(1)
	end

	-- Check if player is eligible for jail
	if Monopoly:CheckComboThrow() == true then
		print("Player ",pID, " goes to jail")
		return false
	end

	-- Check if the player spawned token
	if Monopoly:GetToken(pID) == nil then
		print("No token spawned")
		return false
	end
	-- Check if its players current turn
	if pID == currentTurn then
		print("Dice is thrown and you get "..rand1.." and "..rand2)
		MoveToken(rand1,rand2,pID,false)
	else
		print("Currently not your turn")
		return false
	end

end

-- throw_dice
function CheckStatus(event)
end


-- buy_estate
function BuyEstate(event)
	local kv = GameRules.kvStreets
	kv = kv or {} -- Handle the case where there is not keyvalues file

	local estate = event.caster
	local name = estate:GetName()
	local price = kv[name].Price
	local playerID = estate:GetPlayerOwnerID()

	if PlayerResource:GetGold(playerID) >= price then
		PlayerResource:ModifyGold(playerID,-price,false,1)
		estate:RemoveAbility("buy_estate")
		estate:AddAbility("mortgage_street"):SetLevel(1)
		-- Add to the table of ownership
		Monopoly:AddStreetToPlayer(name,playerID)
		else return false
	end

	local broadcast_estate =
	{ 
		pID = playerID,
		price = price,
		streetName = kv[name].Name,
		streetNumber = Monopoly:GetCurrentPos(playerID)
	}
	CustomGameEventManager:Send_ServerToAllClients("monopoly_buy_notification",broadcast_estate)

	CheckForSet(kv, estate, playerID)

	--print("Price of estate "..price)
end

-- Checks if you have a monopoly, enough houses in bank
-- and are allowed to build a house/hotel
-- buy_house
function BuyHouse(event)
	local kv = GameRules.kvStreets
	kv = kv or {}

	local estate = event.caster
	local name = estate:GetName()
	local playerID = estate:GetPlayerOwnerID()
	local ability = estate:FindAbilityByName("buy_house")
	local buildingCost = kv[name].BuildingCost

	local pathName = "path"..Utilities:GetLastChar(name)
	local bDoesHaveSet = IsSetOwnedByPlayer(estate,playerID)

	-- Check if it has the entire set and enough gold
	-- then builds a house and increases ability level
	if bDoesHaveSet == true then
		local points = ability:GetLevel()
		if points <= ability:GetMaxLevel() then
		if PlayerResource:GetGold(playerID) >= buildingCost then
			ability:SetLevel(points+1)
			PlayerResource:ModifyGold(playerID,-buildingCost, false, 1)
			BuildHouse(pathName,name,playerID)
		else 
			return false
			end
		end
	end

end

-- auction_estate
function AuctionEstate(event)
	local kv = GameRules.kvStreets
	kv = kv or {}

	local estate = event.caster
	local name = estate.GetName()

	nCURRENTESTATEPRICE = kv[name].price / 2

end

-- mortgage_street
function MortgageStreet(event)
	local kv = GameRules.kvStreets

	local estate = event.caster
	local name = estate:GetName()
	local playerID = estate:GetPlayerOwnerID()
	local ability = estate:FindAbilityByName("buy_house") or nil
	local sellPrice = kv[name].Mortgage

	-- Sell houses from the set TODO: Function to check if the player has the entire set
	local set = FindStreetSet(estate)
	for k,v in pairs(set) do
		if IsSetOwnedByPlayer(estate,playerID) then
			name = v:GetName()
			ability = v:FindAbilityByName("buy_house") or nil
			sellPrice = kv[name].Mortgage

			-- Count the sell price of the houses, delete and modify gold
			if ability ~= nil then
				local abilityLevel = ability:GetLevel()
				for i=1,abilityLevel - 1 do
					sellPrice = sellPrice + kv[name].BuildingCost / 2
					DeleteHouses(name)
				end
				-- Modify gold after the sell of the street
				PlayerResource:ModifyGold(playerID,sellPrice, false,1)
			end
			-- Remove ability from the street
			v:RemoveAbility("buy_house")
		end
	end

	estate:RemoveAbility("buy_house")
	estate:RemoveAbility("mortgage_street")
	estate:AddAbility("lift_mortgage"):SetLevel(1)
end

-- lift_mortgage
function LiftMortgage(event)
	local kv = GameRules.kvStreets

	local estate = event.caster
	local name = estate:GetName()
	local playerID = estate:GetPlayerOwnerID()
	local mortgage = kv[name].Mortgage
	-- Price is the mortgage value plus 10% interest
	local price = mortgage + (mortgage*0.10)
	print("lift_mortgage price "..price)

	PlayerResource:ModifyGold(playerID,-price,false,1)
	estate:RemoveAbility("lift_mortgage")
	estate:AddAbility("mortgage_street"):SetLevel(1)
	-- Check if the player the entire set of streets
	-- and add "buy_house" ability
	CheckForSet(kv,estate,playerID)

end

-- jail_dice
function JailDice(event)
	local caster = event.caster
	local pID = caster:GetPlayerID()
	local curPos = Monopoly:GetCurrentPos(pID)

	local dice1 = RandomInt(1,6)
	local dice2 = RandomInt(1,6)
	print("first dice= "..dice1)
	print("second dice= "..dice2)


	if dice1 == dice2 or Monopoly:GetRoundsInJail(pID) >= 2 then
		Monopoly:RemovePlayerFromJail(pID)
		MoveToken(dice1,dice2,pID,false)
	else 
		Monopoly:IncreaseRoundsInJail(pID)
		print("Rounds in jail == ",Monopoly:GetRoundsInJail(pID))
	end

end

-- buy_mid_street
-- Follows the same structure as buy_estate, without having to check for houses
function BuyNoHouseStreet(event)
	local kv = GameRules.kvStreets
	kv = kv or {} -- Handle the case where there is not keyvalues file

	local estate = event.caster
	local name = estate:GetName()
	local price = kv[name].Price
	local playerID = estate:GetPlayerOwnerID()

	if PlayerResource:GetGold(playerID) >= price then
		PlayerResource:ModifyGold(playerID,-price,false,1)
		estate:RemoveAbility("buy_estate")
		estate:AddAbility("mortgage_street"):SetLevel(1)
		-- Add to the table of ownership
		Monopoly:AddStreetToPlayer(name,playerID)
		else return false
	end

	local broadcast_estate =
	{ 
		pID = playerID,
		price = price,
		streetName = kv[name].Name,
		streetNumber = Monopoly:GetCurrentPos(playerID)
	}
	CustomGameEventManager:Send_ServerToAllClients("monopoly_buy_notification",broadcast_estate)

end
