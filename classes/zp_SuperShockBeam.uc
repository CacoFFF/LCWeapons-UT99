//================================================================================
// zp_SuperShockBeam.
//================================================================================
class zp_SuperShockBeam expands supershockbeam;

simulated function Timer ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
	{
		Super.Timer();
	}
}

defaultproperties
{
    bOwnerNoSee=True
}
