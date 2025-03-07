# smwhitelist

this was created because serverwhitelistadvanced checks steam groups & ids very late. sometimes it never checks so players can join even though they're not in a whitelist group. great plugin.

this uses the connect extension (or PTaH on CS:GO) & also caches steamids from steam groups so we can check before the client actually joins the game and before the OnClientAuthorized forward triggers

## to use
create sourcemod/configs/whitelist.txt & fill it with steamids, ips, and group ids (an example exists at `addons/sourcemod/configs/whitelist.txt`)

you need
- SteamWorks https://github.com/KyleSanderson/SteamWorks/releases (link to [linux latest](https://github.com/KyleSanderson/SteamWorks/releases/download/1.2.3c/package-lin.tgz))
	- Windows builds: https://users.alliedmods.net/~kyles/builds/SteamWorks/ (link to [latest](https://users.alliedmods.net/~kyles/builds/SteamWorks/SteamWorks-git132-windows.zip))

- CS:GO:
	- PTaH
		- https://github.com/komashchenko/PTaH
		- https://ptah.zizt.ru/
- CS:S
	- the [connect](https://github.com/asherkin/connect) extension (binaries are included in the release zip)
		- the gamedata file is also copied to `gamedata/custom/connect.games.txt` because the extension's gamedata autoupdater is out of date lol
