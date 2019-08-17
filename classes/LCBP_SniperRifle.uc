class LCBP_SniperRifle expands LCShockRifle;

simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_SpriteBallExplosion e;

	Super.ProcessTraceHit( Other, HitLocation, HitNormal, X, Y, Z);
	if ( (Other != Level) && (Other != Self) && (Other != Owner) && (Other != None) )
	{
		if (Other.bIsPawn && (HitLocation.Z - Other.Location.Z > 0.62 * Other.CollisionHeight)
			&& (instigator.IsA('PlayerPawn') || (instigator.IsA('Bot') && !Bot(Instigator).bNovice)))
		{
		}
		else
		{
			HurtRadius( 15, 120.0, MyDamageType, 60000, HitLocation + HitNormal * 9);
			e = spawn(class'UT_SpriteBallExplosion', , , HitLocation + HitNormal * 9); //TODO: MAKE LC CLIENT
			e.DrawScale /= 3.0;
		}
	}
}

defaultproperties
{
	FireAnimRate=3.0
}
