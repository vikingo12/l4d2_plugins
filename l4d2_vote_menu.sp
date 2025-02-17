#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote> // https://github.com/fdxx/l4d2_nativevote
#include <multicolors>

#define VERSION "0.1"

bool g_bAdminImmunity;

public Plugin myinfo = 
{
	name = "L4D2 Vote menu",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_vote_menu_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	g_bAdminImmunity = CreateConVar("l4d2_vote_menu_kick_immunity", "1", "管理员免疫被踢", FCVAR_NONE).BoolValue;

	RegConsoleCmd("sm_v", Cmd_Vote);
	RegConsoleCmd("sm_votes", Cmd_Vote);
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	if (!CommandExists("sm_vote"))
		RegConsoleCmd("sm_vote", Cmd_Vote);
	else LogMessage("sm_vote 命令已存在，跳过");
}

Action Cmd_Vote(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		Menu menu = new Menu(Category_MenuHandler);
		menu.SetTitle("选择投票类型:");
		if (GetClientTeam(client) != 1)
		{
			menu.AddItem("ReHealth", "所有人回血");
			menu.AddItem("KickPlayer", "踢出玩家");
		}
		menu.AddItem("ForceSpec", "强制玩家旁观");
		menu.Display(client, 20);
	}

	return Plugin_Handled;
}

int Category_MenuHandler(Menu hCategoryMenu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[64];
			hCategoryMenu.GetItem(itemNum, sInfo, sizeof(sInfo));

			switch (sInfo[0])
			{
				case 'R': 
				{
					if (!L4D2NativeVote_IsAllowNewVote())
					{
						CPrintToChat(client, "{default}[{yellow}提示{default}] 投票正在进行中，暂不能发起新的投票");
						return 0;
					}
					
					L4D2NativeVote vote = L4D2NativeVote(ReHealth_VoteHandler);
					vote.SetDisplayText("所有人回血 ?");
					vote.Initiator = client;

					int iPlayerCount = 0;
					int[] iClients = new int[MaxClients];

					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsFakeClient(i))
						{
							if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
							{
								iClients[iPlayerCount++] = i;
							}
						}
					}

					if (!vote.DisplayVote(iClients, iPlayerCount, 20))
						LogError("发起投票失败");
				}

				case 'K':
				{
					char sName[128], sUserid[16];
					Menu menu = new Menu(KickPlayer_MenuHandler);
					menu.SetTitle("踢出玩家:");
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsFakeClient(i))
						{
							if (g_bAdminImmunity && IsAdminClient(i))
								continue;
							FormatEx(sName, sizeof(sName), "%N", i);
							FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
							menu.AddItem(sUserid, sName);
						}
					}
					menu.ExitBackButton = true;
					menu.Display(client, 20);
				}

				case 'F':
				{
					char sName[128], sUserid[16];
					Menu menu = new Menu(ForceSpec_MenuHandler);
					menu.SetTitle("强制玩家旁观:");
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 1)
						{
							FormatEx(sName, sizeof(sName), "%N", i);
							FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
							menu.AddItem(sUserid, sName);
						}
					}
					menu.ExitBackButton = true;
					menu.Display(client, 20);
				}
			}
		}
		case MenuAction_End:
		{
			delete hCategoryMenu;
		}
	}
	return 0;
}

void ReHealth_VoteHandler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}发起了一个投票", param1);
		}
		case VoteAction_PlayerVoted:
		{
			CPrintToChatAll("{olive}%N {default}已投票", param1);
		}
		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("加载中...");

				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && IsPlayerAlive(i))
					{
						if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
						{
							CheatCommand(i, "give", "health");
						}
					}
				}
			}
			else vote.SetFail();
		}
	}
}

int KickPlayer_MenuHandler(Menu hKickMenu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sUserid[16];
			hKickMenu.GetItem(itemNum, sUserid, sizeof(sUserid));
			int userid = StringToInt(sUserid);
			int iTarget = GetClientOfUserId(userid);

			if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && !IsFakeClient(iTarget))
			{
				if (!L4D2NativeVote_IsAllowNewVote())
				{
					CPrintToChat(client, "{default}[{yellow}提示{default}] 投票正在进行中，暂不能发起新的投票");
					return 0;
				}
				
				L4D2NativeVote vote = L4D2NativeVote(KickPlayer_VoteHandler);
				vote.SetDisplayText("踢出玩家: %N ?", iTarget);
				vote.Initiator = client;
				vote.Value = userid;

				int iPlayerCount = 0;
				int[] iClients = new int[MaxClients];

				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i))
					{
						iClients[iPlayerCount++] = i;
					}
				}

				if (!vote.DisplayVote(iClients, iPlayerCount, 20))
					LogError("发起投票失败");
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				Cmd_Vote(client, 0);
		}
		case MenuAction_End:
		{
			delete hKickMenu;
		}
	}
	return 0;
}

void KickPlayer_VoteHandler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}发起了一个投票", param1);
		}
		case VoteAction_PlayerVoted:
		{
			CPrintToChatAll("{olive}%N {default}已投票", param1);
		}
		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("加载中...");

				int iTarget = GetClientOfUserId(vote.Value);
				if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && !IsFakeClient(iTarget) && !IsClientInKickQueue(iTarget))
				{
					KickClient(iTarget, "你已被投票踢出");
				}
			}
			else vote.SetFail();
		}
	}
}

int ForceSpec_MenuHandler(Menu hForceSpecMenu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sUserid[16];
			hForceSpecMenu.GetItem(itemNum, sUserid, sizeof(sUserid));
			int userid = StringToInt(sUserid);
			int iTarget = GetClientOfUserId(userid);

			if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && !IsFakeClient(iTarget) && GetClientTeam(iTarget) != 1)
			{
				if (!L4D2NativeVote_IsAllowNewVote())
				{
					CPrintToChat(client, "{default}[{yellow}提示{default}] 投票正在进行中，暂不能发起新的投票");
					return 0;
				}
				
				L4D2NativeVote vote = L4D2NativeVote(ForceSpec_VoteHandler);
				vote.SetDisplayText("强制玩家旁观: %N ?", iTarget);
				vote.Initiator = client;
				vote.Value = userid;

				int iPlayerCount = 0;
				int[] iClients = new int[MaxClients];

				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i))
					{
						iClients[iPlayerCount++] = i;
					}
				}

				if (!vote.DisplayVote(iClients, iPlayerCount, 20))
					LogError("发起投票失败");
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				Cmd_Vote(client, 0);
		}
		case MenuAction_End:
		{
			delete hForceSpecMenu;
		}
	}
	return 0;
}

void ForceSpec_VoteHandler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}发起了一个投票", param1);
		}
		case VoteAction_PlayerVoted:
		{
			CPrintToChatAll("{olive}%N {default}已投票", param1);
		}
		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("加载中...");
				
				int iTarget = GetClientOfUserId(vote.Value);
				if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && !IsFakeClient(iTarget) && GetClientTeam(iTarget) != 1)
				{
					ChangeClientTeam(iTarget, 1);
					CPrintToChat(iTarget, "{default}[{yellow}提示{default}] 你已被投票强制旁观");
				}
			}
			else vote.SetFail();
		}
	}
}

void CheatCommand(int client, const char[] command, const char[] args = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, args);
	SetCommandFlags(command, iFlags);
}

bool IsAdminClient(int client)
{
	int iFlags = GetUserFlagBits(client);
	if (iFlags != 0 && (iFlags & ADMFLAG_ROOT)) 
	{
		return true;
	}
	return false;
}
