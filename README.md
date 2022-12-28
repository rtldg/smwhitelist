# smwhitelist

this was created because serverwhitelistadvanced checks steam groups & ids very late. sometimes it never checks so players can join even though they're not in a whitelist group. great plugin.

this uses the connect extension & also caches steamids from steam groups so we can check before the client actually joins the game and before the OnClientAuthorized forward triggers

## to use
create sourcemod/configs/whitelist.txt & fill it with steamids, ips, and group ids

you need
- SteamWorks https://github.com/KyleSanderson/SteamWorks/releases
  - Windows builds: https://users.alliedmods.net/~kyles/builds/SteamWorks/

- CS:GO:
	- PTaH
		- https://github.com/komashchenko/PTaH
		- https://ptah.zizt.ru/
- CS:S
	- the connect extension (already in repo)
		- https://forums.alliedmods.net/showthread.php?t=162489&page=36#351
		- for css rename this to `connect.ext.2.css.so`/`connect.ext.2.css.dll`
