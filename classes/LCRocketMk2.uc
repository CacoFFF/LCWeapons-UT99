//=============================================================================
// LCRocketMk2.
// Non bNetTemporary rocket, because Skarn keeps complaining he sees rockets
// explode and not do damage.
//=============================================================================
class LCRocketMk2 extends RocketMk2;

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	AutonomousPhysics( 0.012); //Ensure this rocket leaves a decal.
}

simulated function HitWall (vector HitNormal, actor Wall)
{
	Super.HitWall( HitNormal, Wall);
	if ( Level.NetMode == NM_Client )
		ExplosionDecal = none;
}


auto state Flying
{
	function Explode(vector HitLocation, vector HitNormal)
	{
		Spawn(class'UT_SpriteBallExplosion',,,HitLocation + HitNormal*16);	
		BlowUp(HitLocation);
 		Destroy();
	}
}



defaultproperties
{
	bNetTemporary=False;
}