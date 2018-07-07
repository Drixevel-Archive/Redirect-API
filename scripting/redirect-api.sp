//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <redirect_api>

//Globals
Handle g_Forward_OnRedirect;
Handle g_Forward_OnRedirect_Post;

public Plugin myinfo = 
{
	name = "Redirect API", 
	author = "Keith Warren (Shaders Allen)", 
	description = "Allows for an easy API for plugins to use for redirects.", 
	version = "1.0.0", 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("redirect-api");
	CreateNative("RedirectPlayer", Native_RedirectPlayer);
	g_Forward_OnRedirect = CreateGlobalForward("OnPlayerRedirect", ET_Event, Param_Cell, Param_String, Param_FloatByRef, Param_String);
	g_Forward_OnRedirect_Post = CreateGlobalForward("OnPlayerRedirect_Post", ET_Ignore, Param_Cell, Param_String, Param_Float, Param_String);
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("redirectapi.phrases");

	RegConsoleCmd("sm_redirect", Command_Redirect, "Redirect to another server based on the IP.");
}

public Action Command_Redirect(int client, int args)
{
	if (client == 0 || args == 0)
		return Plugin_Handled;
	
	char sIP[64];
	GetCmdArgString(sIP, sizeof(sIP));

	RedirectPlayer(client, sIP);

	return Plugin_Handled;
}

public int Native_RedirectPlayer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "%t", "error invalid client");

	float time = GetNativeCell(3);

	if (time < 0.0)
		time = 0.0;

	int size1;
	GetNativeStringLength(2, size1);

	char[] sIP = new char[size1 + 1];
	GetNativeString(2, sIP, size1 + 1);

	if (strlen(sIP) == 0)
		return ThrowNativeError(SP_ERROR_NATIVE, "%t", "error empty ip field");

	int size2;
	GetNativeStringLength(4, size2);

	char[] sPassword = new char[size2 + 1];
	GetNativeString(4, sPassword, size2 + 1);

	PrintToChatAll("%N - %s - %.2f - %s", client, sIP, time, sPassword);

	Call_StartForward(g_Forward_OnRedirect);
	Call_PushCell(client);
	Call_PushStringEx(sIP, size1, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushFloatRef(time);
	Call_PushStringEx(sPassword, size2, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);

	PrintToChatAll("2 %N - %s - %.2f - %s", client, sIP, time, sPassword);
	
	int code; Action result;
	if ((code = Call_Finish(result)) != SP_ERROR_NONE)
	{
		LogError("Error while generating pre-forward on redirect. [Code: %i]", code);
		return 0;
	}

	if (result > Plugin_Changed)
		return 0;

	//If non-TF2, just use the regular function.
	if (GetEngineVersion() != Engine_TF2)
	{
		DisplayAskConnectBox(client, time, sIP, sPassword);
		return 1;
	}

	DataPack pack = new DataPack();
	pack.WriteFloat(time);
	pack.WriteCell(size1);
	pack.WriteString(sIP);
	pack.WriteCell(size2);
	pack.WriteString(sPassword);

	QueryClientConVar(client, "cl_showpluginmessages", QueryClientConVar_ShowPluginMessages, pack);
	return 1;
}

public void QueryClientConVar_ShowPluginMessages(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, DataPack value)
{
	value.Reset();

	float time = value.ReadFloat();

	int size1 = value.ReadCell();

	char[] sIP = new char[size1 + 1];
	value.ReadString(sIP, size1 + 1);

	int size2 = value.ReadCell();

	char[] sPassword = new char[size2 + 1];
	value.ReadString(sPassword, size2 + 1);

	delete value;

	//If they can see the connection box, just use that.
	if (StrEqual(cvarValue, "1"))
	{
		DisplayAskConnectBox(client, time, sIP, sPassword);
		return;
	}

	//Build a panel and use this with the redirect command if they have the plugin messages off.
	Menu menu = new Menu(MenuHandler_AskConnect);
	menu.SetTitle("%T", "redirect box title", client, sIP);
	
	char sDisplay[12];
	
	FormatEx(sDisplay, sizeof(sDisplay), "%T", "yes", client);
	menu.AddItem("Yes", sDisplay);
	
	FormatEx(sDisplay, sizeof(sDisplay), "%T", "no", client);
	menu.AddItem("No", sDisplay);
	
	PushMenuFloat(menu, "time", time);
	PushMenuCell(menu, "size1", size1);
	PushMenuString(menu, "ip", sIP);
	PushMenuCell(menu, "size2", size2);
	PushMenuString(menu, "password", sPassword);
	
	menu.Display(client, RoundFloat(time));
}

public int MenuHandler_AskConnect(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[12];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "No"))
				return;

			float time = GetMenuFloat(menu, "time");
			
			int size1 = GetMenuCell(menu, "size1");

			char[] sIP = new char[size1 + 1];
			GetMenuString(menu, "ip", sIP, size1 + 1);

			int size2 = GetMenuCell(menu, "size2");

			char[] sPassword = new char[size2 + 1];
			GetMenuString(menu, "password", sPassword, size2 + 1);

			Call_StartForward(g_Forward_OnRedirect_Post);
			Call_PushCell(param1);
			Call_PushString(sIP);
			Call_PushFloat(time);
			Call_PushString(sPassword);
			Call_Finish();

			ClientCommand(param1, "redirect %s", sIP);
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action OnPlayerRedirect(int client, char[] ip, float time, char[] password)
{
	//PrintToServer("client: %N - ip: %s - time: %.2f - password: %s", client, ip, time, password);
}

public void OnPlayerRedirect_Post(int client, const char[] ip, float time, const char[] password)
{
	//PrintToServer("client: %N - post-ip: %s - time: %.2f - password: %s", client, ip, time, password);
}

bool PushMenuString(Menu pMenu, const char[] pId, const char[] pValue)
{
	if (pMenu == null || strlen(pId) == 0)
		return false;
	
	return pMenu.AddItem(pId, pValue, ITEMDRAW_IGNORE);
}

bool PushMenuCell(Menu pMenu, const char[] pId, int pValue)
{
	if (pMenu == null || strlen(pId) == 0)
		return false;
	
	char sBuffer[128];
	IntToString(pValue, sBuffer, sizeof(sBuffer));
	return pMenu.AddItem(pId, sBuffer, ITEMDRAW_IGNORE);
}

bool PushMenuFloat(Menu pMenu, const char[] pId, float pValue)
{
	if (pMenu == null || strlen(pId) == 0)
		return false;
	
	char sBuffer[128];
	FloatToString(pValue, sBuffer, sizeof(sBuffer));
	return pMenu.AddItem(pId, sBuffer, ITEMDRAW_IGNORE);
}

bool GetMenuString(Menu pMenu, const char[] pId, char[] pBuffer, int pSize)
{
	if (pMenu == null || strlen(pId) == 0)
		return false;
	
	char info[128]; char data[8192];
	for (int i = 0; i < pMenu.ItemCount; i++)
	{
		if (pMenu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, pId))
		{
			strcopy(pBuffer, pSize, data);
			return true;
		}
	}
	
	return false;
}

int GetMenuCell(Menu pMenu, const char[] pId, int pDefaultValue = 0)
{
	if (pMenu == null || strlen(pId) == 0)
		return pDefaultValue;
	
	char info[128]; char data[128];
	for (int i = 0; i < pMenu.ItemCount; i++)
	{
		if (pMenu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, pId))
			return StringToInt(data);
	}
	
	return pDefaultValue;
}

float GetMenuFloat(Menu pMenu, const char[] pId, float pDefaultValue = 0.0)
{
	if (pMenu == null || strlen(pId) == 0)
		return pDefaultValue;
		
	char info[128]; char data[128];
	for (int i = 0; i < pMenu.ItemCount; i++)
	{
		if (pMenu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, pId))
			return StringToFloat(data);
	}
	
	return pDefaultValue;
}