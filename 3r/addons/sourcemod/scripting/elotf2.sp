#include <sourcemod>
#include <tf2_stocks>
#define PL_VERSION "1.2"
#pragma semicolon 1
new Handle:g_kValue = INVALID_HANDLE;
new Handle:db = INVALID_HANDLE;
new bool:roundend = false;
new bool:sqlite = false;
new bool:notify[MAXPLAYERS + 1] = { true, ... };
new rankcount;
new rank[MAXPLAYERS + 1];
new rating[MAXPLAYERS + 1];
new kills[MAXPLAYERS + 1];
new deaths[MAXPLAYERS + 1];
new sessionrating[MAXPLAYERS + 1];
new sessionkills[MAXPLAYERS + 1];
new sessiondeaths[MAXPLAYERS + 1];

public Plugin:myinfo = {
	name = "ELO Ranking",
	author = "Mike + R_Hehl + MaddyUnderStars",
	description = "Ranks players using the ELO rating system.",
	version	= PL_VERSION,
	url	= "https://github.com/MaddyUnderStars/tfdb"
};

public OnPluginStart()
{
	decl String:error[256];
	if (SQL_CheckConfig("elo"))
	{
		db = SQL_Connect("elo", true, error, sizeof(error));
	}
	else {
		db = SQL_Connect("storage-local", true, error, sizeof(error));
	}
	if (db == INVALID_HANDLE)
	{
		LogError("Could not connect to database: %s", error);
		return;
	}
	decl String:ident[16];
	SQL_ReadDriver(db, ident, sizeof(ident));
	if (strcmp(ident, "mysql", false) == 0)
	{
		sqlite = false;
	}
	else if (strcmp(ident, "sqlite", false) == 0) {
		sqlite = true;
	}
	else {
		LogError("Invalid database.");
		return;
	}
	if (sqlite)
	{
		SQL_TQuery(db, SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS elostats (steamid TEXT, name TEXT, rating INTEGER, kills INTEGER, deaths INTEGER, notify INTEGER)");
	}
	else {
		SQL_TQuery(db, SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS elostats (steamid varchar(32) NOT NULL, name varchar(64) NOT NULL, rating int(8) NOT NULL, kills int(8) NOT NULL, deaths int(8) NOT NULL, notify int(2) NOT NULL)");
	}
	CreateConVar("sm_elo_version", PL_VERSION, "ELO Ranking version.", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	// RegConsoleCmd("say", Command_say);
	// RegConsoleCmd("say_team", Command_say);
	HookEvent("player_changename", Event_player_changename);
	HookEvent("player_death", Event_player_death);
	HookEvent("arena_round_start", Event_round_start);
	HookEvent("teamplay_restart_round", Event_round_start);
	HookEvent("teamplay_round_start", Event_round_start);
	HookEvent("teamplay_round_win", Event_round_win);

	g_kValue = CreateConVar("sm_elo_k", "16", "K-Value for ELO Ranking.", FCVAR_NOTIFY);

	RegConsoleCmd("sm_elo", Command_show);
	RegConsoleCmd("sm_elo_notify", Command_EloNotify);
	RegConsoleCmd("sm_rank", Command_Rank);
	RegConsoleCmd("sm_session", Command_Session);
	RegConsoleCmd("sm_top10", Command_TopTen);
}

public OnClientPutInServer(client)
{
	if (!IsFakeClient(client))
	{
		decl String:clientid[32],
					  String:query[256];
		new userid = GetClientUserId(client);
		GetClientAuthString(client, clientid, sizeof(clientid));
		Format(query, sizeof(query), "SELECT rating,kills,deaths,notify FROM elostats WHERE steamid='%s'", clientid);
		SQL_TQuery(db, SQLQueryConnect, query, userid);
		sessionrating[client] = 0;
		sessionkills[client]  = 0;
		sessiondeaths[client] = 0;
	}
}

public SQLQueryConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	if (hndl == INVALID_HANDLE)
	{
		LogError("Query failed: %s", error);
	}
	else {
		decl String:query[512], String:clientname[64], String:clientid[32];
		GetClientName(client, clientname, sizeof(clientname));
		ReplaceString(clientname, sizeof(clientname), "'", "");
		GetClientAuthString(client, clientid, sizeof(clientid));
		if (!SQL_MoreRows(hndl))
		{
			if (sqlite)
			{
				Format(query, sizeof(query), "INSERT INTO elostats VALUES('%s', '%s', 1600, 0, 0, 0)", clientid, clientname);
				SQL_TQuery(db, SQLErrorCheckCallback, query);
			}
			else {
				Format(query, sizeof(query), "INSERT INTO elostats (steamid, name, rating, kills, deaths, notify) VALUES ('%s', '%s', 1600, 0, 0, 0)", clientid, clientname);
				SQL_TQuery(db, SQLErrorCheckCallback, query);
			}
			rating[client] = 1600;
			kills[client]  = 0;
			deaths[client] = 0;
			notify[client] = false;
			CreateTimer(15.0, EloWelcome, client);
		}
		else {
			Format(query, sizeof(query), "UPDATE elostats SET name='%s' WHERE steamid='%s'", client, clientname, clientid);
			SQL_TQuery(db, SQLErrorCheckCallback, query);
		}
		while (SQL_FetchRow(hndl))
		{
			rating[client] = SQL_FetchInt(hndl, 0);
			kills[client]  = SQL_FetchInt(hndl, 1);
			deaths[client] = SQL_FetchInt(hndl, 2);
			notify[client] = SQL_FetchInt(hndl, 3) == 0 ? false : true;
		}
	}
}

public SQLQueryRank(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	if (hndl == INVALID_HANDLE)
	{
		LogError("Query failed: %s", error);
	}
	else {
		rank[client] = SQL_GetRowCount(hndl) + 1;
	}
	SQL_TQuery(db, SQLQueryCount, "SELECT * FROM elostats", GetClientUserId(client));
}

public SQLQueryCount(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	rankcount = SQL_GetRowCount(hndl);
	decl String:rankstr[16];
	new Float:kpd = deaths[client] == 0 ? 0.0 : float(kills[client]) / float(deaths[client]);
	if ((rank[client] % 100) > 10 && (rank[client] % 100) < 14)
	{
		Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
	}
	else {
		switch (rank[client] % 10)
		{
			case 0: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
			case 1: Format(rankstr, sizeof(rankstr), "%ist", rank[client]);
			case 2: Format(rankstr, sizeof(rankstr), "%ind", rank[client]);
			case 3: Format(rankstr, sizeof(rankstr), "%ird", rank[client]);
			case 4: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
			case 5: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
			case 6: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
			case 7: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
			case 8: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
			case 9: Format(rankstr, sizeof(rankstr), "%ith", rank[client]);
		}
	}
	decl String:buffer[64];
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "ELO Ranking stats:");
	Format(buffer, sizeof(buffer), "Rating: %i", rating[client]);
	DrawPanelText(panel, buffer);
	Format(buffer, sizeof(buffer), "Rank: %s (of %i)", rankstr, rankcount);
	DrawPanelText(panel, buffer);
	Format(buffer, sizeof(buffer), "KPD: %.2f", kpd);
	DrawPanelText(panel, buffer);
	DrawPanelItem(panel, "Close");
	SendPanelToClient(panel, client, PanelHandlerNothing, 15);
	CloseHandle(panel);
}

public SQLQueryTop10(Handle:owner, Handle:hndl, const String:error[], any: data)
{
	new client;
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	if (hndl == INVALID_HANDLE)
	{
		LogError("Query failed: %s", error);
	}
	else {
		decl String:qname[64], String:qrating[8], String:buffer[68];
		new i = 0;
		new Handle:panel = CreatePanel();
		SetPanelTitle(panel, "Top 10 players:");
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, qname, sizeof(qname));
			SQL_FetchString(hndl, 1, qrating, sizeof(qrating));
			Format(buffer, sizeof(buffer), "%s: %s", qrating, qname);
			DrawPanelText(panel, buffer);
			i++;
		}
		DrawPanelItem(panel, "Close");
		SendPanelToClient(panel, client, PanelHandlerNothing, 15);
		CloseHandle(panel);
	}
}

public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any: data)
{
	if (!StrEqual("", error))
	{
		LogError("Query failed: %s", error);
	}
}

public Action:EloWelcome(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		PrintToChat(client, "\x01This appears to be your first visit. You may say \x04/elo_notify\x01 in chat to enable ranking notifications.");
	}
}

public Action:Event_player_changename(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:clientname[64], String:clientid[32], String:query[512];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetClientName(client, clientname, sizeof(clientname));
	ReplaceString(clientname, sizeof(clientname), "'", "");
	GetClientAuthString(client, clientid, sizeof(clientid));
	Format(query, sizeof(query), "UPDATE elostats SET name='%s' WHERE steamid='%s'", client, clientname, clientid);
	SQL_TQuery(db, SQLErrorCheckCallback, query);
}

public Action:Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!roundend)
	{
		new client	 = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new assister = GetClientOfUserId(GetEventInt(event, "assister"));
		if (client != 0 && attacker != 0)
		{
			if (!IsFakeClient(client) && !IsFakeClient(attacker) && client != attacker)
			{
				decl String:clientid[32], String:attackerid[32], String:query[512], String:buffer[256];
				GetClientAuthString(client, clientid, sizeof(clientid));
				GetClientAuthString(attacker, attackerid, sizeof(attackerid));
				new Float:prob = 1 / (Pow(10.0, float((rating[client] - rating[attacker])) / 400) + 1);
				new diff = RoundFloat(GetConVarFloat(g_kValue) * (1 - prob));
				new diffl = diff;
				if (assister != 0)
				{
					if (_:TF2_GetPlayerClass(assister) == 5 && !IsFakeClient(assister))
					{
						decl String:assisterid[32];
						GetClientAuthString(assister, assisterid, sizeof(assister));
						new diff2		 = RoundToCeil(float(diff) / 3.0);
						diff			 = diff - diff2;
						rating[assister] = rating[assister] + diff2;
						kills[assister]++;
						Format(query, sizeof(query), "UPDATE elostats SET rating=%i,kills=%i WHERE steamid='%s'", rating[assister], kills[assister], assisterid);
						SQL_TQuery(db, SQLErrorCheckCallback, query);
						if (notify[assister])
						{
							Format(buffer, sizeof(buffer), "\x01You (\x04%i\x01) gained \x04%i\x01 points for healing \x03%N\x01.", rating[assister], diff2, attacker);
							SayText2(assister, client, buffer);
						}
					}
				}
				rating[client]			= rating[client] - diffl;
				rating[attacker]		= rating[attacker] + diff;
				sessionrating[client]	= sessionrating[client] - diff;
				sessionrating[attacker] = sessionrating[attacker] + diff;
				kills[attacker]++;
				deaths[client]++;
				sessionkills[attacker]++;
				sessiondeaths[client]++;
				Format(query, sizeof(query), "UPDATE elostats SET rating=%i,deaths=%i WHERE steamid='%s'", rating[client], deaths[client], clientid);
				SQL_TQuery(db, SQLErrorCheckCallback, query);
				Format(query, sizeof(query), "UPDATE elostats SET rating=%i,kills=%i WHERE steamid='%s'", rating[attacker], kills[attacker], attackerid);
				SQL_TQuery(db, SQLErrorCheckCallback, query);
				if (notify[client])
				{
					Format(buffer, sizeof(buffer), "\x01You (\x04%i\x01) were killed by \x03%N\x01 (\x04%i\x01) and lost \x04%i\x01 points.", rating[client], attacker, rating[attacker], diffl);
					SayText2(client, attacker, buffer);
				}
				if (notify[attacker])
				{
					Format(buffer, sizeof(buffer), "\x01You (\x04%i\x01) gained \x04%i\x01 points for killing \x03%N\x01 (\x04%i\x01).", rating[attacker], diff, client, rating[client]);
					SayText2(attacker, client, buffer);
				}
			}
		}
	}
}

public Action:Event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	roundend = false;
}

public Action:Event_round_win(Handle:event, const String:name[], bool:dontBroadcast)
{
	roundend = true;
}

public Action:Command_show(client, args)
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInGame(i))
		{
			PrintToConsole(client, "%N: %i", i, rating[i]);
		}
	}
	return Plugin_Handled;
}

public Action:Command_EloNotify(client, args)
{
	decl String:clientid[32], String:query[512];
	GetClientAuthString(client, clientid, sizeof(clientid));
	if (notify[client] == false)
	{
		notify[client] = true;
		PrintToChat(client, "\x01Rank notifications enabled. Say \x04/elo_notify\x01 again to disable them.");
		Format(query, sizeof(query), "UPDATE elostats SET notify=1 WHERE steamid='%s'", clientid);
		SQL_TQuery(db, SQLErrorCheckCallback, query);
	}
	else {
		notify[client] = false;
		PrintToChat(client, "\x01Rank notifications disabled. Say \x04/elo_notify\x01 again to enable them.");
		Format(query, sizeof(query), "UPDATE elostats SET notify=0 WHERE steamid='%s'", clientid);
		SQL_TQuery(db, SQLErrorCheckCallback, query);
	}
	return Plugin_Handled;
}

public Action:Command_Rank(client, args)
{
	decl String:clientid[32];
	GetClientAuthString(client, clientid, sizeof(clientid));
	decl String:query[512];
	Format(query, sizeof(query), "SELECT * FROM elostats WHERE rating>%i", rating[client]);
	SQL_TQuery(db, SQLQueryRank, query, GetClientUserId(client));
	return Plugin_Handled;
}

public Action:Command_Session(client, args)
{
	decl String:clientid[32];
	GetClientAuthString(client, clientid, sizeof(clientid));
	decl String:buffer[64];
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "Session stats:");
	Format(buffer, sizeof(buffer), "Rating: %i", sessionrating[client]);
	DrawPanelText(panel, buffer);
	Format(buffer, sizeof(buffer), "Kills: %i", sessionkills[client]);
	DrawPanelText(panel, buffer);
	Format(buffer, sizeof(buffer), "Deaths: %i", sessiondeaths[client]);
	DrawPanelText(panel, buffer);
	DrawPanelItem(panel, "Close");
	SendPanelToClient(panel, client, PanelHandlerNothing, 15);
	CloseHandle(panel);
}

public Action:Command_TopTen(client, args)
{
	SQL_TQuery(db, SQLQueryTop10, "SELECT name,rating FROM elostats ORDER BY rating DESC LIMIT 0,10", GetClientUserId(client));
	return Plugin_Handled;
}

public PanelHandlerNothing(Handle:menu, MenuAction:action, param1, param2)
{
	// Do nothing
}
SayText2(client, user, const String:message[])
{
	new Handle:buffer = StartMessageOne("SayText2", client);
	if (buffer != INVALID_HANDLE)
	{
		BfWriteByte(buffer, user);
		BfWriteByte(buffer, true);
		BfWriteString(buffer, message);
		EndMessage();
	}
}