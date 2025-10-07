#define WAVESTATS_MENU_DISPLAY_TIME	30

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
			int nCurrentWave = TF2_GetMannVsMachineWaveCount(rsrc);
			char sMissionName[PLATFORM_MAX_PATH]; TF2_GetMvMPopfileName(rsrc, sMissionName, sizeof(sMissionName));
			
			//Trim the extras
			ReplaceString(sMissionName, sizeof(sMissionName), "scripts/population/", "");
			ReplaceString(sMissionName, sizeof(sMissionName), ".pop", "");
			
			//Update title with current wave number
			this.hWaveStats.SetTitle("[MvM Wave Statistics]\n%s\nWave %d", sMissionName, nCurrentWave);
		}
		
		this.DestroySubMenus();
		this.CreateSubMenus();
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPVEDefender(i))
			{
				char sBuffer[PLATFORM_MAX_PATH];
				char sClassName[9]; GetPlayerClassName(i, sClassName, sizeof(sClassName));
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d", i, sClassName, g_arrPlayerStats[i].iKills);
				this.hKills.DrawItem(sBuffer);
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d", i, sClassName, g_arrPlayerStats[i].iDeaths);
				this.hDeaths.DrawItem(sBuffer);
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d", i, sClassName, g_arrPlayerStats[i].iDamage);
				this.hDamage.DrawItem(sBuffer);
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d", i, sClassName, g_arrPlayerStats[i].iTankDamage);
				this.hTankDamage.DrawItem(sBuffer);
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d", i, sClassName, g_arrPlayerStats[i].iHealing);
				this.hHealing.DrawItem(sBuffer);
				
				FormatEx(sBuffer, sizeof(sBuffer), "%N (%s): %d", i, sClassName, g_arrPlayerStats[i].iCredits);
				this.hCreditsCollected.DrawItem(sBuffer);
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
	//TODO: add a back button to return to the main menu
}
