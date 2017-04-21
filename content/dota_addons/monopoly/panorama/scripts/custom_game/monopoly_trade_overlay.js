"use strict";

var streetPanels = new Array();
var targetGold = 0;
var localGold = 0;
var targetStreets = new Array();
var localStreets = new Array();
var targetPID = null;
var localPID = null;

function RemoveStreetPanels()
{
	for(var x in streetPanels)
	{
		streetPanels[x].RemoveAndDeleteChildren();
	}
	streetPanels = [];
}

function ResetValues()
{
	localStreets = [];
	targetStreets = [];
	targetGold = 0;
	localGold = 0;
	targetPID = null;
	localPID = null;
}

function ResetTradePanel()
{
	$("#TargetPlayerGold").text = 0;
	$("#TargetPlayerGold").style.color = 'white';

	$("#LocalPlayerGold").text = 0;
	$("#LocalPlayerGold").style.color = 'white';

	RemoveStreetPanels();

	$.GetContextPanel().SetHasClass("show_trade_panel_overlay",false);
}

function SendTradeOverlayRequest()
{
	ResetTradePanel();
	ResetValues();

	var target = Players.GetLocalPlayerPortraitUnit(); // entIndex
	var player = Players.GetLocalPlayer(); // pID

	GameEvents.SendCustomGameEventToServer("monopoly_trade_overlay_request",{"player" : player, "target" : target});
}

// Check whether player has clicked on another player
function HeroSelectionUpdate()
{
	var pIDs = Game.GetAllPlayerIDs();
	var targetName = null;
	var localPID = Players.GetLocalPlayer()
	var localHeroIndex = Players.GetPlayerHeroEntityIndex(localPID)
	var localPortraitUnit = Players.GetLocalPlayerPortraitUnit()

	// Find targets name
	for(var x in pIDs)
	{
		if(localPortraitUnit == Players.GetPlayerHeroEntityIndex(Number(x)))
		{
			targetName = Players.GetPlayerName(Number(x));
		}
	}

	if(Entities.IsRealHero(localPortraitUnit) == true && localPortraitUnit != localHeroIndex)
	{
		$.GetContextPanel().SetHasClass("trade_start_overlay", true);
		$("#TitleName_Text").SetDialogVariable("playerName",targetName)
	}
	else
	{
		$.GetContextPanel().SetHasClass("trade_start_overlay",false);
	}
}

// Load local and target inventory in the trade window
function TradeOverlayDisplay(data)
{
	// TODO: Same as in ProcessOffer(). This should be independent
	// Probably new .xml and .js for street display
	$.GetContextPanel().SetHasClass("show_trade_offer_panel",false);
	ResetValues();
	RemoveStreetPanels();

	var containerLocal = $("#LocalPlayerItems");
	var containerTarget = $("#TargetPlayerItems");
	var street = null;

	// Create panel for each street
	for(var x in data)
	{
		for(var y in data[x])
		{
			if(x == "local")
			{
				street = $.CreatePanel('Panel',containerLocal,1);
				street.streetName = data[x][y];
				street.local = 1;
				street.BLoadLayout("file://{resources}/layout/custom_game/monopoly_trade_overlay_streets.xml",false, false);
				streetPanels.push(street);
			}

			if(x == "target")
			{
				street = $.CreatePanel('Panel',containerTarget,1);
				street.streetName = data[x][y];
				street.local = 0;
				street.BLoadLayout("file://{resources}/layout/custom_game/monopoly_trade_overlay_streets.xml",false, false);
				streetPanels.push(street);
			}

		}
		if(x == "targetPID")
		{
			targetPID = data[x]; // Save target pID to send the offer later on
		}
	}

	$.GetContextPanel().SetHasClass("show_trade_panel_overlay",true);
}

function OnLocalGoldSubmit()
{

	var isNumber = !isNaN(Number($("#LocalPlayerGold").text));
	var gold = Number($("#LocalPlayerGold").text);
	
	if(isNumber && gold > 0)
	{
		$("#LocalPlayerGold").style.color = '#e1ce4c';
		localGold = gold;
	}
	else
	{
		$("#LocalPlayerGold").style.color = 'white';
		localGold = 0;
		$("#LocalPlayerGold").text = 0;
	}
}

function OnTargetGoldSubmit()
{
	var isNumber = !isNaN(Number($("#TargetPlayerGold").text));
	var gold = Number($("#TargetPlayerGold").text);

	if(isNumber && gold > 0)
	{
		$("#TargetPlayerGold").style.color = '#e1ce4c';
		targetGold = gold;
	}
	else
	{
		$("#TargetPlayerGold").style.color = 'white';
		$("#TargetPlayerGold").text = 0;
		targetGold = 0;
	}
}

function AddStreet(data)
{
	var streetName = data[1];
	var localStreet = data[2]; // boolean

	// See if its a local player street or targets
	if(localStreet == 1)
	{
		localStreets.push(streetName);
	}
	else
	{
		targetStreets.push(streetName);
	}
}

function RemoveStreet(data)
{
	var streetName = data[1];
	var localStreet = data[2];

	if(localStreet == 1)
	{
		for(var i = localStreets.length-1; i >= 0; i--)
		{
			if(localStreets[i] == streetName)
			{
				localStreets.splice(i,1);
			}
		}
	}
	else
	{
		for(var i = targetStreets.length-1; i >= 0; i--)
		{
			if(targetStreets[i] == streetName)
			{
				targetStreets.splice(i,1);
			}
		}
	}
}

function OnSendTrade()
{
	GameEvents.SendCustomGameEventToServer("monopoly_trade_send_offer",{"localStreets" : localStreets, "targetStreets" : targetStreets, "localGold" : localGold, "targetGold" : targetGold, "targetPID" : targetPID,"localPID" : Players.GetLocalPlayer()});

	$.GetContextPanel().SetHasClass("show_trade_panel_overlay",false);
	ResetValues();
	RemoveStreetPanels();
}

function OnTradeCancel()
{
	$.GetContextPanel().SetHasClass("show_trade_panel_overlay",false);
	ResetValues();
	RemoveStreetPanels();
}

function OnOfferAccepted()
{
	GameEvents.SendCustomGameEventToServer("monopoly_trade_accepted", {"localStreets" : localStreets, "targetStreets" : targetStreets, "localGold" : localGold, "targetGold" : targetGold, "targetPID" : targetPID,"localPID" : localPID})
	RemoveStreetPanels();
	$.GetContextPanel().SetHasClass("show_trade_offer_panel",false);
}

function OnOfferDeclined()
{
	RemoveStreetPanels();
	$.GetContextPanel().SetHasClass("show_trade_offer_panel",false);
}

function ProcessOffer(data)
{
	// TODO: Trade and offer panels should be independent
	// This should be remove later on
	$.GetContextPanel().SetHasClass("show_trade_panel_overlay",false);
	ResetValues();
	RemoveStreetPanels();

	var street;
	localStreets = data['1'];
	targetStreets = data['2'];
	localGold = data['3'];
	targetGold = data['4'];
	localPID = data['5']; // local as in the one who sent the offer
	targetPID = Players.GetLocalPlayer();

	RemoveStreetPanels();
		$("#TradeOfferPanel_Text").SetDialogVariable("playerName",Players.GetPlayerName(localPID));
	$.GetContextPanel().SetHasClass("show_trade_offer_panel",true);



	var containerLocal = $("#LocalPlayerOffers");
	var containerTarget = $("#TargetPlayerOffers");

	for(var x in targetStreets)
	{
		street = $.CreatePanel('Panel',containerLocal,1);
		street.streetName = targetStreets[x];
		street.offerPanel = true;
		$("#TargetGoldOffer_Text").style.color = '#e1ce4c';
		street.BLoadLayout("file://{resources}/layout/custom_game/monopoly_trade_overlay_streets.xml",false, false);
		streetPanels.push(street);
	}
	
	for(var x in localStreets)
	{
		street = $.CreatePanel('Panel',containerTarget,1);
		street.streetName = localStreets[x];
		street.offerPanel = true;
		$("#LocalGoldOffer_Text").style.color = '#e1ce4c';
		street.BLoadLayout("file://{resources}/layout/custom_game/monopoly_trade_overlay_streets.xml",false, false);
		streetPanels.push(street);
	}

	$("#TargetGoldOffer_Text").text = targetGold;
	$("#LocalGoldOffer_Text").text = localGold;

}

(function(){

	GameEvents.Subscribe("monopoly_trade_recieve_offer",ProcessOffer);
	GameEvents.Subscribe("monopoly_trade_add_street",AddStreet);
	GameEvents.Subscribe("monopoly_trade_remove_street",RemoveStreet);

	// We need both engine events in order to update properly
	GameEvents.Subscribe("dota_player_update_selected_unit",HeroSelectionUpdate); // Player selected a street
	GameEvents.Subscribe("dota_player_update_query_unit",HeroSelectionUpdate);
	GameEvents.Subscribe("monopoly_trade_overlay_display",TradeOverlayDisplay);

})();