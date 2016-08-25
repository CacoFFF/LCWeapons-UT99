class FV_LCAdaptiveBeam expands FV_AdaptiveBeam;

simulated function Timer ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
		Super.Timer();
}

defaultproperties
{
    bOwnerNoSee=True
}
