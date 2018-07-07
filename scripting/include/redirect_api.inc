#if defined _redirect_api_included
  #endinput
#endif
#define _redirect_api_included

native void RedirectPlayer(int client, char[] ip, float time = 30.0, char[] password = "");
forward Action OnPlayerRedirect(int client, char[] ip, float time, char[] password);
forward void OnPlayerRedirect_Post(int client, const char[] ip, float time, const char[] password);

public SharedPlugin __pl_redirect_api = 
{
	name = "redirect-api",
	file = "redirect-api.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_redirect_api_SetNTVOptional()
{
	MarkNativeAsOptional("RedirectPlayer");
}
#endif