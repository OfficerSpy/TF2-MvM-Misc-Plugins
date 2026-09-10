#define WAVESTATS_MENU_DISPLAY_TIME	20

//I will admit, this array structure was taken from l4d2_skill_announce
enum
{
	STATS_PLAYER_INDEX,
	STATS_KILLS,
	STATS_DEATHS,
	STATS_DAMAGE,
	STATS_TANK_DAMAGE,
	STATS_HEALING,
	STATS_CREDITS,
	STATS_COUNT
}

enum struct esWaveStatsMenu
{
	Menu hWaveStats;
	Panel hKills;
	Panel hDeaths;
	Panel hDamage;
	Panel hTankDamage;
	Panel hHealing;
	Panel hCreditsCollected;
	
	void DisplayToClient(int client, int time = WAVESTATS_MENU_DISPLAY_TIME)
	{
		this.hWaveStats.Display(client, time);
	}
	
	void DisplayToAll(int time = WAVESTATS_MENU_DISPLAY_TIME)
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i))
				this.DisplayToClient(i, time);
	}
	
	void CreateMainMenu()
	{
		// delete this.hWaveStats;
		
		this.hWaveStats = new Menu(MenuHandler_WaveStats);
		this.hWaveStats.AddItem("0", "Robots Killed");
		this.hWaveStats.AddItem("1", "Mannco Deaths");
		this.hWaveStats.AddItem("2", "Robot Damage");
		this.hWaveStats.AddItem("3", "Tank Damage");
		this.hWaveStats.AddItem("4", "Mannco Healing");
		this.hWaveStats.AddItem("5", "Credits Collected");
	}
	
	void DestroySubMenus()
	{
		delete this.hKills;
		delete this.hDeaths;
		delete this.hDamage;
		delete this.hTankDamage;
		delete this.hHealing;
		delete this.hCreditsCollected;
	}
	
	void CreateSubMenus()
	{
		this.hKills = new Panel();
		this.hDeaths = new Panel();
		this.hDamage = new Panel();
		this.hTankDamage = new Panel();
		this.hHealing = new Panel();
		this.hCreditsCollected = new Panel();
		
		this.hKills.SetTitle("Robots Killed");
		this.hDeaths.SetTitle("Defender Deaths");
		this.hDamage.SetTitle("Damage Done");
		this.hTankDamage.SetTitle("Damage Done To Tanks");
		this.hHealing.SetTitle("Healing");
		this.hCreditsCollected.SetTitle("Credits Collected");
	}
	
	void UpdateNewWaveStats()
	{
		int rsrc = FindEntityByClassname(-1, "tf_objective_resource");
		
		if (rsrc != -1)
		{
			//Update title with current wave number
			this.hWaveStats.SetTitle("[MvM Wave Statistics]\n%s\nWave %d", g_sCurrentMission, TF2_GetMannVsMachineWaveCount(rsrc));
		}
		
		this.DestroySubMenus();
		this.CreateSubMenus();
		
		int[][] iArrStatistics = new int[MaxClients][STATS_COUNT];
		int iTotalDefenders = 0;
		
		int iTotalStats[STATS_COUNT];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPVEDefender(i))
			{
				//We used to print directly here, but now we build a new array for sorting purposes
				iArrStatistics[iTotalDefenders][STATS_PLAYER_INDEX] = i;
				iArrStatistics[iTotalDefenders][STATS_KILLS] = g_arrPlayerStats[i].iKills;
				iArrStatistics[iTotalDefenders][STATS_DEATHS] = g_arrPlayerStats[i].iDeaths;
				iArrStatistics[iTotalDefenders][STATS_DAMAGE] = g_arrPlayerStats[i].iDamage;
				iArrStatistics[iTotalDefenders][STATS_TANK_DAMAGE] = g_arrPlayerStats[i].iTankDamage;
				iArrStatistics[iTotalDefenders][STATS_HEALING] = g_arrPlayerStats[i].iHealing;
				iArrStatistics[iTotalDefenders][STATS_CREDITS] = g_arrPlayerStats[i].iCredits;
				iTotalDefenders++;
				
				//Gather the total amount from all RED players
				iTotalStats[STATS_KILLS] += g_arrPlayerStats[i].iKills;
				iTotalStats[STATS_DEATHS] += g_arrPlayerStats[i].iDeaths;
				iTotalStats[STATS_DAMAGE] += g_arrPlayerStats[i].iDamage;
				iTotalStats[STATS_TANK_DAMAGE] += g_arrPlayerStats[i].iTankDamage;
				iTotalStats[STATS_HEALING] += g_arrPlayerStats[i].iHealing;
				iTotalStats[STATS_CREDITS] += g_arrPlayerStats[i].iCredits;
			}
		}
		
		for (int i = 1; i < STATS_COUNT; i++)
		{
			Panel hPanel;
			
			//This looks kinda dumb...
			switch (i)
			{
				case STATS_KILLS:
				{
					hPanel = this.hKills;
					SortCustom2D(iArrStatistics, iTotalDefenders, SortFunc_Kills);
				}
				case STATS_DEATHS:
				{
					hPanel = this.hDeaths;
					SortCustom2D(iArrStatistics, iTotalDefenders, SortFunc_Deaths);
				}
				case STATS_DAMAGE:
				{
					hPanel = this.hDamage;
					SortCustom2D(iArrStatistics, iTotalDefenders, SortFunc_Damage);
				}
				case STATS_TANK_DAMAGE:
				{
					hPanel = this.hTankDamage;
					SortCustom2D(iArrStatistics, iTotalDefenders, SortFunc_TankDamage);
				}
				case STATS_HEALING:
				{
					hPanel = this.hHealing;
					SortCustom2D(iArrStatistics, iTotalDefenders, SortFunc_Healing);
				}
				case STATS_CREDITS:
				{
					hPanel = this.hCreditsCollected;
					SortCustom2D(iArrStatistics, iTotalDefenders, SortFunc_CreditsCollected);
				}
			}
			
			for (int j = 0; j < iTotalDefenders; j++)
			{
				char sBuffer[PLATFORM_MAX_PATH];
				char sClassName[9]; GetPlayerClassName(iArrStatistics[j][STATS_PLAYER_INDEX], sClassName, sizeof(sClassName));
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d (%d%%)", iArrStatistics[j][STATS_PLAYER_INDEX], sClassName, iArrStatistics[j][i], RoundToNearest((float(iArrStatistics[j][i]) / float(iTotalStats[i])) * 100));
				hPanel.DrawItem(sBuffer);
			}
		}
	}
}

esWaveStatsMenu g_arrWaveStatsMenu;

static void MenuHandler_WaveStats(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: g_arrWaveStatsMenu.hKills.Send(param1, MenuHandler_WaveStatsSubMenu, WAVESTATS_MENU_DISPLAY_TIME);
			case 1: g_arrWaveStatsMenu.hDeaths.Send(param1, MenuHandler_WaveStatsSubMenu, WAVESTATS_MENU_DISPLAY_TIME);
			case 2: g_arrWaveStatsMenu.hDamage.Send(param1, MenuHandler_WaveStatsSubMenu, WAVESTATS_MENU_DISPLAY_TIME);
			case 3: g_arrWaveStatsMenu.hTankDamage.Send(param1, MenuHandler_WaveStatsSubMenu, WAVESTATS_MENU_DISPLAY_TIME);
			case 4: g_arrWaveStatsMenu.hHealing.Send(param1, MenuHandler_WaveStatsSubMenu, WAVESTATS_MENU_DISPLAY_TIME);
			case 5: g_arrWaveStatsMenu.hCreditsCollected.Send(param1, MenuHandler_WaveStatsSubMenu, WAVESTATS_MENU_DISPLAY_TIME);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		CPrintToChat(param1, "%s Type {unique}!wavestats{default} to bring up this menu again.", PLUGIN_PREFIX);
	}
}

static void MenuHandler_WaveStatsSubMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		//Send to the main menu for now
		g_arrWaveStatsMenu.DisplayToClient(param1);
		return;
	}
	
	if (action == MenuAction_Cancel)
	{
		//Normally doesn't happen, but other mods can force off this menu
		CPrintToChat(param1, "%s Type {unique}!wavestats{default} to bring up this menu again.", PLUGIN_PREFIX);
	}
}

static int SortFunc_Kills(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	//Sort by descending order
	if (elem1[STATS_KILLS] > elem2[STATS_KILLS])
		return -1;
	
	if (elem1[STATS_KILLS] < elem2[STATS_KILLS])
		return 1;
	
	return 0;
}

static int SortFunc_Deaths(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[STATS_DEATHS] > elem2[STATS_DEATHS])
		return -1;
	
	if (elem1[STATS_DEATHS] < elem2[STATS_DEATHS])
		return 1;
	
	return 0;
}

static int SortFunc_Damage(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[STATS_DAMAGE] > elem2[STATS_DAMAGE])
		return -1;
	
	if (elem1[STATS_DAMAGE] < elem2[STATS_DAMAGE])
		return 1;
	
	return 0;
}

static int SortFunc_TankDamage(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[STATS_TANK_DAMAGE] > elem2[STATS_TANK_DAMAGE])
		return -1;
	
	if (elem1[STATS_TANK_DAMAGE] < elem2[STATS_TANK_DAMAGE])
		return 1;
	
	return 0;
}

static int SortFunc_Healing(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[STATS_HEALING] > elem2[STATS_HEALING])
		return -1;
	
	if (elem1[STATS_HEALING] < elem2[STATS_HEALING])
		return 1;
	
	return 0;
}

static int SortFunc_CreditsCollected(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[STATS_CREDITS] > elem2[STATS_CREDITS])
		return -1;
	
	if (elem1[STATS_CREDITS] < elem2[STATS_CREDITS])
		return 1;
	
	return 0;
}