#include <sourcemod>
#include <tf2_stocks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_PREFIX	"{unique}[MvMStats]{default}"

enum struct esPlayerStats
{
	int iKills;
	int iDeaths;
	int iDamage;
	int iTankDamage;
	int iHealing;
	int iCredits;
	
	void Reset()
	{
		this.iKills = 0;
		this.iDeaths = 0;
		this.iDamage = 0;
		this.iTankDamage = 0;
		this.iHealing = 0;
		this.iCredits = 0;
	}
}

//Number of waves played on the current map, regardless of fail or pass
int g_iNumWavesPlayed;

esPlayerStats g_arrPlayerStats[MAXPLAYERS + 1];

#include "wavestats/menu.sp"

public Plugin myinfo =
{
	name = "[TF2] MvM Wave Statistics",
	author = "Officer Spy",
	description = "Reports details about a game after a wave has ended.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_wavestats", Command_WaveStats, "Brings up the wave statistics menu.");
	HookEvent("mvm_begin_wave", Event_MvmBeginWave);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("npc_hurt", Event_NpcHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("mvm_pickup_currency", Event_MvmPickupCurrency);
	HookEvent("mvm_sniper_headshot_currency", Event_MvmSniperHeadshotCurrency);
	HookEvent("mvm_wave_complete", Event_MvmWaveComplete);
	HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
}

public void OnMapStart()
{
	g_iNumWavesPlayed = 0;
	g_arrWaveStatsMenu.CreateMainMenu();
}

public void OnClientDisconnect_Post(int client)
{
	g_arrPlayerStats[client].Reset();
}

public Action Command_WaveStats(int client, int args)
{
	if (g_iNumWavesPlayed < 1)
	{
		CReplyToCommand(client, "%s A wave hasn't happened yet.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	g_arrWaveStatsMenu.DisplayToClient(client);
	
	return Plugin_Handled;
}

public void Event_MvmBeginWave(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllPlayerStats();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iDeathFlags = event.GetInt("death_flags");
	
	if (iDeathFlags & TF_DEATHFLAG_DEADRINGER)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsPVEDefender(client))
		g_arrPlayerStats[client].iDeaths++;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (attacker > 0 && attacker != client && IsPVEDefender(attacker))
	{
		if (IsPVEInvader(client))
		{
			g_arrPlayerStats[attacker].iKills++;
		}
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsValidClientIndex(attacker) && IsPVEDefender(attacker))
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		if (client != attacker && IsPVEInvader(client))
		{
			g_arrPlayerStats[attacker].iDamage += event.GetInt("damageamount");
		}
	}
}

public void Event_NpcHurt(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("entindex");
	char classname[10]; GetEdictClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "tank_boss"))
	{
		int attacker = GetClientOfUserId(event.GetInt("attacker_player"));
		
		if (IsValidClientIndex(attacker) && IsPVEDefender(attacker))
		{
			g_arrPlayerStats[attacker].iTankDamage += event.GetInt("damageamount");
		}
	}
}

public void Event_PlayerHealed(Event event, const char[] name, bool dontBroadcast)
{
	int healer = GetClientOfUserId(event.GetInt("healer"));
	
	if (healer && IsPVEDefender(healer))
	{
		int patient = GetClientOfUserId(event.GetInt("patient"));
		
		if (IsPVEDefender(patient))
			g_arrPlayerStats[healer].iHealing += event.GetInt("amount");
	}
}

public void Event_MvmPickupCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	
	if (IsPVEDefender(client))
	{
		g_arrPlayerStats[client].iCredits += event.GetInt("currency");
	}
}

public void Event_MvmSniperHeadshotCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsPVEDefender(client))
	{
		g_arrPlayerStats[client].iCredits += event.GetInt("currency");
	}
}

public void Event_MvmWaveComplete(Event event, const char[] name, bool dontBroadcast)
{
	g_iNumWavesPlayed++;
	g_arrWaveStatsMenu.UpdateNewWaveStats();
	g_arrWaveStatsMenu.DisplayToAll();
}

public void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	g_iNumWavesPlayed++;
	g_arrWaveStatsMenu.UpdateNewWaveStats();
	g_arrWaveStatsMenu.DisplayToAll();
}

void ResetAllPlayerStats()
{
	for (int i = 1; i <= MaxClients; i++)
		g_arrPlayerStats[i].Reset();
}

bool IsPVEDefender(int client)
{
	return TF2_GetClientTeam(client) == TFTeam_Red && !TF2_IsPlayerInCondition(client, TFCond_Reprogrammed);
}

bool IsPVEInvader(int client)
{
	return TF2_GetClientTeam(client) == TFTeam_Blue;
}

stock bool IsValidClientIndex(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock void GetPlayerClassName(int client, char[] buffer, int maxlen)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:	strcopy(buffer, maxlen, "Scout");
		case TFClass_Soldier:	strcopy(buffer, maxlen, "Soldier");
		case TFClass_Pyro:	strcopy(buffer, maxlen, "Pyro");
		case TFClass_DemoMan:	strcopy(buffer, maxlen, "Demoman");
		case TFClass_Heavy:	strcopy(buffer, maxlen, "Heavy");
		case TFClass_Engineer:	strcopy(buffer, maxlen, "Engineer");
		case TFClass_Medic:	strcopy(buffer, maxlen, "Medic");
		case TFClass_Sniper:	strcopy(buffer, maxlen, "Sniper");
		case TFClass_Spy:	strcopy(buffer, maxlen, "Spy");
		case TFClass_Unknown:	strcopy(buffer, maxlen, "Undefined");
		default:	strcopy(buffer, maxlen, "Invalid Class Index");
	}
}

//Ripped from stocklib_officerspy/tf/tf_objective_resource.inc
stock int TF2_GetMannVsMachineWaveCount(int iResource)
{
	return GetEntProp(iResource, Prop_Send, "m_nMannVsMachineWaveCount");
}

//Ripped from stocklib_officerspy/tf/tf_objective_resource.inc
stock void TF2_GetMvMPopfileName(int iResource, char[] buffer, int maxlen)
{
	GetEntPropString(iResource, Prop_Send, "m_iszMvMPopfileName", buffer, maxlen);
}
