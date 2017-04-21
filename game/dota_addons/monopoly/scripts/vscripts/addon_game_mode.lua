if Monopoly == nil then
	_G.Monopoly = class({})
end

require("abilities")
require("triggers")
require("utilities")
require("commands")
require("player_movement")
require("street_managment")
require("special_events")

function Precache( context )

	PrecacheResource( "model", "*.vmdl", context )
	PrecacheResource( "portraits", "*.usm", context )
	--PrecacheResource( "soundfile", "*.vsndevts", context )
	--PrecacheModel("lina.vmdl", context)
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):

			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	GameRules.monopoly = Monopoly()
	Monopoly:InitGameMode()
	-- GameRules.monopoly:InitGameMode()
end

function Monopoly:InitGameMode()
	print( "Monopoly is loaded." )

	self.nCurrentTurn = 0 -- pID. Whose turn is it
	self.nHousesInBank = 40 -- Houses and Hotels in bank
	self.nComboThrow = 0 -- Counting the amount of times the dices were the same number
	self.nPreviousTurn = -1

	self.vNextPos = {}
	self.vCurrentPos = {} -- Current position for each player in the board
	self.vPlayerIDs = {} -- pIDs
	self.vUserIDs = {} -- keys.player
	self.vModelName = {} -- Saves token model name
	self.vPlayerOwnership = {} -- Streets that the player owns
	self.vHeroIndex = {} -- Hero entity of the player
	self.vPlayersInJail = {}
	self.vRoundsInJail = {} -- How many times the player has thrown jail_dice
	self.vLastDiceThrown = {} -- Last dice number thrown by the player
	self.vPlayersInGame = {} -- Players that haven't lost. '1' = Currently playing. '-1' = Player lost

	self.bStartTimer = false

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 1 )
	GameRules:SetGoldPerTick(0)
	GameRules:SetGoldTickTime(0)
	GameRules:SetPreGameTime(10)
	GameRules:SetPostGameTime(10)
	GameRules:SetStartingGold(1000)
	GameRules:SetTreeRegrowTime(1)

	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS,1)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS,1)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_1,1)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_2,1)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_3,1)
	GameRules:EnableCustomGameSetupAutoLaunch(true)
	GameRules:SetHeroRespawnEnabled(true)
	GameRules:LockCustomGameSetupTeamAssignment(false)
	GameRules:SetHeroSelectionTime(999)
	GameRules:SetPreGameTime(10)
	
	GameMode = GameRules:GetGameModeEntity()
	GameMode:SetRecommendedItemsDisabled(true)
	GameMode:SetStashPurchasingDisabled(true)
	GameMode:SetAlwaysShowPlayerInventory(false)
	GameMode:SetTopBarTeamValuesOverride(true)
	GameMode:SetTopBarTeamValuesVisible(true)
	GameMode:SetCameraDistanceOverride(3000)
	GameMode:SetRecommendedItemsDisabled(true)
	GameMode:SetStashPurchasingDisabled(true)
	GameMode:SetBuybackEnabled(false)
	
	-- all this is probably deprecated. Scaleform stuff
	-- GameMode:SetHUDVisible(DOTA_HUD_VISIBILITY_INVENTORY_SHOP,false)
	-- GameMode:SetHUDVisible(DOTA_HUD_VISIBILITY_INVENTORY_QUICKBUY,false)
	-- GameMode:SetHUDVisible(DOTA_HUD_VISIBILITY_INVENTORY_COURIER,false)
	-- GameMode:SetHUDVisible(DOTA_HUD_VISIBILITY_SHOP_SUGGESTEDITEMS,false)
	 GameMode:SetCustomGameForceHero("npc_dota_hero_furion")

	-- GameRules:SetCustomGameSetupTimeout(0)
	
	--Tutorial:StartTutorialMode()
	--Tutorial:SelectHero("npc_dota_hero_ancient_apparition")

	--[[
	self.m_TeamColors = {}
	self.m_TeamColors[DOTA_TEAM_GOODGUYS] = { 61, 210, 150 }	--		Teal
	self.m_TeamColors[DOTA_TEAM_BADGUYS]  = { 243, 201, 9 }		--		Yellow
	self.m_TeamColors[DOTA_TEAM_CUSTOM_1] = { 197, 77, 168 }	--      Pink
	self.m_TeamColors[DOTA_TEAM_CUSTOM_2] = { 255, 108, 0 }		--		Orange
	self.m_TeamColors[DOTA_TEAM_CUSTOM_3] = { 52, 85, 255 }		--		Blue
	
	for team = 0, (DOTA_TEAM_COUNT-1) do
		color = self.m_TeamColors[ team ]
		if color then
			SetTeamCustomHealthbarColor( team, color[1], color[2], color[3] )
		end
	end	

	--]]
	Convars:RegisterCommand( "monopoly_set_timer", function(...) return Utilities:SetTimer( ... ) end, "Set the timer.", FCVAR_CHEAT)
	Convars:RegisterCommand( "monopoly_set_game_winner", function(...) return Utilities:SetWinner( ... ) end, "Set a Winner by his pID.", FCVAR_CHEAT)
	Convars:RegisterCommand( "monopoly_set_gold", function(...) return	 Utilities:SetPlayerGold( ... ) end, "Set gold(not add) to a pID", FCVAR_CHEAT)


	-- Listeners
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(Monopoly, 'OnPlayerPickHero'), self)
	ListenToGameEvent('player_chat', Dynamic_Wrap(Monopoly,'OnPlayerChat'), self)


	-- Custom listeners
	CustomGameEventManager:RegisterListener( "monopoly_end_turn_call", Dynamic_Wrap(Monopoly,"NextPlayerTurn"))
	CustomGameEventManager:RegisterListener( "monopoly_street_stats_update", Dynamic_Wrap(Monopoly,"GetStreetsStats"))
	CustomGameEventManager:RegisterListener( "monopoly_trade_overlay_request", Dynamic_Wrap(Monopoly,"SendPlayerInventory"))
	CustomGameEventManager:RegisterListener( "monopoly_trade_add_remove_street", Dynamic_Wrap(Monopoly,"TradeAddRemoveStreet"))
	CustomGameEventManager:RegisterListener( "monopoly_trade_send_offer", Dynamic_Wrap(Monopoly,"SendTradeOffer"))
	CustomGameEventManager:RegisterListener( "monopoly_trade_accepted", Dynamic_Wrap(Monopoly,"ProcessTrade"))

	self.LoadAllKV()

end

-- Evaluate the state of the game
function Monopoly:OnThink()
	-- Pre game
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		if Utilities:GetTimer() == nil then
			Utilities:SetTimer("Pre-Game Timer", 1)
		end

	end

	-- Game in progress
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then

		Monopoly:CheckGamePause()

		-- Check for next players turn
		if self.bStartTimer == true then
			Utilities:CountdownTimer()
			Monopoly:CheckPlayerTurn()
		end

	-- Game ended
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end


-- Player init
--[[
	TODO: Player gets insta-pick hero depending in which slot he is.
	Player init begins. It saves into tables diferent values for later use.
	It also creates "spawn_token" ability for the player in order to chose a token.
]]
function Monopoly:OnPlayerPickHero(keys)
	print("--OnPlayerPickHero called!--")

	local hero = EntIndexToHScript(keys.heroindex)
	local player = EntIndexToHScript(keys.player)
	local playerID = hero:GetPlayerID()
	local team = player:GetTeamNumber()

--[[ Spawn a new hero depending on which team player is on.
	 Very problematic. Might be done later.
	hero:RemoveSelf()
	--print("hero1 ", hero)
	hero = CreateHeroForPlayer( "npc_dota_hero_abaddon", player )
	--print("hero2 ", hero)
	hero:RespawnUnit()
	hero:SetControllableByPlayer(playerID,true)
	hero:SetOwner(player)
	hero:SetTeam(team)
	]]

--[[ Deprecated. Used before to create a building for the player.
	local origin = hero:GetAbsOrigin()
    local fv = hero:GetForwardVector()
    local distance = 100
    local position = origin + fv * distance
	]]
    --hero:AddAbility("throw_dice"):SetLevel(1)
    --hero:AddAbility("spawn_token"):SetLevel(1)
	hero:FindAbilityByName("spawn_token"):SetLevel(1) -- 23/01/2017 for some reason "hero:AddAbility("spawn_token"):SetLevel(1)" doesnt work.

	-- push into tables
	self.vUserIDs[playerID] = keys.player
	self.vPlayerIDs[keys.player] = playerID
	self.vCurrentPos[playerID] = 0
	self.vNextPos[playerID] = 0
	self.vHeroIndex[playerID] = hero
	self.vPlayersInGame[playerID] = 1

	print("player =",keys.player)
	print("PlayerID '"..playerID.."' values have been loaded")
	print("Hero index=",hero:GetEntityIndex())
end

function PrecacheEveryThingFromKV( context )
	local kv_files = {  "scripts/npc/npc_units_custom.txt",
							"scripts/npc/npc_abilities_custom.txt",
							"scripts/npc/npc_heroes_custom.txt",
							"scripts/npc/npc_abilities_override.txt",
							"npc_items_custom.txt"
						}
	for _, kv in pairs(kv_files) do
		local kvs = LoadKeyValues(kv)
		if kvs then
			print("BEGIN TO PRECACHE RESOURCE FROM: ", kv)
			PrecacheEverythingFromTable( context, kvs)
		end
	end
end

function PrecacheEverythingFromTable( context, kvtable)
	for key, value in pairs(kvtable) do
		if type(value) == "table" then
			PrecacheEverythingFromTable( context, value )
		else
			if string.find(value, "vpcf") then
				PrecacheResource( "particle",  value, context)
				print("PRECACHE PARTICLE RESOURCE", value)
			end
			if string.find(value, "vmdl") then  
				PrecacheResource( "model",  value, context)
				print("PRECACHE MODEL RESOURCE", value)
			end
			if string.find(value, "vsndevts") then
				PrecacheResource( "soundfile",  value, context)
				print("PRECACHE SOUND RESOURCE", value)
			end
		end
	end
end

function Monopoly:LoadAllKV()
	print("Loading all KVs")
	GameRules.kvStreets = LoadKeyValues("scripts/kv/streets.kv")
	GameRules.kvEvents = LoadKeyValues("scripts/kv/ccEvents.kv")
end

function Monopoly:GetHeroEntity(pID)
	return self.vHeroIndex[pID]
end

-- returns pID
function Monopoly:GetCurrentTurn()
	return self.nCurrentTurn
end

--[[
	Links token used to represent the player
	using its model name. Reason for this is because the
	model name of their token will always be unique between players.
	This is also done because it is the easiest way of finding a token entity
	using FindByModel() (at least it was at the time I was looking for a solution).
]] 
function Monopoly:SetTokenToPlayerID(modelName, pID)
	self.vModelName[pID] = modelName
end

-- returns entity linked to the player
function Monopoly:GetToken(pID)
	return self.vModelName[pID]
end

-- returns position of specified pID
function Monopoly:GetCurrentPos(pID)
	return self.vCurrentPos[pID]
end

-- Sets the specified pos to the table
function Monopoly:SetCurrentPos(nPos, pID)
	print("PlayerID ",pID, "set to position",nPos)
	self.vCurrentPos[pID] = nPos
end

function Monopoly:GetPlayerID(userID)
	return self.vPlayerIDs[userID]
end

-- Returns a table with all players that still are in the game
function Monopoly:GetAllPlayersID()
	local playerIDs = {}

	for k,v in pairs(self.vPlayerIDs) do
		table.insert(playerIDs,v)
	end
	return playerIDs
end

-- Adds to the specified vPlayerOwnership
-- Saves the name of the street and what playerID is attached to
function Monopoly:AddStreetToPlayer(streetName, pID)
	print("Street ", streetName, " set to PlayerID ", pID)
	self.vPlayerOwnership[streetName] = pID
end

-- TODO: Get this back to work
-- returns a table of all the streets the player owns
function Monopoly:GetPlayerStreets(pID)
	local stTable = {}
	for k,v in pairs(Monopoly.vPlayerOwnership) do
		--print(k,v)
		if v == pID then
			table.insert(stTable,k)
		end
	end
	return stTable
end 

-- TODO:
function Monopoly:RemoveStreetFromPlayer(streetName, pID)
	local i = 1
	for k,v in pairs(self.vPlayerOwnership) do
		print("Removing property...",k)
		if k == streetName then
			table.remove(self.vPlayerOwnership,i)
			return true
		end
		i = i+1
	end

	return false
end

-- Timer respects pauses
function Monopoly:CheckGamePause()
	if GameRules:IsGamePaused() == true then
		self.bStartTimer = false
	end

	if GameRules:IsGamePaused() == false then
		self.bStartTimer = true
	end

end

--[[ Both 'SetPlayerToJail' and 'RemovePlayerFromJail'
	 use a pID+1 just to make it easier to remove 
	 player from the table.
	 ]]
function Monopoly:SetPlayerToJail(pID)
	self.vPlayersInJail[pID+1] = pID
	self.vRoundsInJail[pID+1] = 0
end

function Monopoly:RemovePlayerFromJail(pID)
	table.remove(self.vPlayersInJail, pID+1)
	table.remove(self.vRoundsInJail, pID+1)
end

function Monopoly:GetRoundsInJail(pID)
	return self.vRoundsInJail[pID+1]
end

function Monopoly:IncreaseRoundsInJail(pID)
	self.vRoundsInJail[pID+1] = self.vRoundsInJail[pID+1] + 1
end

function Monopoly:SetPreviousTurn(pID)
	self.nPreviousTurn = pID
end

function Monopoly:GetPreviousTurn()
	return self.nPreviousTurn
end

-- Bit of cleaning in OnThink()
-- sets the next player turn
function Monopoly:CheckPlayerTurn()
	local currentPID = Monopoly:GetCurrentTurn()

	if PlayerResource:GetGold(currentPID) <= 0 then
		print("Player "..currentPID.." lost")
		local playerTeam = PlayerResource:GetTeam(currentPID)
		Monopoly:MakePlayerLose(currentPID)
	end

	-- Players turn is over
	if Utilities:GetTimer() <= 0 then
		local previousPID = currentPID
		local curPos = Monopoly:GetCurrentPos(previousPID)
		local street = Entities:FindByName(nil,("street"..curPos))

		Monopoly:SetPreviousTurn(previousPID)
		-- TODO: Check for different streets that are not the default ones(ex. IncomeTax should have a default pay if the player hasn't used any ability)
		Monopoly:CheckStreetConditons(street,previousPID)

		-- Remove any ability previous player has left
		Monopoly:RemoveAllAbilities(previousPID)

		-- Remove some panorama from the client
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(previousPID),"end_turn_notification_disable",{})

		-- Set the next player on the table to play
		Monopoly:SetNextPlayerTurn()

		-- Update turn in Panorama and enable end turn button
		local update_current_turn = {
		pID = self.nCurrentTurn	}
		CustomGameEventManager:Send_ServerToAllClients( "update_turn", update_current_turn )
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(Monopoly:GetCurrentTurn()),"end_turn_notification_enable",update_current_turn)
		
		-- Reset the combo throw for the next player
		self.nComboThrow = 0 

		local nextPlayer = Monopoly:GetCurrentTurn() -- This call gets the next player
		-- Check next player status
		Monopoly:OnNextTurn(nextPlayer)

		Utilities:SetTimer("Next Player", 31)
		print("Next player ID: " ..self.nCurrentTurn)
	end

end

-- A player 
function Monopoly:CheckStreetConditons(entStreet,pID)
	-- Remove control of the street if the player hasn't bought it
	-- Standard street, utility street and 'tiny' street
	if entStreet ~= nil then 
		if entStreet:FindAbilityByName("buy_estate") ~= nil or entStreet:FindAbilityByName("buy_no_house_street") ~= nil then
			entStreet:SetControllableByPlayer(-1,true)
			entStreet:SetTeam(-1)
			entStreet:SetOwner(nil)
		end
		-- IncomeTax should default to 200 gold if the player doesn't use any ability on time
		-- Also, remove control of the street
		if entStreet:FindAbilityByName("pay_tax") ~= nil then
			if entStreet:FindAbilityByName("pay_tax"):IsOwnersGoldEnough(pID) == false then
				Monopoly:MakePlayerLose(pID) -- Not enough to pay_tax. Lost already
				return
			end
			entStreet:FindAbilityByName("pay_tax"):CastAbility() -- Casting this ability without enough gold overflows the players gold
		end
	end

end

-- Remove player from all the tables,
-- all houses and street ownership
function Monopoly:MakePlayerLose(pID)
	local player = self.vUserIDs[pID]
	local playerStreets = Monopoly:GetPlayerStreets(pID)
	local street = nil -- entity

	-- Table removes
	-- table.remove(self.vPlayerIDs,player)
	-- table.remove(self.vUserIDs,pID)
	self.vCurrentPos[pID] = -1
	self.vNextPos[pID] = -1
	self.vPlayersInGame[pID] = -1

	-- Remove streets from table,
	-- remove remaining houses and set the street to default state
	for k,v in pairs(playerStreets) do
		Monopoly:RemoveStreetFromPlayer(v,pID)

		street = Entities:FindByName(nil,v)
		street:SetControllableByPlayer(-1,true)
		street:SetTeam(-1)
		street:SetOwner(nil)
		DeleteHouses(v)

		street:RemoveAbility("buy_house")
		street:RemoveAbility("mortgage_street")
		street:AddAbility("buy_house")
	end

	-- Check game end
	Monopoly:HasGameEnded()

	-- Skip turn as this player lost
	Monopoly:NextPlayerTurn()
end

-- Checks if there are players in the game, if not sets the winner to the last one standing
function Monopoly:HasGameEnded()
	local i = 0
	local playersInGame = {}
	for k,v in pairs(self.vPlayersInGame) do
		if v == 1 then
			i = i + 1
			table.insert(playersInGame, k)
		end
	end
	
	if Utilities:TableSize(playersInGame) == 1 then
		local nTeam = PlayerResource:GetTeam(tonumber(playersInGame[1]))
		GameRules:SetGameWinner(nTeam)
	end

end

-- Checks the table if the player is still in the game and sets the turn
function Monopoly:SetNextPlayerTurn()
	local curTurn = self.nCurrentTurn
	local firstPlayer = -1 -- pID of the first player if everybody finished the round

	-- Check who is going to be the first player
	local i = 1
	for k,v in pairs(self.vPlayerIDs) do
		if self.vCurrentPos[i-1] ~= -1 then
			firstPlayer = i - 1
			break
		end
		i = i + 1
	end

	local i = self.nCurrentTurn
	for k,v in pairs(self.vPlayerIDs) do
		-- Table size has been reached, start from the first player that is in the game
		if self.nCurrentTurn + 1 > Utilities:TableSize(self.vPlayerIDs) - 1 then
			self.nCurrentTurn = firstPlayer
			return
		elseif self.vCurrentPos[i + 1] ~= -1 then
			self.nCurrentTurn = i + 1
			return
		end
		i = i + 1
	end

end

-- Get ready for next player
function Monopoly:OnNextTurn(pID)
	local hero = Monopoly:GetHeroEntity(pID) 

	-- Check if player is in Jail
	for k,v in pairs(self.vPlayersInJail) do
		if v == pID then
			hero:AddAbility("jail_dice"):SetLevel(1)
		end
	end
	--[[
	There can be a case where self.vPlayersInJail will be
	nil from not having anyone in it, making for statement
	not being run. That's why we don't set it all as 'elseif'.
	]]
	if hero:FindAbilityByName("jail_dice") == nil and Monopoly:GetToken(pID) ~= nil then
		hero:AddAbility("throw_dice"):SetLevel(1)
	end


end

-- Removes all abilities from the heroes player
-- Abilities have to be added manually
-- TODO: Add a table of abilities
function Monopoly:RemoveAllAbilities(pID)
	local hero = Monopoly:GetHeroEntity(pID)
	local diceThrow = hero:FindAbilityByName("throw_dice")
	local jailThrow = hero:FindAbilityByName("jail_dice")

	if diceThrow ~= nil then
		hero:RemoveAbility("throw_dice")
	end
	if jailThrow ~= nil then
		hero:RemoveAbility("jail_dice")
	end

end

--[[ Sets the timer to 0 manually.
	 creating a nextTurn status.
	 ]]
function Monopoly:NextPlayerTurn()
	if Utilities:GetTimer() > 0 then
		Utilities:SetTimer("Next Player", 0)
	end
end

-- Increases player combo throw. Resets to 0 every turn
function Monopoly:IncreaseComboThrow() 
	self.nComboThrow = self.nComboThrow + 1
end 

function Monopoly:CheckComboThrow()
	local pID = Monopoly:GetCurrentTurn()
	local curPos = Monopoly:GetCurrentPos(self.nCurrentTurn)

	-- Player has thrown the dice 3 times 
	-- with both dices being the same --> Jail
	if self.nComboThrow == 3 then
		self.nComboThrow = 0 
		JailEvent(curPos,pID)
		return true
	end
end

function Monopoly:SetLastDiceThrown(nDice,pID)
	self.vLastDiceThrown[pID] = nDice
end

function Monopoly:GetLastDiceThrown(pID)
	return self.vLastDiceThrown[pID]
end

-- DEPRECATED.
-- Check in what state the player is.
-- Whether it is in jail, normal dice throw
-- or combo throw its on.
function Monopoly:CheckPlayerStatus(pID)
	local jailBuilding = Entities:FindByName( nil, "path10" )
	local token = Monopoly:GetToken(pID)
	local curPos = Monopoly:GetCurrentPos(pID)
	local hero = Monopoly:GetHeroEntity(pID)

	for k,v in pairs(self.vPlayersInJail) do
		if v == pID then
			if hero:FindAbilityByName( "jail_dice" ) == nil then
				hero:AddAbility("jail_dice"):SetLevel(1)
			end
		end
	end

	if hero:FindAbilityByName("throw_dice") == nil and hero:FindAbilityByName( "jail_dice" ) == nil then
		hero:AddAbility("throw_dice"):SetLevel(1)
		end

end

--[[
	Get data from kvStreets
	and send it back to panorama.
]]
function Monopoly:GetStreetsStats(data)
	local streetsKV = GameRules.kvStreets
	
	-- Look in streets.kv if the player selected any street
	for k,v in pairs(streetsKV) do
		-- Some keys do not have Name
		local street = streetsKV[k]

		if street.Name ~= nil then

			-- Check if more links exist
			local link2 = nil
			local link3 = nil
			if street.Link2 ~= nil then
				link2 = streetsKV[street.Link2].Name
			end
			if street.Link3 ~= nil then
				link3 = streetsKV[street.Link3].Name
			end

			-- Keys only have the last bit of the string (ex. "cm")
			if "npc_monopoly_estate_"..street.Name == data.hero then
				local stats = 
				{
					name = street.Name,
					price = street.Price,
					rent = street.Rent,
					mortgage = street.Mortgage,
					link1 = streetsKV[street.Link1].Name,
					link2 = link2,
					link3 = link3,
					building_cost = street.BuildingCost,
					house1 = street.House1,
					house2 = street.House2,
					house3 = street.House3,
					house4 = street.House4,
					house5 = street.House5,
					nohouses = street.NoHouses,
					rent1 = street.Rent1,
					rent2 = street.Rent2,
					rent3 = street.Rent3,
					rent4 = street.Rent4
				}
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.PlayerID),"monopoly_show_street_stats",stats)
				return
			end
		end
	end
end

--[[
	TODO:
	Later on this has to be improved with other
	stuff like wards(which for now are unlimited)
]]
function Monopoly:GetPlayerInventory(pID)
	local streets = Monopoly:GetPlayerStreets(pID)

	return streets
end

--[[
	Sends player and target inventory to panorama
]]
function Monopoly:SendPlayerInventory(data)
	local streetsKV = GameRules.kvStreets
	local localInventory
	local targetInventory
	local inventory = {}
	inventory["local"] = {}
	inventory["target"] = {}
	inventory['targetPID'] = {}
	local localPID = data.player
	local targetPID = -1

	-- Find pID of target
	for k,v in pairs(Monopoly.vHeroIndex) do
		if v:GetEntityIndex() == data.target then
			targetPID = v:GetPlayerID()
		end
	end

	localInventory = Monopoly:GetPlayerInventory(localPID)
	targetInventory = Monopoly:GetPlayerInventory(targetPID)

	-- Add player inventory first
	for k,v in pairs(localInventory) do
		inventory["local"][k] = streetsKV[v].Name
	end

	-- Target inventory
	for k,v in pairs(targetInventory) do
		inventory["target"][k] = streetsKV[v].Name
	end

	-- Send Target pID
	inventory['targetPID'] = targetPID

	CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(localPID),"monopoly_trade_overlay_display",inventory)
end

function Monopoly:TradeAddRemoveStreet(data)
	local remove = data['remove']
	local name = data['name']
	local pID = data['pID']
	local localStreet = data['local']

	if remove == 0 then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID),"monopoly_trade_add_street",{name,localStreet})
	else
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID),"monopoly_trade_remove_street",{name,localStreet})
	end

end

function Monopoly:SendTradeOffer(data)
	CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.targetPID),"monopoly_trade_recieve_offer",{data.localStreets,data.targetStreets, data.localGold, data.targetGold, data.localPID})
end

--[[
	TODO: Remove houses only if the player bought part of the entire set
]]
function Monopoly:ProcessTrade(data)
	local kvStreets = GameRules.kvStreets
	local localGoldModifier = data.targetGold - data.localGold
	local targetGoldModifier = data.localGold - data.targetGold

	-- TODO: A bit meh. Runs through the entire kv
	-- while entering both fors
	for k,v in pairs(kvStreets) do
		for x,y in pairs(data.localStreets) do -- Swap local player streets
			if kvStreets[k].Name == y then
				SwapStreets(data.localPID,data.targetPID,k)
			end
		end -- data.localStreets

		for x,y in pairs(data.targetStreets) do -- Swap target player streets
			if kvStreets[k].Name == y then
				SwapStreets(data.targetPID,data.localPID,k)
			end
		end -- data.targetStreets
	end -- kvStreets

	PlayerResource:ModifyGold(data.localPID,localGoldModifier, false, 0)
	PlayerResource:ModifyGold(data.targetPID,targetGoldModifier, false, 0)

end