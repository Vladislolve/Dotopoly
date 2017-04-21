-- Sets the game boxes for each section

function IncomeTaxPass(trigger)
  print("--IncomeTaxPass called--")
  local kv = LoadKeyValues("scripts/kv/tax.kv")

  local token = trigger.activator:GetOwner()
  local playerID = token:GetPlayerID()
  local building = Entities:FindByName(nil, ("street"..Monopoly:GetCurrentPos(playerID)))


  if Monopoly:GetCurrentPos(playerID) == kv["IncomeTax"].Street then
    print("Hey")
  else
    return
  end
end








 
