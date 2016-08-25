class LCSiegeIGLoader expands LCClassLoader;

var class<TournamentWeapon> TCL;

replication
{
	reliable if ( Role==ROLE_Authority )
		TCL;
}


simulated event PostNetBeginPlay()
{
	local LCSiegeInstaGibRifle LCM;

	if ( TCL != none )
	{
		Class'LCSiegeInstaGibRifle'.default.OrgClass = TCL;
		ForEach AllActors (class'LCSiegeInstaGibRifle', LCM)
		{
			LCM.OrgClass = TCL;
			LCM.InitGraphics();
		}
	}
}
