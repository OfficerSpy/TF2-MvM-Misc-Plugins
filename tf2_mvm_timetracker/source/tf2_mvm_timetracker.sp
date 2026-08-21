#include <sourcemod>
#include <sdktools>

#include <stocklib_officerspy/tf/tf_objective_resource>

#pragma semicolon 1
#pragma newdecls required

#define MVM_WAVE_NUMBER_MAX	64
#define RECORD_DATA_PATH	"data/mvmtimetracker.txt"

float g_flWaveTimes[MVM_WAVE_NUMBER_MAX];
bool g_bWavePassed[MVM_WAVE_NUMBER_MAX];
float g_flWaveStartTime = 0.0;
float g_flWavesTotalTime = 0.0;
int g_iLastWaveNumber = 0;
int g_iFailCounterTick = 0;
Handle g_hWaveTimeTimer = null;
int g_iWaveFailCount;

static bool m_bIsSpeedrun;
static float m_flSpeedrunStartTime;

ConVar mvmtimetracker_write_wave_time;
ConVar mvmtimetracker_wavetime_text_color1;
ConVar mvmtimetracker_wavetime_text_color2;


char g_sWaveTimeTextColor1[PLATFORM_MAX_PATH], g_sWaveTimeTextColor2[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "[TF2] MvM Mission Time Tracker",
	author = "Officer Spy",
	description = "Reports details about a game after a wave has ended.",
	version = "1.0.2",
	url = ""
};

public void OnPluginStart()
{
	mvmtimetracker_write_wave_time = CreateConVar("sm_mvmtimetracker_write_wave_time", "1", "write wave time in client chat", FCVAR_NONE);
	mvmtimetracker_wavetime_text_color1 = CreateConVar("sm_mvmtimetracker_wavetime_text_color1", "00FFFF", "Text color for wave time sentence", FCVAR_NONE);
	mvmtimetracker_wavetime_text_color2 = CreateConVar("sm_mvmtimetracker_wavetime_text_color2", "FFD800", "Text color for wave time time", FCVAR_NONE);
	
	
	HookConVarChange(mvmtimetracker_wavetime_text_color1, ConVarChanged_WaveTimeTextColor);
	HookConVarChange(mvmtimetracker_wavetime_text_color2, ConVarChanged_WaveTimeTextColor);
	
	RegConsoleCmd("sm_wave_time", Command_WaveTime, "Shows times for all waves in the mission");
	RegConsoleCmd("sm_wave_summary", Command_WaveTime, "Shows times for all waves in the mission");
	
	HookEvent("mvm_begin_wave", Event_MvmBeginWave);
	HookEvent("mvm_wave_complete", Event_MvmWaveComplete);
	HookEvent("mvm_wave_failed", Event_MvmWaveFailed);
	HookEvent("mvm_mission_complete", Event_MvmMissionComplete);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	
	mvmtimetracker_wavetime_text_color1.GetString(g_sWaveTimeTextColor1, sizeof(g_sWaveTimeTextColor1));
	mvmtimetracker_wavetime_text_color2.GetString(g_sWaveTimeTextColor2, sizeof(g_sWaveTimeTextColor2));
}

public void OnMapStart()
{
	ResetTimeStats();
	
	//Timer is stopped on map change so this won't be valid here
	if (g_hWaveTimeTimer)
		g_hWaveTimeTimer = null;
}


public void ConVarChanged_WaveTimeTextColor(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == mvmtimetracker_wavetime_text_color1)
		strcopy(g_sWaveTimeTextColor1, sizeof(g_sWaveTimeTextColor1), newValue);
	else if (convar == mvmtimetracker_wavetime_text_color2)
		strcopy(g_sWaveTimeTextColor2, sizeof(g_sWaveTimeTextColor2), newValue);
}

public Action Command_WaveTime(int client, int args)
{
	DisplayWaveTimesTotal(client);
	return Plugin_Handled;
}

public void Event_MvmBeginWave(Event event, const char[] name, bool dontBroadcast)
{
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
	g_iLastWaveNumber = TF2_GetMannVsMachineWaveCount(resource);
	g_flWaveStartTime = GetGameTime();
	
	if (g_iLastWaveNumber == 1)
	{
		//Start a new speedrun on the first wave
		StartSpeedrun();
	}

	if (mvmtimetracker_write_wave_time.BoolValue)
		g_hWaveTimeTimer = CreateTimer(60.0, Timer_UpdateMissionProgressTime, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_MvmWaveComplete(Event event, const char[] name, bool dontBroadcast)
{
	g_bWavePassed[g_iLastWaveNumber] = true;
	g_flWaveTimes[g_iLastWaveNumber] = GetGameTime() - g_flWaveStartTime;
	g_flWavesTotalTime += GetGameTime() - g_flWaveStartTime;
	
	
	g_iLastWaveNumber = 0;

	if (mvmtimetracker_write_wave_time.BoolValue)
		DisplayWaveTimes();
	
	if (m_bIsSpeedrun)
		DisplaySpeedrunTime();
	
	if (g_hWaveTimeTimer != null)
	{
		KillTimer(g_hWaveTimeTimer);
		g_hWaveTimeTimer = null;
	}
}


public void Event_MvmWaveFailed(Event event, const char[] name, bool dontBroadcast)
{
	g_iFailCounterTick++;
	
	//If this event is fired 4 times in one tick, it's a mission restart
	if (g_iFailCounterTick > 3)
		MissionRestarted();
	
	//Failing the first wave doesn't count
	if (g_iLastWaveNumber == 1)
		MissionRestarted();
	
	CreateTimer(0.00, Timer_ResetFailCounter, 0);
	
	if (g_iLastWaveNumber != 0)
	{
		g_flWaveTimes[g_iLastWaveNumber] = GetGameTime() - g_flWaveStartTime;
		g_flWavesTotalTime += GetGameTime() - g_flWaveStartTime;
		g_iWaveFailCount++;

		if (mvmtimetracker_write_wave_time.BoolValue)
			DisplayWaveTimes();
	}
	
	g_iLastWaveNumber = 0;
	
	if (g_hWaveTimeTimer != null)
	{
		KillTimer(g_hWaveTimeTimer);
		g_hWaveTimeTimer = null;
	}
	
	//The speedrun is no longer valid if we failed
	InvalidateSpeedrun();
}

public void Event_MvmMissionComplete(Event event, const char[] name, bool dontBroadcast)
{
	// PrintToServer("Mission complete");
	// PrintToChatAll("Mission complete");

	if (mvmtimetracker_write_wave_time.BoolValue)
		DisplayWaveTimesTotal();
	
	if (m_bIsSpeedrun)
	{
		int newTime = RoundToFloor(GetGameTime() - m_flSpeedrunStartTime);
		char sMission[PLATFORM_MAX_PATH]; GetCurrentMissionName(sMission, sizeof(sMission));
		
		if (newTime < GetSpeedrunRecordTime(sMission))
		{
			SetSpeedrunRecordTime(sMission, newTime);
			
			
			PrintToChatAll("\x07%sA NEW RECORD HAS BEEN SET!", "FFD700");
			LogMessage("New record set for mission %s (time: %d)", sMission, newTime);
		}
	}
	
	
	ResetTimeStats();
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hWaveTimeTimer != null)
	{
		KillTimer(g_hWaveTimeTimer);
		g_hWaveTimeTimer = null;
	}
}

public Action Timer_ResetFailCounter(Handle timer, any value)
{
	g_iFailCounterTick = 0;
	return Plugin_Stop;
}

public Action Timer_UpdateMissionProgressTime(Handle timer, any value)
{
	DisplayCurrentWaveTime();
	return Plugin_Continue;
}


void ResetTimeStats()
{
	for (int i = 0; i < MVM_WAVE_NUMBER_MAX; i++)
	{
		g_flWaveTimes[i] = 0.0;
		g_bWavePassed[i] = false;
	}
	
	g_flWaveStartTime = 0.0;
	g_flWavesTotalTime = 0.0;
	g_iLastWaveNumber = 0;
	g_iWaveFailCount = 0;
	
	InvalidateSpeedrun();
}

void DisplayCurrentWaveTime()
{
	if (g_iLastWaveNumber == 0)
		return;
	
	char timestr[64];
	WriteTime(GetGameTime() - g_flWaveStartTime, timestr, sizeof(timestr));
	PrintToChatAll("\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
}

float GetWaveSuccessTime()
{
	float success_time = 0.0;

	for (int i = 1; i < sizeof(g_bWavePassed); i++)
	{
		if (g_bWavePassed[i])
			success_time += g_flWaveTimes[i];
	}
	
	return success_time;
}

static int m_iLastWaveDisplayTick;
void DisplayWaveTimes()
{
	if (m_iLastWaveDisplayTick == GetGameTickCount())
		return;

	char timestr[64];
	
	if (g_iLastWaveNumber != 0)
	{
		WriteTime(g_flWaveTimes[g_iLastWaveNumber], timestr, sizeof(timestr));
		PrintToChatAll("\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
	}

	WriteTime(GetWaveSuccessTime(), timestr, sizeof(timestr));
	PrintToChatAll("\x07%sTotal success time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	WriteTime(g_flWavesTotalTime, timestr, sizeof(timestr));
	PrintToChatAll("\x07%sTotal time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	m_iLastWaveDisplayTick = GetGameTickCount();
}

void DisplayWaveTimesTotal(int client = 0)
{
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
	int max_wave = TF2_GetMannVsMachineMaxWaveCount(resource);

	char timestr[64];
	char strprint[256];
	
	for (int i = 1; i <= max_wave; i++)
	{
		WriteTime(g_flWaveTimes[i], timestr, sizeof(timestr));
		FormatEx(strprint, sizeof(strprint), "\x07%s[Wave %d] Time spent:\x07%s %s", g_sWaveTimeTextColor1, i, g_sWaveTimeTextColor2, timestr);
		
		if (g_bWavePassed[i])
			Format(strprint, sizeof(strprint), "%s %s", strprint, "\x077FFF8E(Success)");
		else if (g_flWaveTimes[i] > 0)
			Format(strprint, sizeof(strprint),"%s %s", strprint, "\x07FF5661(Fail)");
		else
			Format(strprint, sizeof(strprint), "%s %s", strprint, "\x07FFF47F(Not played)");
		
		if (client == 0)
			PrintToChatAll(strprint);
		else
			PrintToChat(client, strprint);
	}
	
	if (client > 0)
	{
		WriteTime(g_flWaveTimes[g_iLastWaveNumber], timestr, sizeof(timestr));
		PrintToChat(client, "\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
		WriteTime(GetWaveSuccessTime(), timestr, sizeof(timestr));
		PrintToChat(client, "\x07%sTotal success time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
		WriteTime(g_flWavesTotalTime, timestr, sizeof(timestr));
		PrintToChat(client, "\x07%sTotal time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	}
	else
	{
		//TODO: change this as rather multiple calls of PrintToChatAll is rather redundant
		WriteTime(g_flWaveTimes[g_iLastWaveNumber], timestr, sizeof(timestr));
		PrintToChatAll("\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
		WriteTime(GetWaveSuccessTime(), timestr, sizeof(timestr));
		PrintToChatAll("\x07%sTotal success time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
		WriteTime(g_flWavesTotalTime, timestr, sizeof(timestr));
		PrintToChatAll("\x07%sTotal time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	}
}

void MissionRestarted()
{
	ResetTimeStats();
}

void StartSpeedrun()
{
	m_bIsSpeedrun = true;
	m_flSpeedrunStartTime = GetGameTime();
}

void InvalidateSpeedrun()
{
	m_bIsSpeedrun = false;
	m_flSpeedrunStartTime = 0.0;
}

void DisplaySpeedrunTime()
{
	char sTime[64]; WriteTime(GetGameTime() - m_flSpeedrunStartTime, sTime, sizeof(sTime));
	PrintToChatAll("\x07%sTotal speedrun time: %s", "99FF99", sTime);
}

//Get the record time of the specified mission name
int GetSpeedrunRecordTime(const char[] sMission)
{
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), RECORD_DATA_PATH);
	
	KeyValues kv = new KeyValues("MissionTimes");
	
	if (!kv.ImportFromFile(filePath))
	{
		kv.Close();
		return 999998;
	}
	
	if (kv.JumpToKey(sMission))
	{
		int recordTime = kv.GetNum("speedrun_time");
		kv.Close();
		return recordTime;
	}
	
	kv.Close();
	
	return 999999;
}

//Set the specified mission's name record time with a new time
void SetSpeedrunRecordTime(const char[] sMission, int newTime)
{
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), RECORD_DATA_PATH);
	
	KeyValues kv = new KeyValues("MissionTimes");
	
	kv.ImportFromFile(filePath);
	
	if (kv.JumpToKey(sMission, true))
	{
		kv.SetNum("speedrun_time", newTime);
		kv.SetNum("speedrun_timestamp", GetTime());
		kv.Rewind();
		kv.ExportToFile(filePath);
	}
	
	kv.Close();
}


stock void WriteTime(float time, char[] str, int maxlen)
{
	int timeint = RoundToFloor(time);
	const int secPerHour = 3600;
	const int secPerMinute = 60;
	
	if (timeint / secPerHour > 0)
		FormatEx(str, maxlen, "%d h %d min %d sec", timeint / secPerHour, (timeint / secPerMinute) % secPerMinute, (timeint) % secPerMinute);
	else if (timeint / secPerMinute > 0)
		FormatEx(str, maxlen, "%d min %d sec", (timeint / secPerMinute) % secPerMinute, (timeint) % secPerMinute);
	else
		FormatEx(str, maxlen, "%d sec", (timeint) % secPerMinute);
}

stock void GetCurrentMissionName(char[] buffer, int maxlen)
{
	int rsrc = FindEntityByClassname(-1, "tf_objective_resource");
	
	if (rsrc != -1)
	{
		TF2_GetMvMPopfileName(rsrc, buffer, maxlen);
		ReplaceString(buffer, maxlen, "scripts/population/", "");
		ReplaceString(buffer, maxlen, ".pop", "");
	}
	else
	{
		LogError("GetCurrentMissionName: Could not find entity tf_objective_resource!");
	}
}

stock void WriteTimeLong(float time, char[] str, int maxlen)
{
	int timeint = RoundToFloor(time);
	const int secPerHour = 3600;
	const int secPerMinute = 60;
	
	if (timeint / secPerHour > 0)
		FormatEx(str, maxlen, "%d hour(s) %d minute(s) %d second(s)", timeint / secPerHour, (timeint / secPerMinute) % secPerMinute, (timeint) % secPerMinute);
	else if (timeint / secPerMinute > 0)
		FormatEx(str, maxlen, "%d minute(s) %d second(s)", (timeint / secPerMinute) % secPerMinute, (timeint) % secPerMinute);
	else
		FormatEx(str, maxlen, "%d second(s)", (timeint) % secPerMinute);
}

stock int GetFinalWaveNumber()
{
	int rsrc = FindEntityByClassname(-1, "tf_objective_resource");
	
	if (rsrc != -1)
		return TF2_GetMannVsMachineMaxWaveCount(rsrc);
	
	return -69;
}