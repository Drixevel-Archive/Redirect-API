//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>

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
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("redirectapi.phrases");
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
	
	PushMenuCell(menu, "size", size1);
	PushMenuString(menu, "ip", sIP);
	
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
			
			int size = GetMenuCell(menu, "size");

			char[] sIP = new char[size + 1];
			GetMenuString(menu, "ip", sIP, size + 1);

			ClientCommand(param1, "redirect %s", sIP);
		}
		case MenuAction_End:
			delete menu;
	}
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