"use strict";

function ClearMovementMessage()
{
	$.GetContextPanel().SetHasClass("movement_notification", false);
}

function PlayerMovementNotification( data )
{
	var text1 = "Player ";
	var text2 = "Has moved to street ";
	var nStreet = data.nStreet;
	var player = Game.GetPlayerInfo(data.pID);
	var name = player.player_name;

	$.GetContextPanel().SetHasClass("movement_notification", true);
	$("#PlayerMoved_Text").SetDialogVariable("name",name);
	$("#PlayerMoved_Text").SetDialogVariable("number",nStreet);
	//Game.EmitSound("Tutorial.TaskProgress");
	$.Schedule(6, ClearMovementMessage);
}

function ClearBoughtStreetMessage()
{
	$.GetContextPanel().SetHasClass("buy_notification", false);
}

function PlayerBoughtStreet(data)
{
	var player = Game.GetPlayerInfo(data.pID);
	//$.Msg(data);

	$.GetContextPanel().SetHasClass("buy_notification", true);
	$( "#BoughtStreet_Text").SetDialogVariable("name",player.player_name);
	$( "#BoughtStreet_Text").SetDialogVariable("street",$.Localize("npc_monopoly_estate_"+data.streetName));
	$( "#BoughtStreet_Text").SetDialogVariable("number",data.streetNumber);
	$( "#BoughtStreet_Text").SetDialogVariable("gold",data.price);

	$.Schedule(6, ClearBoughtStreetMessage);

}

function ClearCommunityEvent()
{
	$.GetContextPanel().SetHasClass("community_event_trigger", false);
}

function CommunityEvent(data)
{
	var title = "Community Event!";
	var action = data.text;
	var name = Game.GetPlayerInfo(data.pID).player_name;

	$.Msg(data);

	$.GetContextPanel().SetHasClass("community_event_trigger",true);

	$( "#CommunityEvent_Title").text = $.Localize("#CommunityEventTitle")
	$( "#CommunityEvent_Text").SetDialogVariable("name",name);
	$( "#CommunityEvent_Prize").text = $.Localize("#CommunityEvent_"+action);

	$.Schedule(5, ClearCommunityEvent);
}

function EndTurnNotification(data)
{
	$.GetContextPanel().SetHasClass("end_turn_button",true);
	$("#EndTurnButton_Text").text = $.Localize("#EndTurnButton");

}

function RemoveEndTurnNotification()
{
	$.GetContextPanel().SetHasClass("end_turn_button",false);
}

function EndTurnCall()
{
	GameEvents.SendCustomGameEventToServer("monopoly_end_turn_call",{})
	RemoveEndTurnNotification();

}

function PaymentNotification(data)
{
	
}

function ShowStreetStats(data)
{

		if(data.nohouses != 1)
		{
			$.GetContextPanel().SetHasClass("show_nohouse_street_stats",false);
			$.GetContextPanel().SetHasClass("show_house_street_stats",true);
			$( "#StreetInfoHouse_Text").SetDialogVariable("name",$.Localize("#npc_monopoly_estate_"+data.name));
			$( "#StreetInfoHouse_Text").SetDialogVariable("price",data.price);
			$( "#StreetInfoHouse_Text").SetDialogVariable("rent",data.rent);
			$( "#StreetInfoHouse_Text").SetDialogVariable("mortgage",data.mortgage);
			$( "#StreetInfoHouse_Text").SetDialogVariable("link1",$.Localize("npc_monopoly_estate_"+data.link1));
			$( "#StreetInfoHouse_Text").SetDialogVariable("link2",$.Localize("npc_monopoly_estate_"+data.link2));
			$( "#StreetInfoHouse_Text").SetDialogVariable("link3",$.Localize("npc_monopoly_estate_"+data.link3));
			$( "#StreetInfoHouse_Text").SetDialogVariable("building_cost",data.building_cost);
			$( "#StreetInfoHouse_Text").SetDialogVariable("house1",data.house1);
			$( "#StreetInfoHouse_Text").SetDialogVariable("house2",data.house2);
			$( "#StreetInfoHouse_Text").SetDialogVariable("house3",data.house3);
			$( "#StreetInfoHouse_Text").SetDialogVariable("house4",data.house4);
			$( "#StreetInfoHouse_Text").SetDialogVariable("house5",data.house5);
		}
		else 
		{
			$.GetContextPanel().SetHasClass("show_house_street_stats",false);
			$.GetContextPanel().SetHasClass("show_nohouse_street_stats",true);
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("name",$.Localize("#npc_monopoly_estate_"+data.name));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("price",$.Localize(+data.price));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("rent1",$.Localize(+data.rent1));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("rent2",$.Localize(+data.rent2));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("rent3",$.Localize(+data.rent3));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("rent4",$.Localize(+data.rent4));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("mortgage",$.Localize(+data.mortgage));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("link1",$.Localize("npc_monopoly_estate_"+data.link1));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("link2",$.Localize("npc_monopoly_estate_"+data.link2));
			$( "#StreetInfoNoHouse_Text").SetDialogVariable("link3",$.Localize("npc_monopoly_estate_"+data.link3));
		}


}

function ClearStreetStats()
{
	$.GetContextPanel().SetHasClass("show_street_stats",false);
}

// Send info of the unit selected and playerID
function UnitSelectionUpdate()
{
	var heroName = Entities.GetUnitName(Players.GetLocalPlayerPortraitUnit());
	GameEvents.SendCustomGameEventToServer("monopoly_street_stats_update",{"hero" : heroName});
	// Send custom game event to query stats from streets
	//$.Msg(kvStreets,"  ",Entities.GetUnitName(Players.GetLocalPlayerPortraitUnit(0))); // TODO: This has to be used to show the players a panel with values for each street	
}

(function() {

	GameEvents.Subscribe("monopoly_movement_notification", PlayerMovementNotification);
	GameEvents.Subscribe("monopoly_buy_notification", PlayerBoughtStreet);
	GameEvents.Subscribe("special_events_community", CommunityEvent); // General special_events function
	GameEvents.Subscribe("end_turn_notification_enable",EndTurnNotification); // Enable end button
	GameEvents.Subscribe("end_turn_notification_disable",RemoveEndTurnNotification);

	// We need both engine events in order to update properly
	GameEvents.Subscribe("dota_player_update_selected_unit",UnitSelectionUpdate); // Player selected a street
	GameEvents.Subscribe("dota_player_update_query_unit",UnitSelectionUpdate); 
	GameEvents.Subscribe("monopoly_show_street_stats",ShowStreetStats);
})();