// Adaptation of AWM_Beta1's sunlight shock

class LCAdvancedShockRifle expands LCShockRifle;

var bool bGraphicsInitialized;
var native class<ShockRifle> OrgClass;

simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	local int i;
	local ENetRole OldRole;
	
	if ( OrgClass == none )
	{
		OldRole = Role;
		Role = ROLE_Authority;
		SetPropertyText("OrgClass","AdvancedShockRifle"); //Predict
		SetPropertyText("GlobalBeam","sunbeam");
		SetPropertyText("GlobalExplosion","sunexplo");
		Role = OldRole;
		if ( OrgClass == none )
			OrgClass = class<ShockRifle>( DynamicLoadObject("AWM_Beta1.AdvancedShockRifle",class'class') ); //Hardcode!
		if ( GlobalBeam == none )
			GlobalBeam = class<ShockBeam>( DynamicLoadObject("AWM_Beta1.sunbeam",class'class'));
		if ( GlobalExplosion == none )
			GlobalExplosion = class<Effects>( DynamicLoadObject("AWM_Beta1.sunexplo",class'class'));
		if ( OrgClass == none )
		{
			Log("Original class not loaded! (AdvancedShockRifle)");
			return;
		}
		if ( GlobalBeam != none )
			default.GlobalBeam = GlobalBeam;
		if ( GlobalExplosion != none )
			default.GlobalExplosion = GlobalExplosion;
	}
	
	default.bGraphicsInitialized = True;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
	default.PickupMessage = OrgClass.default.PickupMessage;
	PickupMessage = default.PickupMessage;
	default.AltProjectileClass = OrgClass.default.AltProjectileClass;
	AltProjectileClass = default.AltProjectileClass;

	For ( i=0 ; i<3 ; i++ )
	{
		default.MultiSkins[i] = OrgClass.default.MultiSkins[i];
		MultiSkins[i] = default.MultiSkins[i];
	}

	GlobalBeam = default.GlobalBeam;
	GlobalExplosion = default.GlobalExplosion;
	HiddenBeam.default.Texture = GlobalBeam.default.Texture;
	HiddenExplosion.default.Texture = GlobalExplosion.default.Texture;
}


defaultproperties
{
    HiddenBeam=class'LCSunBeam'
    HiddenExplosion=class'LCSunExplo'
    HitDamage=100
    PickupAmmoCount=40
}
