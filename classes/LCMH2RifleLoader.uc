class LCMH2RifleLoader expands LCClassLoader;

var class<TournamentWeapon> TCL;

replication
{
	reliable if ( Role==ROLE_Authority )
		TCL;
}


simulated event PostNetBeginPlay()
{
	local LCMH2Rifle LCM;

	if ( TCL != none )
	{
		Class'LCMH2Rifle'.default.OrgClass = TCL;
		ForEach AllActors (class'LCMH2Rifle', LCM)
		{
			LCM.OrgClass = TCL;
			LCM.InitGraphics();
		}
	}
}
