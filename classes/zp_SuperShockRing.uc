//================================================================================
// zp_SuperShockRing.
//================================================================================
class zp_SuperShockRing expands UT_Superring2;

simulated function SpawnExtraEffects ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
	{
		Super.SpawnExtraEffects();
	}
}

defaultproperties
{
    bOwnerNoSee=True
}
