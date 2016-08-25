//================================================================================
//================================================================================
class LCShockBeam2 expands ShockBeam;

simulated function Timer ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
		Super.Timer();
}

defaultproperties
{
    bOwnerNoSee=True
}
