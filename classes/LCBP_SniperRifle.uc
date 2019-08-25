class LCBP_SniperRifle expands LCSniperRifle;

simulated function ProcessTraceHit( Actor Other, vector HitLocation, vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_SpriteBallExplosion e;

	Super.ProcessTraceHit( Other, HitLocation, HitNormal, X, Y, Z);
	if ( (Other != Level) && (Other != Self) && (Other != Owner) && (Other != None) )
	{
		if ( Other.bIsPawn 
		&& (CanHeadshot(Instigator) || CanHeadshot(Pawn(Owner))) 
		&& (HitLocation.Z - Other.Location.Z > HeadshotHeight(Pawn(Other))) )
		{
		}
		else
		{
			HurtRadius( 15, 120.0, MyDamageType, 60000, HitLocation + HitNormal * 9);
			e = spawn(class'FV_SpriteBallExplosion', Owner, , HitLocation + HitNormal * 9);
			e.DrawScale /= 3.0;
			class'LCStatics'.static.SetHiddenEffect( e, Owner, LCChan);
		}
	}
}

defaultproperties
{
	FireAnimRate=3.0
}
