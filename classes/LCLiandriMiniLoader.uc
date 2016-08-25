class LCLiandriMiniLoader expands LCClassLoader;

var class<TournamentWeapon> TCL;

replication
{
	reliable if ( Role==ROLE_Authority )
		TCL;
}


simulated event PostNetBeginPlay()
{
	local LCLiandriMinigun LCM;

	if ( TCL != none )
	{
		Class'LCLiandriMinigun'.default.OrgClass = TCL;
		ForEach AllActors (class'LCLiandriMinigun', LCM)
		{
			LCM.OrgClass = TCL;
			LCM.InitGraphics();
		}
	}
}
