SPECIAL_EVENT_CODES = {
["IncomeTax"] = function(...) IncomeTaxEvent(...) end,
["LuxuryTax"] = function(...) LuxuryTaxEvent(...) end,
["Community"] = function(...) CommunityEvent(...) end,
["Jail"] = function(...) JailEvent(...) end,
["JailThrough"] = function(...) JailThroughEvent(...) end, -- nothing supposed to happen here
["Utility"] = function(...) UtilityStreetEvent(...) end,
}

EVENT_ACTIONS = {
["Move"] = function(...) MoveToPos(...) end,
["Take"] = function(...) TakeFromPlayer(...) end,
["Give"] = function(...) GiveToPlayer(...) end,
["TakeFromPlayers"] = function(...) TakeFromPlayers(...) end,
["GiveToPlayers"] = function(...) GiveToPlayers(...) end,
["Jump"] = function(...) JumpToPos(...) end,
}

-- INCOME TAX FUNCTIONS
function IncomeTaxEvent(pos,pID)
	print("--IncomeTaxEvent called--")
	local building = Entities:FindByName(nil, "street"..pos)
	local owner = Monopoly:GetToken(pID):GetOwner()

	building:SetControllableByPlayer(pID, false)
	building:SetOwner(owner)
	building:SetTeam(owner:GetTeamNumber())
	building:AddAbility("pay_tax"):SetLevel(1)
	building:AddAbility("pay_worth"):SetLevel(1)

end

-- TODO: Panorama notification
function LuxuryTaxEvent(pos, pID)
	print("--LuxuryTaxEvent called--")
	PlayerResource:ModifyGold(pID,-150,false,0)
end

-- Pays 10% of the players worth. Includes buildings
-- streets(mortgaged included) and his current gold
function PayTaxWorth(event)
	print("--PayTaxWorth called--")
	local nTotalWorth = 0
	local pID = event.caster:GetPlayerOwnerID()

	nTotalWorth = CalculateStreetsWorth(pID) + PlayerResource:GetGold(pID)
	print("total worth ",nTotalWorth)
	print("to pay ",nTotalWorth*0.1)

	PlayerResource:ModifyGold(pID,-nTotalWorth*0.1,false,1)
end

-- Calculates all the worth from the streets the player owns
function CalculateStreetsWorth( pID )
	local kv = LoadKeyValues("scripts/kv/streets.kv")
	local vPlayerStreets = Monopoly:GetPlayerStreets(pID)
	local worth = 0

	for k,v in pairs(vPlayerStreets) do
		print(v)
		-- Find worth of each individual street and sum to the worth
		-- Street is mortgaged
		local street = Entities:FindByName(nil, v)
		print(street)
		if street:FindAbilityByName("lift_mortgage") then
			worth = worth + kv[v].Mortgage
		end
		-- Street is not mortgaged. Check for buildings worth
		if street:FindAbilityByName("mortgage_street") then
			worth = worth + kv[v].Price
			-- Check for buildings
			if street:FindAbilityByName("buy_house") ~= nil then
				local level = street:FindAbilityByName("buy_house"):GetLevel() - 1
				for i=1, level do
					worth = worth + kv[v].BuildingCost
				end
			end
		end
	end

	return worth
end
-- END OF INCOME TAX FUNCTIONS

function CommunityEvent(pos,pID)
	print("--CommunityEvent called--")
	local kv = GameRules.kvEvents
	local building = Entities:FindByName( nil, "street"..pos)
	local owner = Monopoly:GetToken(pID):GetOwner()
	local nEvents = 0

	building:SetControllableByPlayer( pID, false )
	building:SetOwner( owner )
	building:SetTeam(owner:GetTeamNumber())
	-- Check how many events there are
	for k in pairs(kv) do
		nEvents = nEvents + 1
	end
	print("Number of events", nEvents)

	-- Choose a random event 
	local rand = RandomInt( 1, nEvents )
	print("Event chosen",rand)
	
	local actionName = kv[tostring(rand)].Action
	print(actionName)

	-- Call the specific chosen event
	-- [function](arg1,arg2...)
	EVENT_ACTIONS[actionName](kv[tostring(rand)], pID)
end

function MoveToPos(kv,pID)
	print("--MOVE--")
	local amount = tonumber(kv["Amount"])
	local text = kv["Action"]
	local collect = kv["Collect"] -- Collect gold from GO street
	local token = Monopoly:GetToken(pID)
	local curPos = Monopoly:GetCurrentPos(pID)
	-- Sum curPos + amount in order to move and not get stuck in "amount"
	local path = Entities:FindByName(nil, "path"..amount+curPos)

	Utilities:Send_CommunityNotification(text,pID)
	-- First, we order the unit to move to the specific position
	-- then we teleport the unit
	MoveToken(amount, 0, pID, false)
	FindClearSpaceForUnit(token, path:GetAbsOrigin(), false)
end

function JumpToPos(kv, pID)
	local position = tonumber(kv["Position"])
	local text = kv["Action"]
	local token = Monopoly:GetToken(pID)
	local path = Entities:FindByName(nil,"path"..position)

	Utilities:Send_CommunityNotification(text,pID)
	MoveToken(position, 0, pID, true)
	FindClearSpaceForUnit(token, path:GetAbsOrigin(), false)
end

function TakeFromPlayer(kv,pID)
	print("--TAKE--")
	local amount = tonumber(kv["Amount"])
	local text = kv["Action"]

	Utilities:Send_CommunityNotification(text,pID)
	PlayerResource:ModifyGold(pID, -amount, false, 1)
end

function GiveToPlayer(kv,pID)
	print("--GIVE--")
	local amount = tonumber(kv["Amount"])
	local text = kv["Action"]

	Utilities:Send_CommunityNotification(text,pID)
	PlayerResource:ModifyGold(pID, amount, false, 1)
end

function TakeFromPlayers(kv, pID)
	print("--TAKE FROM PLAYERS--")
	local amount = tonumber(kv["Amount"])
	local text = kv["Action"]
	local playerIDs = Monopoly:GetAllPlayersID() -- Make sure the players are still in the game
	local sum = 0 -- Sum of all the money colected from other players

	-- Remove pID from the table
	for k,v in pairs(playerIDs) do
		if v == pID then
			table.remove(playerIDs,k)
		end
	end

	-- Remove 'amount' from players and add to sum
	for k,v in pairs(playerIDs) do
		PlayerResource:ModifyGold(v, -amount, false, 1)
		sum = sum + amount
	end

	Utilities:Send_CommunityNotification(text,pID)

	-- Add 'sum' to the player
	PlayerResource:ModifyGold(pID, sum, false, 1)
end

function GiveToPlayers(kv, pID)
	print("--GIVE TO PLAYERS--")
	local amount = tonumber(kv["Amount"])
	local text = kv["Action"]
	local playerIDs = Monopoly:GetAllPlayersID() 
	local sum = 0
	
	for k,v in pairs(playerIDs) do
		if v == pID then
			table.remove(playerIDs, k)
		end
	end

	for k,v in pairs(playerIDs) do 
		PlayerResource:ModifyGold(v, amount, false, 1)
		sum = sum + amount
	end

	Utilities:Send_CommunityNotification(text,pID)
	PlayerResource:ModifyGold(pID, -sum, false, 1)
end

-- TODO: Panorama notification
function JailEvent(pos, pID)
	print("--JailEvent Called--")
	local token = Monopoly:GetToken(pID)
	local path = Entities:FindByName(nil, "path10")

	-- Write pID in the array
	Monopoly:SetPlayerToJail(pID)
	-- Move player to jail
	MoveToken(10, 0, pID, true)
	FindClearSpaceForUnit(token, path:GetAbsOrigin(), false)
	-- Set a next turn because the player ends turn on that point
	Monopoly:NextPlayerTurn()
end

function JailThroughEvent(pos, pID)

end

-- Electrical company streets
--[[ 
If ONE Utility is owned, rent is 4x the number on the dice which landed the player on the utility,
but if BOTH Utilities are owned, rent is 10x the amount shown on the dice. 
-]]
function UtilityStreetEvent(pos, pID)
	local kv = GameRules.kvEvents
	local building = Entities:FindByName( nil, "street"..pos)
	local owner = Monopoly:GetToken(pID):GetOwner()
	local streetSet = FindStreetSet(building) 
	local lastDice = Monopoly:GetLastDiceThrown(pID)
	if building:GetOwner() == nil then
		building:SetControllableByPlayer( pID, false )
		building:SetOwner( owner )
		building:SetTeam(owner:GetTeamNumber())
	else
		if IsStreetOwnedByPlayer(("street"..pos),pID) == false then
			for k,v in pairs(streetSet) do
				if k ~= "street"..pos then
					if v:GetPlayerOwner() == building:GetPlayerOwner() then
						PlayerResource:ModifyGold(pID,-(10*lastDice),false,0)
					else
						PlayerResource:ModifyGold(pID,-(4*lastDice),false,0)
					end
				end
			end
		end
	end
end

















