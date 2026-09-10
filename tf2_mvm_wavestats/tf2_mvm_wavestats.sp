#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_PREFIX	"{unique}[MvMStats]{default}"

#define TANK_HISTORY_SIZE	MAXPLAYERS + 1

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

#if SOURCEMOD_V_MINOR >= 13
methodmap TankMap < IntMap
{
	public bool RegisterTank(int tank)
	{
		//History is an array indexed by client, each representing their damage towards this specific tank
		//All default damage values are 0 unless we say otherwise
		int iTankDamageHistory[TANK_HISTORY_SIZE] = {0, ...};
		return this.SetArray(tank, iTankDamageHistory, sizeof(iTankDamageHistory), false);
	}
	
	public bool IsTankRegistered(int tank)
	{
		return this.ContainsKey(tank);
	}
	
	public void RemoveTank(int tank)
	{
		this.Remove(tank);
	}
	
	public void RemoveAllTanks()
	{
		this.Clear();
	}
	
	//Register the damage tracked for a specific client
	public void AddTankDamage(int tank, int client, int damage)
	{
		int iTankDamageHistory[TANK_HISTORY_SIZE];
		
		if (!this.GetArray(tank, iTankDamageHistory, sizeof(iTankDamageHistory)))
		{
			ThrowError("Tank Boss %d not registered!", tank);
			return;
		}
		
		iTankDamageHistory[client] += damage;
		this.SetArray(tank, iTankDamageHistory, sizeof(iTankDamageHistory), true);
	}
	
	public void RemoveTankDamageHistory(int client)
	{
		//Wipe any trace of this player from every active tank's damage history
		IntMapSnapshot shot = this.Snapshot();
		
		for (int i = 0; i < shot.Length; i++)
		{
			int iTankDamageHistory[TANK_HISTORY_SIZE];
			
			if (this.GetArray(shot.GetKey(i), iTankDamageHistory, sizeof(iTankDamageHistory)))
			{
				iTankDamageHistory[client] = 0;
				this.SetArray(tank, iTankDamageHistory, sizeof(iTankDamageHistory), true);
			}
		}
		
		shot.Close();
	}
}
#endif

Handle g_hHudSyncObject;
#if SOURCEMOD_V_MINOR >= 13
IntMap g_adtTanks;
#endif
char g_sCurrentMission[PLATFORM_MAX_PATH];

//Number of waves played on the current map, regardless of fail or pass
int g_iNumWavesPlayed;

esPlayerStats g_arrPlayerStats[MAXPLAYERS + 1];

#include "wavestats/menu.sp"

public Plugin myinfo =
{
	name = "[TF2] MvM Wave Statistics",
	author = "Officer Spy",
	description = "Reports details about a game after a wave has ended.",
	version = "1.0.1",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_wavestats", Command_WaveStats, "Brings up the wave statistics menu.");
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("mvm_begin_wave", Event_MvmBeginWave);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("npc_hurt", Event_NpcHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("mvm_pickup_currency", Event_MvmPickupCurrency);
	HookEvent("mvm_sniper_headshot_currency", Event_MvmSniperHeadshotCurrency);
	HookEvent("mvm_wave_complete", Event_MvmWaveComplete);
	HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
	
	g_hHudSyncObject = CreateHudSynchronizer();
#if SOURCEMOD_V_MINOR >= 13
	g_adtTanks = new IntMap();
#endif
}

public void OnMapStart()
{
	g_iNumWavesPlayed = 0;
	g_arrWaveStatsMenu.CreateMainMenu();
#if SOURCEMOD_V_MINOR >= 13
	g_adtTanks.RemoveAllTanks();
#endif
}

public void OnClientDisconnect_Post(int client)
{
	g_arrPlayerStats[client].Reset();
#if SOURCEMOD_V_MINOR >= 13
	g_adtTanks.RemoveTankDamageHistory(client);
#endif
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!strcmp(classname, "tank_boss", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, TankBoss_SpawnPost);
	}
}

public void OnEntityDestroyed(int entity)
{
#if SOURCEMOD_V_MINOR >= 13
	if (g_adtTanks.IsTankRegistered(entity))
	{
		//TODO: show tank winner?
		g_adtTanks.RemoveTank(entity);
	}
#endif
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

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int rsrc = FindEntityByClassname(-1, "tf_objective_resource");
	
	if (rsrc != -1)
	{
		TF2_GetMvMPopfileName(rsrc, g_sCurrentMission, sizeof(g_sCurrentMission));
		
		//Trim these off
		ReplaceString(g_sCurrentMission, sizeof(g_sCurrentMission), "scripts/population/", "");
		ReplaceString(g_sCurrentMission, sizeof(g_sCurrentMission), ".pop", "");
	}
	else
	{
		g_sCurrentMission = "UNKNOWN SEX MISSION";
	}
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
			int damage = event.GetInt("damageamount");
			g_arrPlayerStats[attacker].iTankDamage += damage;
			
#if SOURCEMOD_V_MINOR >= 13
			if (g_adtTanks.IsTankRegistered(entity))
				g_adtTanks.AddTankDamage(entity, attacker, damage);
#endif
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

public void TankBoss_SpawnPost(int entity)
{
	//Don't show... admins are probably fooling around between waves
	if (GameRules_GetRoundState() != RoundState_RoundRunning)
		return;
	
#if SOURCEMOD_V_MINOR >= 13
	g_adtTanks.RegisterTank(entity);
#endif
	
	int iHealth = GetEntProp(entity, Prop_Data, "m_iHealth");
	
	SetHudTextParams(0.18, 0.9, 10.0, 255, 0, 0, 255);
	
	for (int i = 0; i <= MaxClients; i++)
		if (IsClientInGame(i))
			ShowSyncHudText(i, g_hHudSyncObject, "Tank spawned with %i health!", iHealth);
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