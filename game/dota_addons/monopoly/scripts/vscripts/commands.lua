
-- standard command call should be something like
-- -[command] [player] [buy] [sell]

COMMAND_CODES = {
  	["j"] = function(...) Monopoly:jumpStreet(...) end,
	["dt"] = function(...) Monopoly:ManipulateDices(...) end,
  	["bid"] = function(...) Monopoly:EstateAuction(...) end,
}


function Monopoly:OnPlayerChat(keys)
    print("--OnPlayerChat called--")
    local text = keys.text
    local userID = keys.userid


    -- Handle '-command'
    if Utilities:StringStartsWith(text, "-") then
        text = string.sub(text, 2, -1)
        --print(text)
        for k, v, n, z in string.gmatch(text, "(%w+) (%w+) (%w+) (%w+)") do
       		COMMAND_CODES[k](v,n,z)
			return
        end
		for k, v, n in string.gmatch(text, "(%w+) (%w+) (%w+)") do
			COMMAND_CODES[k](v,n)
			return
		end
    end
end

function Monopoly:ManipulateDices(dice1,dice2,pID)
	local d1 = tonumber(dice1)
	local d2 = tonumber(dice2)
	local pID = tonumber(pID)
	MoveToken(d1,d2,pID,false)
end

function Monopoly:jumpStreet(street,pID)
	local street = tonumber(street)
	local pID = tonumber(pID)
	MoveToken(street,0,pID,true)

end

function Monopoly:EstateAuction(nPrice)

end
