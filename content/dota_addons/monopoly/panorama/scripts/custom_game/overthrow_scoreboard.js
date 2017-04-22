"use strict";

function UpdateTimer( data )
{
	var timerText = "";
	timerText += data.timer_minute_10;
	timerText += data.timer_minute_01;
	timerText += ":";
	timerText += data.timer_second_10;
	timerText += data.timer_second_01;

	$( "#Timer" ).text = timerText;

	//$.Schedule( 0.1, UpdateTimer );
}

function ShowTimer( data )
{
	$( "#Timer" ).AddClass( "timer_visible" );
}

function AlertTimer( data )
{
	$( "#Timer" ).AddClass( "timer_alert" );
}

function HideTimer( data )
{
	$( "#Timer" ).AddClass( "timer_hidden" );
}

function UpdatePlayersTurn( data )
{	
	var name;
	var pID = data.pID;
	var playerInfo = Game.GetPlayerInfo(pID);
	var playerInfoID = playerInfo.player_id;

	name = playerInfo.player_name;
	$("#VictoryPoints").text = name;

	var player;
}

(function()
{
	// We use a nettable to communicate victory conditions to make sure we get the value regardless of timing.
	//UpdateKillsToWin();
	//CustomNetTables.SubscribeNetTableListener( "game_state", OnGameStateChanged );

    GameEvents.Subscribe( "countdown", UpdateTimer );
    GameEvents.Subscribe( "show_timer", ShowTimer );
    GameEvents.Subscribe( "timer_alert", AlertTimer );
    GameEvents.Subscribe( "overtime_alert", HideTimer );
    GameEvents.Subscribe( "update_turn", UpdatePlayersTurn);
	//UpdateTimer();
})();

