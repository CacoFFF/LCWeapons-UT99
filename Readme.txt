LCWeapons

LCWeapons is a lightweight and versatile lag compensator for hitscan weapons in Unreal Tournament.
It's weapon replacement system is mod friendly and can adapt many variations of default weapons, making it suitable for custom gametypes and arena mutators.
It can also improve gameplay with other weapons that don't have any kind of lag compensation by displaying elements such as projectiles and enemies in a 'predicted' position.

Weapons that are replaced:
- Impact Hammer
- Enforcer
- Shock Rifle
- Sniper Rifle
- Minigun
- Minigun (Unreal)
- ASMD Pulse Rifle (Siege)

Supported weapon variations:
- Enhanced Shock Rifle
- Sunlight Shock Rifle
- Quick Charge Shock rifle
- Siege Instagib Rifle
- Rainbow Shock Rifle
- Blast Rifle
- MonsterHunt 2 Gold Rifle
- {NYA}Covert Sniper Rifle
- Cham Sniper Rifle
- Alien Assault Rifle v17
- h4x Rifle v3
- Minigun MK-III
- Liandri Minigun

Arena mutators related to any of the weapon above are also supported, simply load them as usual with the LCWeapons mutator as well.
In XC_Engine servers LCWeapons will automatically register itself to the packages the client must receive without modifying the server config, it will also register the package of a supported custom arena mutator.
Additionally, LCWeapons comes with a team-shock mutator that changes colors of normal shock rifles.

=======================
Client commands:

- mutate GetPrediction
** Displays your current prediction cap

- mutate Prediction [MS]
** Sets your client's prediction cap in milliseconds, overriding the server's (-1 resets to default, 0 disables prediction)

- mutate zp_on
- mutate zp_off
** Enables/disables lag compensation code on your client.



=======================
Other notes:

Impact hammer alt fire effect on projectiles is now partially visible on clients.
* Only for projectiles that move in a straight line.

Shock Rifle alt fire visibly displays the shock ball as if it was fully compensated, making combo fire easier and smoother.

In XC_Engine servers data usage is slightly lower due to usage of netcode enhancements.

There's an option in LCWeapons.ini that forces your client to send movement updates at a higher frequency (up to 120hz).
[Client]
bHighFidelityMode=True

This package can only be built on UT v469 (Win32) with XC_Core's script compiler enhancements.

=======================
Made by Fernando Velázquez

caco_fff@hotmail.com
https://github.com/CacoFFF/
https://ut99.org/memberlist.php?mode=viewprofile&u=5945
