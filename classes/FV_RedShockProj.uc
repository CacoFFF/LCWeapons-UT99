class FV_RedShockProj expands ShockProj;

var byte Team;

function Explode(vector HitLocation,vector HitNormal)
{
	PlaySound(ImpactSound, SLOT_Misc, 0.5,,, 0.5+FRand());
	HurtRadius(Damage, 70, MyDamageType, MomentumTransfer, Location );
	if (Damage > 60)
		Spawn(class'ut_RingExplosion3',,, HitLocation+HitNormal*8,rotator(HitNormal)).Skin = class'FVTeamShock'.default.ExploSkin[Team];
	else
		Spawn(class'ut_RingExplosion',,, HitLocation+HitNormal*8,rotator(Velocity)).Skin = class'FVTeamShock'.default.ExploSkin[Team];
	Destroy();
}

function SuperExplosion()
{
	local UT_RingExplosion4 Exp;
	HurtRadius(Damage*3, 250, MyDamageType, MomentumTransfer*2, Location );
	
	Spawn(Class'ut_ComboRing',,'',Location, Instigator.ViewRotation).Skin = class'FVTeamShock'.default.sExploSkin[Team];
	ForEach RadiusActors( class'UT_RingExplosion4', Exp, 2)
		Exp.Skin = class'FVTeamShock'.default.sExploSkin[Team];
	PlaySound(ExploSound,,20.0,,2000,0.6);	
	
	Destroy(); 
}

simulated event Destroyed()
{
	local ShockRiflewave SHW;

	ForEach RadiusActors( class'ShockRiflewave', SHW, 30)
		SHW.Skin = class'FVTeamShock'.default.sExploSkin[Team];

	Super.Destroyed();
}

defaultproperties
{
	Texture=Texture'FV_ColorShock.ASMDAlt_0_a00'
}