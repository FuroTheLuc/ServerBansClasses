#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1

#define _tf2_included


public Plugin myinfo =
{
	name = "BanClasses",
	author = "FuroTheLucario",
	description = "",
	version = "1.0.0",
	url = "https://github.com/FuroTheLuc/BanClasses"
};

// Global variables to store vote counts for each option
int g_VoteCounts[9];
int currentBannedClass = 10;
bool isDebug;

public void OnPluginStart()
{
	PrintToServer("Hello World!");

	PrintToServer("Shit Plugin by FuroTheLucario");

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("game_end", Event_MapEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_class", Event_PlayerClassChange);

	// Create the console variable
	CreateConVar("bc_banned_class", "0", "Set the currently banned class", FCVAR_NOTIFY | FCVAR_REPLICATED, false, 1.0, true, 9.0);
    
    // Hook the callback function to handle changes to the console variable
	Handle bannedClassConVar = FindConVar("bc_banned_class");
	if (bannedClassConVar != INVALID_HANDLE)
	{
		HookConVarChange(bannedClassConVar, OnConVarChanged);
	}
	else
	{
	    PrintToServer("Error: Failed to find the 'bc_banned_class' convar.");
	}

	isDebug = false;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // Convert the new value to an integer
    int newBannedClass = StringToInt(newValue);
    
    // Check if the new value is within the valid range (1-9)
    if (newBannedClass >= 1 && newBannedClass <= 9)
    {
        // Update the internal variable
        currentBannedClass = newBannedClass;
        PrintToServer("Currently banned class set to: %d", currentBannedClass);
    }
    else
    {
        // Invalid value, print an error message
        PrintToServer("Invalid value for bc_banned_class. Value must be between 1 and 9.");
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim_id = event.GetInt("userid");
	int attacker_id = event.GetInt("attacker");

	int victim = GetClientOfUserId(victim_id);
	int attacker = GetClientOfUserId(attacker_id);

	char victim_name[64], attacker_name[64];
	GetClientName(victim, victim_name, sizeof(victim_name));
	GetClientName(attacker, attacker_name, sizeof(attacker_name));

	PrintToServer("%s was killed by %s", victim_name, attacker_name);

	if(!isDebug){return;}

	// Clear vote counts for each option
	for (int i = 0; i < 9; i++)
    {
		g_VoteCounts[i] = 0;
    }

    // Create and display the vote menu
	Handle voteMenu = CreateVoteMenu();
	DisplayVoteMenu(voteMenu);

    // Set a timer to wait for 15 seconds before tallying the votes
	CreateTimer(15.0, Timer_TallyVotes);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("A new round has started!");
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("The round has ended!");

    // Clear vote counts for each option
	for (int i = 0; i < 9; i++)
	{
    	g_VoteCounts[i] = 0;
	}

    // Create and display the vote menu
	Handle voteMenu = CreateVoteMenu();
	DisplayVoteMenu(voteMenu);

    // Set a timer to wait for 15 seconds before tallying the votes
	CreateTimer(15.0, Timer_TallyVotes);
}

public Action Timer_TallyVotes(Handle timer)
{
	int highestVotedOption = 0;
	int highestVoteCount = g_VoteCounts[0];

    // Find the highest-voted option
	for (int i = 1; i < 9; i++)
	{
		if (g_VoteCounts[i] > highestVoteCount)
		{
			highestVotedOption = i;
			highestVoteCount = g_VoteCounts[i];
		}
	}

    // Print the highest-voted option to the console
	PrintToServer("The highest voted option is: Option %d with %d votes", highestVotedOption + 1, highestVoteCount);
	currentBannedClass = highestVotedOption;
	PrintToServer("%d", currentBannedClass);
	return Plugin_Continue;
}

public void Event_MapEnd(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("The map has ended!");

	for (int i = 0; i < 9; i++)
	{
		g_VoteCounts[i] = 0;
	}

	Handle voteMenu = CreateVoteMenu();
	DisplayVoteMenu(voteMenu);
}

public void DisplayVoteMenu(Handle menu)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        DisplayMenu(menu, i, 15);
    }
}

public Handle CreateVoteMenu()
{
	MenuHandler handler = Event_VoteMenuHandler;
	Handle voteMenu = CreateMenu(handler);

	AddMenuItem(voteMenu, "Scout", "Scout", 0);
	AddMenuItem(voteMenu, "Soldier", "Soldier", 0);
	AddMenuItem(voteMenu, "Pyro", "Pyro", 0);
	AddMenuItem(voteMenu, "Demoman", "Demoman", 0);
	AddMenuItem(voteMenu, "Heavy", "Heavy", 0);
	AddMenuItem(voteMenu, "Engineer", "Engineer", 0);
	AddMenuItem(voteMenu, "Medic", "Medic", 0);
	AddMenuItem(voteMenu, "Sniper", "Sniper", 0);
	AddMenuItem(voteMenu, "Spy", "Spy", 0);

	return voteMenu;
}

public int Event_VoteMenuHandler(Handle menu, MenuAction action, int client, int item)
{
	char voteMessage[128];
	char item_str[16];

	Format(item_str, sizeof(item_str), "%d", item);

	Format(voteMessage, sizeof(voteMessage), "Client %d voted for option %s", client, item_str);

	if (client >= 1 && client <= MaxClients && IsClientInGame(client))
	{
		// The client index is valid and the client is in the game
		PrintToChat(client, voteMessage);

		// Increment the vote count for the selected option
		g_VoteCounts[item]++;
	}

	return 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    CheckAndImmobizePlayer(client);
}

public void Event_PlayerClassChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    CheckAndImmobizePlayer(client);
}

public void CheckAndImmobizePlayer(int client)
{
	int playerClass = GetEntProp(client, Prop_Send, "m_iClass");

	PrintToServer("Client %d is class %d!", client, playerClass);

	int CurrentBannedClassAsInternal = 10;
	if(currentBannedClass == 0) {CurrentBannedClassAsInternal = 1;}
	else if(currentBannedClass == 1) { CurrentBannedClassAsInternal = 3;}
	else if(currentBannedClass == 2) { CurrentBannedClassAsInternal = 7;}
	else if(currentBannedClass == 3) { CurrentBannedClassAsInternal = 4;}
	else if(currentBannedClass == 4) { CurrentBannedClassAsInternal = 6;}
	else if(currentBannedClass == 5) { CurrentBannedClassAsInternal = 9;}
	else if(currentBannedClass == 6) { CurrentBannedClassAsInternal = 5;}
	else if(currentBannedClass == 7) { CurrentBannedClassAsInternal = 2;}
	else if(currentBannedClass == 8) { CurrentBannedClassAsInternal = 8;}


	PrintToServer("Current Banned: %d Current Banned Internal %d", currentBannedClass, CurrentBannedClassAsInternal);


	if(playerClass == CurrentBannedClassAsInternal)
	{
		PrintToChat(client, "Playing Banned Class, please change! %d", playerClass);
		RenderMode kRenderTransColor = RENDER_TRANSCOLOR;
		SetEntityRenderMode(client, kRenderTransColor);
		SetEntityRenderColor(client, 255, 255, 255, 100);
		TF2_StunPlayer(client, 9999.0, 100.0, TF_STUNFLAG_SLOWDOWN);
	}else
	{
		//PrintToChat(client, "You are okay! %d", playerClass);
		RenderMode kRenderNormal = RENDER_NORMAL;
		SetEntityRenderMode(client, kRenderNormal);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}