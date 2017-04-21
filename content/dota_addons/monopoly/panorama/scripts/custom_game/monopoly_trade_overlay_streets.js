var Root = $.GetContextPanel();

function SelectStreet()
{
	if(Root.added == false && !Root.offerPanel)
	{
		$("#StreetOverlay_Name").style.color = '#e1ce4c';
		Root.added = true;

		GameEvents.SendCustomGameEventToServer("monopoly_trade_add_remove_street",{"remove" : 0, "name" : Root.streetName, "local": Root.local, "pID" :  	Players.GetLocalPlayer()});
	}
	else if(!Root.offerPanel)
	{
		$("#StreetOverlay_Name").style.color = 'red';
		Root.added = false;
		GameEvents.SendCustomGameEventToServer("monopoly_trade_add_remove_street",{"remove" : 1, "name" : Root.streetName, "local": Root.local, "pID" :  	Players.GetLocalPlayer()});
	}
}

(function(){

	Root.added = false;
	$("#StreetOverlay_Name").text = $.Localize("npc_monopoly_estate_"+Root.streetName);

	if(Root.offerPanel == true)
	{
		$("#StreetOverlay_Name").style.color = '#e1ce4c';
	}
})();