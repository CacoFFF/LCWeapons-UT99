class LCShockRifleLoader expands LCClassLoader;

var class<Effects> BeamPrototype; //Set in weapon
var class<Effects> ExplosionPrototype; //Not set in weapon

replication
{
	reliable if ( Role==ROLE_Authority )
		BeamPrototype;
}

function LoadBeam( string BeamName)
{
	SetPropertyText( "BeamPrototype", GetItemName(BeamName));
	if ( BeamPrototype == None )
		BeamPrototype = class<Effects>( DynamicLoadObject( BeamName, class'Class'));
}

function LoadExplosion( string ExplName)
{
	SetPropertyText( "ExplosionPrototype", GetItemName(ExplName));
	if ( ExplosionPrototype == None )
		ExplosionPrototype = class<Effects>( DynamicLoadObject( ExplName, class'Class'));
}

function Setup( class<Weapon> InBase, class<Weapon> InLC)
{
	if ( InLC == class'LCAdvancedShockRifle' )
	{
		LoadBeam( "AWM_Beta1.sunbeam");
		LoadExplosion( "AWM_Beta1.SunExplo");
		class'LCSunExplo'.default.Texture = ExplosionPrototype.default.Texture;
	}
	Super.Setup( InBase, InLC);
}

simulated function InitClassDefaults()
{
	local class<ShockRifle> SR;
	local class<LCShockRifle> LCSR;
	
	Super.InitClassDefaults();
	SR   = class<ShockRifle>(BaseWeaponClass);
	LCSR = class<LCShockRifle>(LCWeaponClass);
	if ( LCSR != None )
	{
		LCSR.default.BeamPrototype = BeamPrototype;
		if ( SR != None )
			LCSR.default.HitDamage      = SR.default.HitDamage;
	}
}

simulated function InitProperties( Weapon W)
{
	local LCShockRifle SR;

	SR = LCShockRifle(W);
	if ( SR != None )
	{
		SR.HitDamage      = SR.default.HitDamage;
		SR.BeamPrototype  = SR.default.BeamPrototype;
	}
}
