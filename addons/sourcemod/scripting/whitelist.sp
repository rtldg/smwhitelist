// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2021-2022 rtldg <rtldg@protonmail.com>

#define FOR_CSGO 1

// Added this because I'd occasionally get errors when SteamWorks tries
// to push the response string...
#pragma dynamic 69696
// from:
//   Stack/heap size:      16384 bytes
//   Total requirements:   41884 bytes
// to:
//   Stack/heap size:     278784 bytes
//   Total requirements:  304284 bytes
// .... that should be good enough ....
/*
L 10/04/2022 - 15:20:16: [SM] Exception reported: Not enough space on the heap
L 10/04/2022 - 15:20:16: [SM] Blaming: whitelist.smx
L 10/04/2022 - 15:20:16: [SM] Call stack trace:
L 10/04/2022 - 15:20:16: [SM]   [0] SteamWorks_GetHTTPResponseBodyCallback
L 10/04/2022 - 15:20:16: [SM]   [1] Line 156, .\whitelist.sp::RequestCompletedCallback
*/

#include <sourcemod>

#include <sourcemod>

#include <convar_class>

#define REQUIRE_EXTENSIONS
#if FOR_CSGO
#include <PTaH>
#else
#include <connect>
#endif
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

Convar gCV_Enabled = null;
Convar gCV_AllowAdmins = null;
Convar gCV_KickMessage = null;
ConVar sv_password = null;

StringMap gSM_WhitelistedGroups = null;
StringMap gSM_WhitelistedSteamIDs = null;
StringMap gSM_WhitelistedIPs = null;

bool gB_WhitelistCached = false;

#if FOR_CSGO
int gI_MapsChanged = 0;
#endif

public Plugin myinfo =
{
	name = "generic whitelist",
	author = "rtldg",
	description = "A generic whitelist plugin.",
	version = "1.1.2",
	url = "https://github.com/rtldg/smwhitelist"
}

#if FOR_CSGO
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gI_MapsChanged = late ? 1 : 0;
	return APLRes_Success;
}
#endif

public void OnPluginStart()
{
	RegAdminCmd("sm_wlreload", Command_ReloadWhitelist, ADMFLAG_KICK, "desc");
	RegAdminCmd("sm_wlrefresh", Command_ReloadWhitelist, ADMFLAG_KICK, "desc");
	RegAdminCmd("sm_reloadwl", Command_ReloadWhitelist, ADMFLAG_KICK, "desc");
	RegAdminCmd("sm_refreshwl", Command_ReloadWhitelist, ADMFLAG_KICK, "desc");
	RegAdminCmd("sm_reloadwhitelist", Command_ReloadWhitelist, ADMFLAG_KICK, "desc");
	RegAdminCmd("sm_refreshwhitelist", Command_ReloadWhitelist, ADMFLAG_KICK, "desc");

	RegAdminCmd("sm_whitelistexists", Command_WhitelistExists, ADMFLAG_KICK, "desc");
	RegAdminCmd("sm_wlexists", Command_WhitelistExists, ADMFLAG_KICK, "desc");

	RegAdminCmd("sm_wladd", Command_WhitelistAdd, ADMFLAG_ROOT, "desc");
	RegAdminCmd("sm_whitelistadd", Command_WhitelistAdd, ADMFLAG_ROOT, "desc");
	RegAdminCmd("sm_wldel", Command_WhitelistDelete, ADMFLAG_ROOT, "desc");
	RegAdminCmd("sm_whitelistdel", Command_WhitelistDelete, ADMFLAG_ROOT, "desc");

	gCV_Enabled = new Convar("whitelist_enabled", "1", "Turn on or off the whitelist", 0, true, 0.0, true, 1.0);
	gCV_AllowAdmins = new Convar("whitelist_allow_admins", "1", "Whether admins (with the ban flag) are allowed to join.", 0, true, 0.0, true, 1.0);
	gCV_KickMessage = new Convar("whitelist_kick_message", "You are not in the server's whitelist", "The kick-message used.");

	Convar.AutoExecConfig();

#if FOR_CSGO
	PTaH(PTaH_ClientConnectPre, Hook, ONCLIENTCONNECTPREFUCK);
#endif

	sv_password = FindConVar("sv_password");

	CreateTimer(2.5 * 60.0, Timer_ReloadWhitelist, 0, TIMER_REPEAT);

	ReloadWhitelistFile(!FOR_CSGO);
}

#if FOR_CSGO
public void OnMapStart()
{
	// CS:GO does a dumb double-map-reload thing on server-start...
	// steamworks requests fail before this point?
	if (++gI_MapsChanged >= 2)
		ReloadWhitelistFile();
}
#endif

public Action Timer_ReloadWhitelist(Handle timer, any data)
{
	ReloadWhitelistFile();
	return Plugin_Continue;
}

void AddAccountIDToWhitelist(int accountid)
{
	char steamid[64];
	//FormatEx(steamid, sizeof(steamid), "STEAM_0:%d:%d", accountid&1, accountid>>1);
	IntToString(accountid, steamid, sizeof(steamid));
	gSM_WhitelistedSteamIDs.SetValue(steamid, true);
}

stock int SteamID64ToAccountID(const char[] steamid64)
{
#if FOR_CSGO
	int num[2];
	StringToInt64(steamid64, num);
#else
	static KeyValues kv = null;

	if (kv == null)
		kv = new KeyValues("fuck sourcemod");

	int num[2];
	kv.SetString(NULL_STRING, steamid64);
	kv.GetUInt64(NULL_STRING, num);
#endif
	return num[0];
}

stock void AccountIDToSteamID2(int accountid, char[] buf, int buflen)
{
	FormatEx(buf, buflen, "STEAM_0:%d:%d", accountid&1, (accountid>>1) & 0x7FFFFFFF);
}

// Retrieves accountid from STEAM_X:Y:Z, [U:1:123], and 765xxxxxxxxxxxxxx
stock int SteamIDToAccountID(const char[] sInput)
{
	char sSteamID[32];
	strcopy(sSteamID, sizeof(sSteamID), sInput);
	ReplaceString(sSteamID, 32, "\"", "");
	TrimString(sSteamID);

	if (StrContains(sSteamID, "STEAM_") != -1)
	{
		ReplaceString(sSteamID, 32, "STEAM_", "");

		char parts[3][11];
		ExplodeString(sSteamID, ":", parts, 3, 11);

		// Let X, Y and Z constants be defined by the SteamID: STEAM_X:Y:Z.
		// Using the formula W=Z*2+Y, a SteamID can be converted:
		return StringToInt(parts[2]) * 2 + StringToInt(parts[1]);
	}
	else if (StrContains(sSteamID, "U:1:") != -1)
	{
		ReplaceString(sSteamID, 32, "[", "");
		ReplaceString(sSteamID, 32, "U:1:", "");
		ReplaceString(sSteamID, 32, "]", "");

		return StringToInt(sSteamID);
	}
	else if (StrContains(sSteamID, "765") == 0)
	{
		return SteamID64ToAccountID(sSteamID);
	}

	return 0;
}

void ResponseBodyCallback(const char[] data, any hRequest)
{
	// I would've loved to use regex instead of this horrible mess but Sourcemod's regex seems to be fucked and only gives me 20 matches in a 55 user group???

	char searchopener[] = "<steamID64>";
	char searchcloser[] = "</steamID64>";

	int total_size = StrContains(data, "</memberList>", true);

	int pos = 0;
	int offset = 0;

	while (pos < total_size && -1 != (offset = StrContains(data[pos], searchopener, true)))
	{
		pos += offset + sizeof(searchopener) - 1;
		int end = pos + FindCharInString(data[pos], '<') + 1;

		char steamid[64]; // funny, right?
		strcopy(steamid, end-pos, data[pos]);
		pos = end + sizeof(searchcloser) - 1;

		AddAccountIDToWhitelist(SteamID64ToAccountID(steamid));
	}
}

public void RequestCompletedCallback(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		LogError("Group XML page request failed.");
		return;
	}

	SteamWorks_GetHTTPResponseBodyCallback(request, ResponseBodyCallback, request);
}

void RequestGroupXml(const char[] url, const char[] groupid)
{
	Handle request;
	if (!(request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url))
	  || !SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, 4000)
	//|| !SteamWorks_SetHTTPRequestRequiresVerifiedCertificate(request, true)
	  || !SteamWorks_SetHTTPCallbacks(request, RequestCompletedCallback)
	  || !SteamWorks_SendHTTPRequest(request)
	)
	{
		CloseHandle(request);
		LogError("Failed to setup group XML request to group '%s'", groupid);
		return;
	}
}

void ReloadWhitelistFile(bool groups=true)
{
	gB_WhitelistCached = false;

	delete gSM_WhitelistedGroups;
	delete gSM_WhitelistedSteamIDs;
	delete gSM_WhitelistedIPs;
	gSM_WhitelistedGroups = new StringMap();
	gSM_WhitelistedSteamIDs = new StringMap();
	gSM_WhitelistedIPs = new StringMap();

	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/whitelist.txt");
	File fWhitelist = OpenFile(sFile, "r");

	if (fWhitelist == null)
	{
		LogError("Failed to open %s", sFile);
		return;
	}

	char buffer[256];

	while (!fWhitelist.EndOfFile() && fWhitelist.ReadLine(buffer, sizeof(buffer)))
	{
		int comment_pos = FindCharInString(buffer, ';');

		if (comment_pos != -1)
			buffer[comment_pos] = 0;

		TrimString(buffer);

		if (strlen(buffer) < 1)
			continue;

		if (FindCharInString(buffer, '.') != -1) // ip
		{
			gSM_WhitelistedIPs.SetValue(buffer, true);
		}
		else if (StrContains(buffer, "STEAM_") == 0 || StrContains(buffer, "[U:") == 0
				|| (StrContains(buffer, "765") == 0) && strlen(buffer) == 17)
		{
			AddAccountIDToWhitelist(SteamIDToAccountID(buffer));
		}
		else if (groups) // should be group id
		{
			if (!IsStrNumbers(buffer))
			{
				PrintToServer("Tried to parse Steam Group ID but value includes a non-number. '%s'", buffer);
				continue;
			}

			// in case someone uses a 64-bit groupid...
			IntToString(SteamID64ToAccountID(buffer), buffer, sizeof(buffer));

			gSM_WhitelistedGroups.SetValue(buffer, true);

			char request_url[256];
			FormatEx(request_url, sizeof(request_url),
				  "https://steamcommunity.com/gid/[g:1:%s]/memberslistxml/?xml=1"
				, buffer
			);

			RequestGroupXml(request_url, buffer);
		}
	}

	gB_WhitelistCached = true;

	delete fWhitelist;
}

public Action Command_WhitelistExists(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Missing argument");
		return Plugin_Handled;
	}

	char buffer[64];
	GetCmdArgString(buffer, sizeof(buffer));
	TrimString(buffer);

	char accountid[32];
	IntToString(SteamIDToAccountID(buffer), accountid, sizeof(accountid));

	bool x;

	if (gSM_WhitelistedIPs.GetValue(buffer, x) || gSM_WhitelistedGroups.GetValue(buffer, x) || gSM_WhitelistedSteamIDs.GetValue(accountid, x))
	{
		ReplyToCommand(client, "'%s' is in the whitelist", buffer);
	}
	else
	{
		ReplyToCommand(client, "'%s' is NOT in the whitelist", buffer);
	}

	return Plugin_Handled;
}

public Action Command_ReloadWhitelist(int client, int args)
{
	ReloadWhitelistFile();
	return Plugin_Handled;
}

void AddThingToWhitelist(int client, const char[] thing)
{
	char client_steamid[32];

	if (client != 0)
	{
		GetClientAuthId(client, AuthId_Steam2, client_steamid, sizeof(client_steamid));
	}

	char datetime[64];
	FormatTime(datetime, sizeof(datetime), "%Y-%m-%d %H:%M:%S");

	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/whitelist.txt");
	File fWhitelist = OpenFile(sFile, "ab");

	if (fWhitelist == null)
	{
		ReplyToCommand(client, "Failed to open %s", sFile);
		return;
	}

	bool success = true;

	if (!fWhitelist.WriteLine("%s ; added by %s on %s", thing, (client != 0) ? client_steamid : "rcon", datetime))
	{
		success = false;
		ReplyToCommand(client, "Failed to write to %s", sFile);
	}

	delete fWhitelist;

	if (success)
	{
		ReloadWhitelistFile();
	}
}

bool IsStrNumbers(const char[] str)
{
	for (int i = 0; str[i] != 0; i++)
		if (!('0' <= str[i] <= '9'))
			return false;
	return true;
}

public Action Command_WhitelistAdd(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Missing argument");
		return Plugin_Handled;
	}

	char type[32];
	char buffer[64];
	GetCmdArgString(buffer, sizeof(buffer));
	TrimString(buffer);

	if (FindCharInString(buffer, '.') != -1) // ip
	{
		char splits[8][8];
		int count = ExplodeString(buffer, ".", splits, 8, 8);

		if (count != 4)
		{
			ReplyToCommand(client, "Invalid IP '%s'", buffer);
			return Plugin_Handled;
		}

		for (int i = 0; i < 4; i++)
		{
			if (!IsStrNumbers(splits[i]) || !(0 <= StringToInt(splits[i]) <= 255))
			{
				ReplyToCommand(client, "Invalid IP '%s'", buffer);
				return Plugin_Handled;
			}
		}

		strcopy(type, sizeof(type), "IP");
	}
	else if (StrContains(buffer, "STEAM_") != -1 || StrContains(buffer, "[U:") != -1)
	{
		int account_id = SteamIDToAccountID(buffer);

		if (account_id == 0)
		{
			ReplyToCommand(client, "Invalid Steam ID '%s'", buffer);
			return Plugin_Handled;
		}

		strcopy(type, sizeof(type), "Steam ID");
	}
	else // should be group id
	{
		if (!IsStrNumbers(buffer))
		{
			ReplyToCommand(client, "Tried to parse Steam Group ID but value includes a non-number. '%s'", buffer);
			return Plugin_Handled;
		}

		strcopy(type, sizeof(type), "Steam Group ID");
	}

	ReplyToCommand(client, "Adding %s '%s' to whitelist", type, buffer);
	AddThingToWhitelist(client, buffer);
	ReloadWhitelistFile();

	return Plugin_Handled;
}

public Action Command_WhitelistDelete(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Missing argument");
		return Plugin_Handled;
	}

	char removethis[32];
	GetCmdArgString(removethis, sizeof(removethis));
	TrimString(removethis);

	if (strlen(removethis) < 1)
	{
		ReplyToCommand(client, "Invalid input");
		return Plugin_Handled;
	}

	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/whitelist.txt");

	char sFileTmp[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFileTmp, sizeof(sFileTmp), "configs/whitelist_tmp.txt");

	File fWhitelist = OpenFile(sFile, "r");

	if (fWhitelist == null)
	{
		ReplyToCommand(client, "Failed to open %s", sFile);
		return Plugin_Handled;
	}

	File fWhitelistTmp = OpenFile(sFileTmp, "w");

	if (fWhitelistTmp == null)
	{
		delete fWhitelist;
		ReplyToCommand(client, "Failed to open %s", sFileTmp);
		return Plugin_Handled;
	}

	char buffer[256];

	while (!fWhitelist.EndOfFile() && fWhitelist.ReadLine(buffer, sizeof(buffer)))
	{
		char trimmed[256];
		trimmed = buffer;

		int comment_pos = FindCharInString(trimmed, ';');

		if (comment_pos != -1)
			trimmed[comment_pos] = 0;

		TrimString(trimmed);

		if (!StrEqual(trimmed, removethis))
		{
			TrimString(buffer);
			fWhitelistTmp.WriteLine(buffer);
		}
	}

	delete fWhitelist;
	delete fWhitelistTmp;

	DeleteFile(sFile);
	RenameFile(sFile, sFileTmp);

	ReplyToCommand(client, "Removed '%s'", removethis);

	return Plugin_Handled;
}

public int SteamWorks_OnValidateClient(int ownerauthid, int authid)
{
	//PrintToServer("SteamWorks_OnValidateClient %d %d", ownerauthid, authid);
}

#if !FOR_CSGO
public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
	int account_id = SteamIDToAccountID(steamID);
	return ONCLIENTCONNECTPREFUCK(account_id, ip, name, password, rejectReason) != Plugin_Stop;
}

public Action ONCLIENTCONNECTPREFUCK(int account_id, const char[] ip, const char[] name, char password[255], char rejectReason[255])
#else
public Action ONCLIENTCONNECTPREFUCK(int account_id, const char[] ip, const char[] name, char password[128], char rejectReason[255])
#endif
{
	//PrintToServer("----------------\nName: %s\nPassword: %s\nIP: %s\nSteamID: %d\n----------------", name, password, ip, account_id);

	if (!gCV_Enabled.BoolValue)
	{
		return Plugin_Continue;
	}

	if (!gB_WhitelistCached)
	{
		strcopy(rejectReason, sizeof(rejectReason), "Whitelist not cached");
		return Plugin_Stop;
	}

	bool asdf;

	if (gSM_WhitelistedIPs.GetValue(ip, asdf))
	{
		PrintToServer("Whitelisted IP");
		return Plugin_Continue;
	}

	char buffer[40];
	IntToString(account_id, buffer, sizeof(buffer));

	if (gSM_WhitelistedSteamIDs.GetValue(buffer, asdf))
	{
		PrintToServer("Whitelisted SteamID");
		return Plugin_Continue;
	}

#if 1
	AccountIDToSteamID2(account_id, buffer, sizeof(buffer));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, buffer);

	if (admin != INVALID_ADMIN_ID)
	{
		if (admin.HasFlag(Admin_Root))
		{
			PrintToServer("Whitelisted by Admin Root Flag");
			sv_password.GetString(password, sizeof(password));
			return Plugin_Changed;
		}

		if (admin.HasFlag(Admin_Ban) && gCV_AllowAdmins.BoolValue)
		{
			PrintToServer("Whitelisted by Admin Ban Flag");
			sv_password.GetString(password, sizeof(password));
			return Plugin_Changed;
		}
	}
#endif

	gCV_KickMessage.GetString(rejectReason, sizeof(rejectReason));
	return Plugin_Stop;
}
