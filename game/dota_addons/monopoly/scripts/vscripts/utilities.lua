if Utilities == nil then
    _G.Utilities = class({})
end

function Utilities:StringStartsWith( fullstring, substring )
	local strlen = string.len(substring)
	local first_characters = string.sub(fullstring, 1 , strlen)
	return (first_characters == substring)
end

function Utilities:GetLastChar( fullstring )
	local strlen = string.len(fullstring)
	local last_character
	-- Checks strings length
	-- ex. path1 or path32
		if strlen == 8 then
		last_character = string.sub(fullstring, strlen - 1)
		elseif strlen == 7 then
		last_character = string.sub(fullstring, strlen)
		end
	return last_character
end

function Utilities:CountdownTimer()

    self.nCountdowntimer = self.nCountdowntimer - 1
    local t = self.nCountdowntimer
    --print( t )
    local minutes = math.floor(t / 60)
    local seconds = t - (minutes * 60)
    local m10 = math.floor(minutes / 10)
    local m01 = minutes - (m10 * 10)
    local s10 = math.floor(seconds / 10)
    local s01 = seconds - (s10 * 10)
    local broadcast_gametimer = 
        {
            timer_minute_10 = m10,
            timer_minute_01 = m01,
            timer_second_10 = s10,
            timer_second_01 = s01,
        }
    CustomGameEventManager:Send_ServerToAllClients( "countdown", broadcast_gametimer )
    if t <= 120 then
        CustomGameEventManager:Send_ServerToAllClients( "time_remaining", broadcast_gametimer )
    end
end

-- Used in ConVar and standard game
function Utilities:SetTimer( cmdName, time )
    if time == nil then
        print("Set the timer.\n monopoly_set_timer -time")
		return
    end
    print( "Set the timer to: " .. time )
    print("Reason:",cmdName )
    self.nCountdowntimer = time
end

function Utilities:GetTimer()
  	return self.nCountdowntimer
end

function Utilities:TableSize(table)
	local count = 0
	for _ in pairs(table) do count = count + 1 end
	return count
end

function Utilities:SetContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function Utilities:Send_CommunityNotification(text, pID)
	local broadcast_notification = 
	{
		text = text,
	 	pID = pID,
	}
	CustomGameEventManager:Send_ServerToAllClients("special_events_community",broadcast_notification)

end

-- Convar
function Utilities:SetWinner(cmdName, pID)
	if pID == nil then
        print("Set a Winner by his pID.")
        return
    end
    local nTeam = PlayerResource:GetTeam(tonumber(pID))
    GameRules:SetGameWinner(nTeam)
end

-- Convar
function Utilities:SetPlayerGold(cmdName, amount, pID)
    if amount == nil or pID == nil then
        print("Set player gold.\n monopoly_set_player -amount -pID")
        return
    end
    PlayerResource:SetGold(tonumber(pID),tonumber(amount),false)
    print("Player "..pID.." gold set to "..amount)
end
