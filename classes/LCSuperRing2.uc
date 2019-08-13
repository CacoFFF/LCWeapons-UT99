class LCSuperRing2 expands FV_RingExplosion5;


simulated function SpawnEffects()
{
}

simulated function SpawnExtraEffects()
{
	Spawn(class'SuperShockExplo').RemoteRole = ROLE_None;
	Spawn(class'EnergyImpact');
	if ( Level.bHighDetailMode && !Level.bDropDetail )
		Spawn(class'ut_superring').RemoteRole = ROLE_None;
	bExtraEffectsSpawned = true;
}


defaultproperties
{
	Mesh=LodMesh'Botpack.UTsRingex'
}
