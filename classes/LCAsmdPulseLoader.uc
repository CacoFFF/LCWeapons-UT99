class LCAsmdPulseLoader expands LCClassLoader;

var class<TournamentWeapon> TCL;

replication
{
	reliable if ( Role==ROLE_Authority )
		TCL;
}


simulated event PostNetBeginPlay()
{
	local LCAsmdPulseRifle LCM;

	if ( TCL != none )
	{
		Class'LCAsmdPulseRifle'.default.OrgClass = TCL;
		ForEach AllActors (class'LCAsmdPulseRifle', LCM)
		{
			LCM.OrgClass = TCL;
			LCM.InitGraphics();
		}
	}
}
