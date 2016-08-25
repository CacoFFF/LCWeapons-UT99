class LCImpactMark extends ImpactMark;

simulated function SpawnEffects ()
{
	if ( (Owner == None) || (Owner.Role != 3) )
		Super.SpawnEffects();
}

defaultproperties
{
    bOwnerNoSee=True
}
