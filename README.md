# smwhitelist

this was created because serverwhitelistadvanced checks steam groups & ids very late. sometimes it never checks so players can join even though they're not in a whitelist group. great extension.

so we cache steamids from steam groups and check steamids before the client actually joins the game & before the client auth forward

## to use
create sourcemod/configs/whitelist.txt & fill it with steamids, ips, and group ids

you need
- SteamWorks https://github.com/KyleSanderson/SteamWorks/releases
- the connect extension
  - https://forums.alliedmods.net/showthread.php?t=162489&page=36#351
  - for css rename this to `connect.ext.2.css.so`/`connect.ext.2.css.dll`
