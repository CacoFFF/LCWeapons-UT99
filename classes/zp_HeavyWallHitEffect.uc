//================================================================================
// zp_HeavyWallHitEffect.
//================================================================================
class zp_HeavyWallHitEffect expands UT_HeavyWallHitEffect;

simulated function SpawnSound ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
		Super.SpawnSound();
}

simulated function SpawnEffects ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
		Super.SpawnEffects();
}

defaultproperties
{
    bOwnerNoSee=True
}
