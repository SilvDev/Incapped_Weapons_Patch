/*
*	Incapped Weapons Patch
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.20"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Incapped Weapons Patch
*	Author	:	SilverShot
*	Descrp	:	Patches the game to allow using Weapons while Incapped, instead of changing weapons scripts.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=322859
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.20 (12-Dec-2022)
	- Added cvar "l4d_incapped_weapons_heal_revive" to control if players should revive into black and white status. Requested by "BystanderZK".
	- Fixed cvar "l4d_incapped_weapons_throw" having inverted logic. Thanks to "BystanderZK" for reporting.
	- Fixed the PipeBomb effects not displaying. Thanks to "BystanderZK" for reporting.
	- Fixed taking pills in L4D1 not healing or reviving.
	- These changes are compatible with the "Heartbeat" plugin.

1.19 (09-Dec-2022)
	- Forgot to remove debug messages printing to chat. Thanks to "NoroHime" for reporting.

1.18 (06-Dec-2022)
	- Added extra checks when using Pills and Adrenaline.
	- Fixed equipping melee weapons reducing all damage given to other Survivors. Thanks to "gabuch2" for reporting.

1.17 (05-Dec-2022)
	- Fixed unhooking the wrong Think function, breaking the "pain_pills_health_threshold" cvar.
	- Changed cvars "l4d_incapped_weapons_heal_adren" and "l4d_incapped_weapons_heal_pills" to accept "-1" which will revive a player.

1.16 (05-Dec-2022)
	- Added feature to allow Pills and Adrenaline to be used while incapped. Requires the "Left 4 DHooks" plugin.
	- Added cvars "l4d_incapped_weapons_heal_adren" and "l4d_incapped_weapons_heal_pills" to control healing amount while incapped.

1.15 (22-Nov-2022)
	- Fixed cvar "l4d_incapped_weapons_throw" not preventing standing up animation when plugin is late loaded. Thanks to "TBK Duy" for reporting.

1.14 (12-Nov-2022)
	- Added cvar "l4d_incapped_weapons_throw" to optionally prevent the standing up animation when throwing grenades.
	- Now optionally uses "Left 4 DHooks" plugin to prevent standing up animation when throwing grenades.

1.13a (09-Jul-2021)
	- L4D2: Fixed GameData file from the "2.2.2.0" update.

1.13 (16-Jun-2021)
	- L4D2: Optimized plugin by resetting Melee damage hooks on map end and round start.
	- L4D2: Compatibility update for "2.2.1.3" update. Thanks to "Dragokas" for fixing.
	- GameData .txt file updated.

1.12 (08-Mar-2021)
	- Added cvar "l4d_incapped_weapons_melee" to control Melee weapon damage to Survivors. Thanks to "Mystik Spiral" for reporting.

1.11 (15-Jan-2021)
	- Fixed weapons being blocked when incapped and changing team. Thanks to "HarryPotter" for reporting.

1.10 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.

1.9 (12-Apr-2020)
	- Now keeps the active weapon selected unless it's restricted.
	- Fixed not being able to switch to melee weapons.
	- Fixed pistols possibly disappearing sometimes.
	- Fixed potential of duped pistols when dropped after incap.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.

1.8 (09-Apr-2020)
	- Fixed again not always restricting weapons correctly on incap. Thanks to "MasterMind420" for reporting.

1.7 (08-Apr-2020)
	- Fixed not equipping melee weapons when allowed on incap.

1.6 (08-Apr-2020)
	- Fixed breaking pistols, due to the last update.

1.5 (08-Apr-2020)
	- Fixed ammo being wiped when incapped, due to 1.3 update. Thanks to "Dragokas" for reporting.
	- Fixed not always restricting weapons correctly on incap. Thanks to "MasterMind420" for reporting.

1.4 (07-Apr-2020)
	- Fixed throwing a pistol when dual wielding. Thanks to "MasterMind420" for reporting.

1.3 (07-Apr-2020)
	- Fixed not equipping a valid weapon when the last equipped weapon was restricted.
	- Removed the ability to block pistols.
	- Thanks to "MasterMind420" for reporting.

1.2 (07-Apr-2020)
	- Fixed L4D1 Linux crashing. Only the plugin updated. Thanks to "Dragokas" for testing.

1.1 (07-Apr-2020)
	- Fixed hooking the L4D2 pistol cvar in L4D1. Thanks to "Alliance" for reporting.

1.0 (06-Apr-2020)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_incapped_weapons"

#define PARTICLE_FUSE		"weapon_pipebomb_fuse"
#define PARTICLE_LIGHT		"weapon_pipebomb_blinking_light"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarMaxIncap, g_hCvarhealthThresh, g_hCvarIncapHealth, g_hCvarHealAdren, g_hCvarHealPills, g_hCvarHealRevive, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarMelee, g_hCvarPist, g_hCvarRest, g_hCvarThrow;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bLeft4DHooks, g_bHeartbeat, g_bGrenadeFix, g_bLateLoad, g_bBlockChange, g_bCvarThrow;
int g_iCvarhealthThresh, g_iCvarMaxIncap, g_iCvarIncapHealth, g_iCvarHealAdren, g_iCvarHealPills, g_iCvarHealRevive, g_iCvarPist, g_iCvarMelee;
Handle g_hTimers[MAXPLAYERS+1];
bool g_bUsePills[MAXPLAYERS+1];

ArrayList g_ByteSaved_Deploy, g_ByteSaved_OnIncap;
Address g_Address_Deploy, g_Address_OnIncap;

ArrayList g_aRestrict;
StringMap g_aWeaponIDs;

// From left4dhooks
typeset AnimHookCallback
{
	/**
	 * @brief Callback called whenever animation is invoked.
	 *
	 * @param client		Client triggering.
	 * @param sequence		The animation "activity" (pre-hook) or "m_nSequence" (post-hook) sequence number being used.
	 *
	 * @return				Plugin_Changed to change animation, Plugin_Continue otherwise.
	 */
	function Action(int client, int &sequence);
}

native bool AnimHookEnable(int client, AnimHookCallback callback, AnimHookCallback callbackPost = INVALID_FUNCTION);
native bool AnimHookDisable(int client, AnimHookCallback callback, AnimHookCallback callbackPost = INVALID_FUNCTION);
native void L4D2_UseAdrenaline(int client, float fTime = 15.0, bool heal = true);
native void L4D_ReviveSurvivor(int client);

// From "Heartbeat" plugin
native int Heartbeat_GetRevives(int client);
native void Heartbeat_SetRevives(int client, int reviveCount, bool reviveLogic = true);



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Incapped Weapons Patch",
	author = "SilverShot",
	description = "Patches the game to allow using Weapons while Incapped, instead of changing weapons scripts.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=322859"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	MarkNativeAsOptional("AnimHookEnable");
	MarkNativeAsOptional("AnimHookDisable");
	MarkNativeAsOptional("L4D2_UseAdrenaline");
	MarkNativeAsOptional("L4D_ReviveSurvivor");
	MarkNativeAsOptional("Heartbeat_GetRevives");
	MarkNativeAsOptional("Heartbeat_SetRevives");

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if( strcmp(name, "left4dhooks") == 0 )
	{
		g_bLeft4DHooks = true;
	}
	else if( strcmp(name, "l4d_heartbeat") == 0 )
	{
		g_bHeartbeat = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "left4dhooks") == 0 )
	{
		g_bLeft4DHooks = false;
	}
	else if( strcmp(name, "l4d_heartbeat") == 0 )
	{
		g_bHeartbeat = false;
	}
}

public void OnAllPluginsLoaded()
{
	if( FindConVar("incapped_weapons_enable") != null )
	{
		SetFailState("Delete the old \"Incapped Weapons\" plugin to run this one.");
	}

	g_bGrenadeFix = FindConVar("l4d_unlimited_grenades_version") != null;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);



	// Patch deploy
	int iOffset = GameConfGetOffset(hGameData, "CanDeploy_Offset");
	if( iOffset == -1 ) SetFailState("Failed to load \"CanDeploy_Offset\" offset.");

	int iByteMatch = GameConfGetOffset(hGameData, "CanDeploy_Byte");
	if( iByteMatch == -1 ) SetFailState("Failed to load \"CanDeploy_Byte\" byte.");

	int iByteCount = GameConfGetOffset(hGameData, "CanDeploy_Count");
	if( iByteCount == -1 ) SetFailState("Failed to load \"CanDeploy_Count\" count.");

	g_Address_Deploy = GameConfGetAddress(hGameData, "CanDeploy");
	if( !g_Address_Deploy ) SetFailState("Failed to load \"CanDeploy\" address.");

	g_Address_Deploy += view_as<Address>(iOffset);
	g_ByteSaved_Deploy = new ArrayList();

	for( int i = 0; i < iByteCount; i++ )
	{
		g_ByteSaved_Deploy.Push(LoadFromAddress(g_Address_Deploy + view_as<Address>(i), NumberType_Int8));
	}

	if( g_ByteSaved_Deploy.Get(0) != iByteMatch ) SetFailState("Failed to load 'CanDeploy', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_ByteSaved_Deploy.Get(0), iByteMatch);



	// Patch melee
	if( g_bLeft4Dead2 )
	{
		iOffset = GameConfGetOffset(hGameData, "OnIncap_Offset");
		if( iOffset == -1 ) SetFailState("Failed to load \"OnIncap_Offset\" offset.");

		iByteMatch = GameConfGetOffset(hGameData, "OnIncap_Byte");
		if( iByteMatch == -1 ) SetFailState("Failed to load \"OnIncap_Byte\" byte.");

		iByteCount = GameConfGetOffset(hGameData, "OnIncap_Count");
		if( iByteCount == -1 ) SetFailState("Failed to load \"OnIncap_Count\" count.");

		g_Address_OnIncap = GameConfGetAddress(hGameData, "OnIncapacitatedAsSurvivor");
		if( !g_Address_OnIncap ) SetFailState("Failed to load \"OnIncapacitatedAsSurvivor\" address.");

		g_Address_OnIncap += view_as<Address>(iOffset);
		g_ByteSaved_OnIncap = new ArrayList();

		for( int i = 0; i < iByteCount; i++ )
		{
			g_ByteSaved_OnIncap.Push(LoadFromAddress(g_Address_OnIncap + view_as<Address>(i), NumberType_Int8));
		}

		if( g_ByteSaved_OnIncap.Get(0) != iByteMatch ) SetFailState("Failed to load 'OnIncap', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_ByteSaved_OnIncap.Get(0), iByteMatch);
	}

	delete hGameData;



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =			CreateConVar(	"l4d_incapped_weapons_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_incapped_weapons_modes",			"",						"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_incapped_weapons_modes_off",		"",						"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_incapped_weapons_modes_tog",		"0",					"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );

	if( g_bLeft4Dead2 )
	{
		g_hCvarHealAdren =	CreateConVar(	"l4d_incapped_weapons_heal_adren",		"25",					"L4D2 only: -1=Revive player. 0=Off. How much to heal a player when they use Adrenaline whilst incapped.", CVAR_FLAGS);
		g_hCvarMelee =		CreateConVar(	"l4d_incapped_weapons_melee",			"0",					"L4D2 only: 0=No friendly fire. 1=Allow friendly fire. When using Melee weapons should they hurt other Survivors.", CVAR_FLAGS);
		g_hCvarPist =		CreateConVar(	"l4d_incapped_weapons_pistol",			"0",					"L4D2 only: 0=Don't give pistol (allows Melee weapons to be used). 1=Give pistol (game default).", CVAR_FLAGS);
		g_hCvarRest =		CreateConVar(	"l4d_incapped_weapons_restrict",		"12,24,30,31",			"Empty string to allow all. Prevent these weapon/item IDs from being used while incapped. See plugin post for details.", CVAR_FLAGS);
	} else {
		g_hCvarRest =		CreateConVar(	"l4d_incapped_weapons_restrict",		"8",					"Empty string to allow all. Prevent these weapon/item IDs from being used while incapped. See plugin post for details.", CVAR_FLAGS);
	}

	g_hCvarHealRevive =		CreateConVar(	"l4d_incapped_weapons_heal_revive",		"0",					"0=Off. Should player enter black and white status when reviving using: 1=Pills. 2=Adrenaline. 3=Both.", CVAR_FLAGS);
	g_hCvarHealPills =		CreateConVar(	"l4d_incapped_weapons_heal_pills",		"50",					"-1=Revive player. 0=Off. How much to heal a player when they use Pain Pills whilst incapped.", CVAR_FLAGS);
	g_hCvarThrow =			CreateConVar(	"l4d_incapped_weapons_throw",			"0",					"0=Block grenade throwing animation to prevent standing up during throw (requires Left4DHooks plugin). 1=Allow throwing animation.", CVAR_FLAGS);

	CreateConVar(							"l4d_incapped_weapons_version",			PLUGIN_VERSION,			"Incapped Weapons plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_incapped_weapons");

	g_hCvarMaxIncap = FindConVar("survivor_max_incapacitated_count");
	g_hCvarhealthThresh = FindConVar("pain_pills_health_threshold");
	g_hCvarIncapHealth = FindConVar("survivor_incap_health");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");

	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	if( g_bLeft4Dead2 )
	{
		g_hCvarHealAdren.AddChangeHook(ConVarChanged_Cvars);
		g_hCvarPist.AddChangeHook(ConVarChanged_Cvars);
		g_hCvarMelee.AddChangeHook(ConVarChanged_Cvars);
	}
	g_hCvarHealPills.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHealRevive.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMaxIncap.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarhealthThresh.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarIncapHealth.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRest.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarThrow.AddChangeHook(ConVarChanged_Cvars);



	// ====================================================================================================
	// WEAPON RESTRICTION
	// ====================================================================================================
	// Taken from "Left 4 DHooks Direct", see for complete list.
	g_aWeaponIDs = new StringMap();

	if( g_bLeft4Dead2 )
	{
		g_aWeaponIDs.SetValue("weapon_pistol",						1);
		g_aWeaponIDs.SetValue("weapon_smg",							2);
		g_aWeaponIDs.SetValue("weapon_pumpshotgun",					3);
		g_aWeaponIDs.SetValue("weapon_autoshotgun",					4);
		g_aWeaponIDs.SetValue("weapon_rifle",						5);
		g_aWeaponIDs.SetValue("weapon_hunting_rifle",				6);
		g_aWeaponIDs.SetValue("weapon_smg_silenced",				7);
		g_aWeaponIDs.SetValue("weapon_shotgun_chrome",				8);
		g_aWeaponIDs.SetValue("weapon_rifle_desert",				9);
		g_aWeaponIDs.SetValue("weapon_sniper_military",				10);
		g_aWeaponIDs.SetValue("weapon_shotgun_spas",				11);
		g_aWeaponIDs.SetValue("weapon_first_aid_kit",				12);
		g_aWeaponIDs.SetValue("weapon_molotov",						13);
		g_aWeaponIDs.SetValue("weapon_pipe_bomb",					14);
		g_aWeaponIDs.SetValue("weapon_pain_pills",					15);
		g_aWeaponIDs.SetValue("weapon_melee",						19);
		g_aWeaponIDs.SetValue("weapon_chainsaw",					20);
		g_aWeaponIDs.SetValue("weapon_grenade_launcher",			21);
		g_aWeaponIDs.SetValue("weapon_adrenaline",					23);
		g_aWeaponIDs.SetValue("weapon_defibrillator",				24);
		g_aWeaponIDs.SetValue("weapon_vomitjar",					25);
		g_aWeaponIDs.SetValue("weapon_rifle_ak47",					26);
		g_aWeaponIDs.SetValue("weapon_upgradepack_incendiary",		30);
		g_aWeaponIDs.SetValue("weapon_upgradepack_explosive",		31);
		g_aWeaponIDs.SetValue("weapon_pistol_magnum",				32);
		g_aWeaponIDs.SetValue("weapon_smg_mp5",						33);
		g_aWeaponIDs.SetValue("weapon_rifle_sg552",					34);
		g_aWeaponIDs.SetValue("weapon_sniper_awp",					35);
		g_aWeaponIDs.SetValue("weapon_sniper_scout",				36);
		g_aWeaponIDs.SetValue("weapon_rifle_m60",					37);
	} else {
		g_aWeaponIDs.SetValue("weapon_pistol",						1);
		g_aWeaponIDs.SetValue("weapon_smg",							2);
		g_aWeaponIDs.SetValue("weapon_pumpshotgun",					3);
		g_aWeaponIDs.SetValue("weapon_autoshotgun",					4);
		g_aWeaponIDs.SetValue("weapon_rifle",						5);
		g_aWeaponIDs.SetValue("weapon_hunting_rifle",				6);
		g_aWeaponIDs.SetValue("weapon_first_aid_kit",				8);
		g_aWeaponIDs.SetValue("weapon_molotov",						9);
		g_aWeaponIDs.SetValue("weapon_pipe_bomb",					10);
		g_aWeaponIDs.SetValue("weapon_pain_pills",					12);
	}



	// ====================================================================================================
	// LATE LOAD
	// ====================================================================================================
	if( g_bLateLoad )
	{
		GetCvars();

		g_bLeft4DHooks = LibraryExists("left4dhooks");
		g_bHeartbeat = LibraryExists("l4d_heartbeat");

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1) == 0 )
			{
				SDKHook(i, SDKHook_WeaponCanSwitchTo, CanSwitchTo);

				if( (!g_bCvarThrow || g_iCvarHealAdren || g_iCvarHealPills) && !IsFakeClient(i) )
				{
					if( g_iCvarHealAdren || g_iCvarHealPills )
					{
						SDKHook(i, SDKHook_PreThink, OnThinkPre);
						SDKHook(i, SDKHook_PostThinkPost, OnThinkPost);
					}

					if( g_bLeft4DHooks && (!g_bCvarThrow || g_bLeft4Dead2) ) // L4D2 uses anim hook for detecting pills, L4D1 uses the PreThink
					{
						AnimHookEnable(i, OnAnimPre);
					}
				}
			}
		}
	}
}

public void OnPluginEnd()
{
	PatchAddress(false);
	PatchMelee(false);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	// PipeBomb projectile
	PrecacheParticle(PARTICLE_FUSE);
	PrecacheParticle(PARTICLE_LIGHT);

	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();

	if( g_bLeft4Dead2 )
		MeleeDamageBlock(false);

	ClearTimers();
}

public void OnClientDisconnect(int client)
{
	delete g_hTimers[client];
	g_bUsePills[client] = false;
}

void ClearTimers()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		delete g_hTimers[i];
	}
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	if( g_bBlockChange ) return;

	if( g_bLeft4Dead2 )
		g_iCvarHealAdren = g_hCvarHealAdren.IntValue;
	g_iCvarHealPills = g_hCvarHealPills.IntValue;
	g_iCvarHealRevive = g_hCvarHealRevive.IntValue;
	g_iCvarMaxIncap = g_hCvarMaxIncap.IntValue;
	g_iCvarhealthThresh = g_hCvarhealthThresh.IntValue;
	g_iCvarIncapHealth = g_hCvarIncapHealth.IntValue;
	g_bCvarThrow = g_hCvarThrow.BoolValue;

	if( g_bLeft4Dead2 )
	{
		g_iCvarPist = g_hCvarPist.IntValue;
		g_iCvarMelee = g_hCvarMelee.IntValue;
		PatchMelee(g_iCvarPist == 0);

		if( g_bCvarAllow && g_iCvarPist == 0 && g_iCvarMelee == 0 )
			MeleeDamageBlock(true);
		else
			MeleeDamageBlock(false);
	}

	// Add weapon IDs to array
	char sBlock[128];
	g_hCvarRest.GetString(sBlock, sizeof(sBlock));

	delete g_aRestrict;
	g_aRestrict = new ArrayList();

	if( sBlock[0] )
	{
		StrCat(sBlock, sizeof(sBlock), ",");

		int index, last;
		while( (index = StrContains(sBlock[last], ",")) != -1 )
		{
			sBlock[last + index] = 0;
			g_aRestrict.Push(StringToInt(sBlock[last]));
			sBlock[last + index] = ',';
			last += index + 1;
		}
	}
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		PatchAddress(true);
		PatchMelee(g_iCvarPist == 0);
		HookEvents();

		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		PatchAddress(false);
		PatchMelee(false);
		UnhookEvents();
		ResetPlugin();
		ClearTimers();

		if( g_bLeft4Dead2 )
		{
			MeleeDamageBlock(false);
		}
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
void HookEvents()
{
	HookEvent("player_incapacitated",		Event_Incapped);
	HookEvent("revive_success",				Event_ReviveSuccess);
	HookEvent("player_spawn",				Event_PlayerSpawn);
	HookEvent("player_death",				Event_PlayerDeath);
	HookEvent("player_team",				Event_PlayerDeath);
	HookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
}

void UnhookEvents()
{
	UnhookEvent("player_incapacitated",		Event_Incapped);
	UnhookEvent("revive_success",			Event_ReviveSuccess);
	UnhookEvent("player_spawn",				Event_PlayerSpawn);
	UnhookEvent("player_death",				Event_PlayerDeath);
	UnhookEvent("player_team",				Event_PlayerDeath);
	UnhookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
}

void Event_Incapped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && GetClientTeam(client) == 2 )
	{
		if( (!g_bCvarThrow || g_iCvarHealAdren || g_iCvarHealPills) && !IsFakeClient(client) )
		{
			// Prevent standing up animation when throwing grenades
			if( g_iCvarHealAdren || g_iCvarHealPills )
			{
				SDKHook(client, SDKHook_PreThink, OnThinkPre);
				SDKHook(client, SDKHook_PostThinkPost, OnThinkPost);
			}

			if( g_bLeft4DHooks && (!g_bCvarThrow || g_bLeft4Dead2) )  // L4D2 uses anim hook for detecting pills, L4D1 uses the PreThink
			{
				AnimHookEnable(client, OnAnimPre);
			}
		}

		// Melee weapons block friendly fire
		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}

		// For weapon restrictions
		SDKHook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);

		// Active allowed
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( weapon != -1 && ValidateWeapon(client, weapon) ) return;

		// Switch to primary/pistol/melee/other valid if current weapon restricted, otherwise do nothing.
		for( int i = 0; i < 5; i++ )
		{
			weapon = GetPlayerWeaponSlot(client, i);
			if( weapon != -1 && ValidateWeapon(client, weapon) )
			{
				return;
			}
		}
	}
}

bool ValidateWeapon(int client, int weapon)
{
	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));

	int index;
	g_aWeaponIDs.GetValue(classname, index);

	if( !g_bLeft4Dead2 )
	{
		g_bUsePills[client] = index == 12;
	}

	if( index != 0 && g_aRestrict.FindValue(index) == -1 )
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		return true;
	}

	return false;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client )
	{
		delete g_hTimers[client];
		g_bUsePills[client] = false;

		SDKUnhook(client, SDKHook_PreThink, OnThinkPre);
		SDKUnhook(client, SDKHook_PostThinkPost, OnThinkPost);
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && GetClientTeam(client) == 2 )
	{
		delete g_hTimers[client];
		g_bUsePills[client] = false;

		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}

		if( g_bLeft4DHooks )
		{
			AnimHookDisable(client, OnAnimPre);
		}

		SDKUnhook(client, SDKHook_PreThink, OnThinkPre);
		SDKUnhook(client, SDKHook_PostThinkPost, OnThinkPost);
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
	}
}

void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client && GetClientTeam(client) == 2 )
	{
		delete g_hTimers[client];
		g_bUsePills[client] = false;

		if( g_bLeft4Dead2 && g_iCvarPist == 0 && g_iCvarMelee == 0 )
		{
			MeleeDamageBlock(true);
		}

		if( g_bLeft4DHooks )
		{
			AnimHookDisable(client, OnAnimPre);
		}

		SDKUnhook(client, SDKHook_PreThink, OnThinkPre);
		SDKUnhook(client, SDKHook_PostThinkPost, OnThinkPost);
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();

	if( g_bLeft4Dead2 )
		MeleeDamageBlock(false);
}

void ResetPlugin()
{
	g_bBlockChange = false;

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			if( g_bLeft4DHooks )
			{
				AnimHookDisable(i, OnAnimPre);
			}

			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, CanSwitchTo);
		}
	}
}



// ====================================================================================================
//					DAMAGE HOOKS
// ====================================================================================================
// Hook players OnTakeDamage if someone is incapped - to block melee weapon damage to survivors
void MeleeDamageBlock(bool enable)
{
	bool incapped;

	// Check someone is incapped
	if( enable )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1) == 0 )
			{
				incapped = true;
				break;
			}
		}
	}

	// Unhook and enable if required and someone incapped
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			SDKUnhook(i, SDKHook_OnTakeDamageAlive, OnTakeDamage);

			if( enable && incapped && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamage);
		}
	}
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if( victim > 0 && victim <= MaxClients && attacker > 0 && attacker <= MaxClients && inflictor > MaxClients && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 2 && GetEntProp(attacker, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(attacker, Prop_Send, "m_isHangingFromLedge", 1) == 0 )
	{
		if( IsValidEntity(inflictor) )
		{
			static char classname[16];
			GetEdictClassname(inflictor, classname, sizeof(classname));

			if( strcmp(classname[7], "melee") == 0 )
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					RESTRICT
// ====================================================================================================
// Restrict certain weapons
Action CanSwitchTo(int client, int weapon)
{
	// This causes the animation to sometimes partially skip on L4D1 and doesn't seem to have any effect on L4D2, so removing.
	// if( g_hTimers[client] ) return Plugin_Handled; // Block while using Pills/Adrenaline

	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));

	int index;
	g_aWeaponIDs.GetValue(classname, index);

	if( !g_bLeft4Dead2 )
	{
		g_bUsePills[client] = index == 12;
	}

	if( index == 0 || g_aRestrict.FindValue(index) != -1 )
		return Plugin_Handled;
	return Plugin_Continue;
}



// ====================================================================================================
//					THINK - can use pills/adrenaline
// ====================================================================================================
void OnThinkPre(int client)
{
	g_bBlockChange = true;
	g_hCvarhealthThresh.IntValue = 9999;

	if( g_bUsePills[client] )
	{
		if( GetClientButtons(client) & IN_ATTACK )
		{
			g_bUsePills[client] = false;
			HealSetup(client, true);
		}
	}
}

void OnThinkPost(int client)
{
	g_hCvarhealthThresh.IntValue = g_iCvarhealthThresh;
	g_bBlockChange = false;
}



// ====================================================================================================
//					ANIMATION HOOK
// ====================================================================================================
// Uses "Activity" numbers, which means 1 animation number is the same for all Survivors.
// Detect pills/adrenaline use to heal players and detect grenade throwing
Action OnAnimPre(int client, int &anim)
{
	if( g_bLeft4Dead2 )
	{
		switch( anim )
		{
			// "ACT_TERROR_USE_PILLS" "552"
			case 552:
			{
				if( g_iCvarHealPills )
				{
					HealSetup(client, true);
				}
			}

			// "ACT_TERROR_USE_ADRENALINE" "553"
			case 553:
			{
				if( g_iCvarHealAdren )
				{
					HealSetup(client, false);
				}
			}

			// case L4D2_ACT_PRIMARYATTACK_GREN1_IDLE, L4D2_ACT_PRIMARYATTACK_GREN2_IDLE:
			case 997, 998:
			{
				// anim = L4D2_ACT_IDLE_INCAP_PISTOL;
				if( !g_bCvarThrow )
				{
					anim = 700;
					return Plugin_Changed;
				}
			}
		}
	}
	else
	{
		switch( anim )
		{
			/* Does not work in L4D1
			// "ACT_TERROR_USE_PILLS" "1088"
			case 1088:
			{
				if( g_iCvarHealPills )
				{
					HealSetup(client, true);
				}
			}
			// */

			// case L4D1_ACT_PRIMARYATTACK_GREN1_IDLE, L4D1_ACT_PRIMARYATTACK_GREN2_IDLE:
			case 1510, 1511:
			{
				// anim = L4D1_ACT_IDLE_INCAP_PISTOL;
				if( !g_bCvarThrow )
				{
					anim = 1201;
					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					HEAL
// ====================================================================================================
// Heal player with pills/adrenaline
void HealSetup(int client, bool pills)
{
	// Timeout to prevent spamming and fast animation
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if( weapon != 1 )
	{
		weapon = EntIndexToEntRef(weapon);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.0);
	}

	// Heal when animation is complete and delete weapon
	DataPack dPack;

	delete g_hTimers[client];

	if( pills )
		g_hTimers[client] = CreateDataTimer(0.5, TimerPills, dPack);
	else
		g_hTimers[client] = CreateDataTimer(0.8, TimerAdren, dPack);

	dPack.WriteCell(GetClientUserId(client));
	dPack.WriteCell(weapon);
}

Action TimerAdren(Handle timer, DataPack dPack)
{
	HealPlayer(dPack, false);
	return Plugin_Continue;
}

Action TimerPills(Handle timer, DataPack dPack)
{
	HealPlayer(dPack, true);
	return Plugin_Continue;
}

void HealPlayer(DataPack dPack, bool pills)
{
	dPack.Reset();

	int userid = dPack.ReadCell();
	int weapon = dPack.ReadCell();

	// Validate client
	int client = GetClientOfUserId(userid);

	g_hTimers[client] = null;

	if( client && IsClientInGame(client) && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) )
	{
		// Delete pills/adrenaline
		if( EntRefToEntIndex(weapon) != INVALID_ENT_REFERENCE )
		{
			RemovePlayerItem(client, weapon);
			RemoveEntity(weapon);
		}

		// Healing
		if( (pills ? g_iCvarHealPills : g_iCvarHealAdren) == -1 )
		{
			// Revive player
			L4D_ReviveSurvivor(client);

			// Revive black and white
			int test = pills ? 0 : 1;
			if( g_iCvarHealRevive & (1 << test) )
			{
				if( g_bHeartbeat )
				{
					Heartbeat_SetRevives(client, g_iCvarMaxIncap);
					if( g_bLeft4Dead2 )
					{
						SetEntProp(client, Prop_Send, "m_currentReviveCount", g_iCvarMaxIncap);
					}
				}
				else
				{
					if( g_bLeft4Dead2 )
						SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1);

					SetEntProp(client, Prop_Send, "m_currentReviveCount", g_iCvarMaxIncap);
					SetEntProp(client, Prop_Send, "m_isGoingToDie", 1);
				}
			}
		}
		else
		{
			// Heal player
			int health = GetClientHealth(client);
			health += (pills ? g_iCvarHealPills : g_iCvarHealAdren);
			if( health > g_iCvarIncapHealth ) health = g_iCvarIncapHealth;
			SetEntityHealth(client, health);
		}

		// Fire event
		if( g_bLeft4Dead2 && pills == false )
		{
			// This fires the event and creates the Adrenaline effects
			L4D2_UseAdrenaline(client, 15.0, false);
		}
		else
		{
			Event hEvent = CreateEvent("pills_used");
			hEvent.SetInt("userid", userid);
			hEvent.Fire();
		}
	}
}



// ====================================================================================================
//					PIPEBOMB EFFECTS
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	if( !g_bGrenadeFix && strcmp(classname, "pipe_bomb_projectile") == 0 )
	{
		RequestFrame(OnFrameSpawn, EntIndexToEntRef(entity));
	}
}

void OnFrameSpawn(int entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if( client > 0 && client <= MaxClients && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1 )
		{
			CreateParticle(entity, 0);
			CreateParticle(entity, 1);
		}
	}
}

void CreateParticle(int target, int type)
{
	int entity = CreateEntityByName("info_particle_system");
	if( type == 0 )	DispatchKeyValue(entity, "effect_name", PARTICLE_FUSE);
	else			DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT);

	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start");

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	if( type == 0 )	SetVariantString("fuse");
	else			SetVariantString("pipebomb_light");
	AcceptEntityInput(entity, "SetParentAttachment", target);
}

void PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	if( FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}



// ====================================================================================================
//					PATCH
// ====================================================================================================
void PatchAddress(int patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;

		int len = g_ByteSaved_Deploy.Length;
		for( int i = 0; i < len; i++ )
		{
			if( len == 1 )
				StoreToAddress(g_Address_Deploy + view_as<Address>(i), 0x78, NumberType_Int8); // 0x75 JNZ (jump short if non zero) to 0x78 JS (jump short if sign) - always jump
			else
				StoreToAddress(g_Address_Deploy + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;

		int len = g_ByteSaved_Deploy.Length;
		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address_Deploy + view_as<Address>(i), g_ByteSaved_Deploy.Get(i), NumberType_Int8);
		}
	}
}

void PatchMelee(int patch)
{
	if( !g_bLeft4Dead2 ) return;

	static bool patched;

	if( !patched && patch )
	{
		patched = true;

		int len = g_ByteSaved_OnIncap.Length;
		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address_OnIncap + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;

		int len = g_ByteSaved_OnIncap.Length;
		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address_OnIncap + view_as<Address>(i), g_ByteSaved_OnIncap.Get(i), NumberType_Int8);
		}
	}
}
