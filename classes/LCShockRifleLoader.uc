class LCShockRifleLoader expands LCClassLoader;

var class<Effects> BeamPrototype; //Set in weapon
var class<Effects> ExplosionPrototype; //Not set in weapon

replication
{
	reliable if ( Role==ROLE_Authority )
		BeamPrototype, ExplosionPrototype;
}

//This allows clients to attempt to load missing resources
function LoadBeam( string BeamName)
{
	if ( BeamPrototype == None )
		SetPropertyText( "BeamPrototype", BeamName);
	if ( BeamPrototype == None )
		SetPropertyText( "BeamPrototype", GetItemName(BeamName));
	if ( BeamPrototype == None )
		BeamPrototype = class<Effects>( DynamicLoadObject( BeamName, class'Class'));
}
function LoadExplosion( string ExplName)
{
	if ( ExplosionPrototype == None )
		SetPropertyText( "ExplosionPrototype", ExplName);
	if ( ExplosionPrototype == None )
		SetPropertyText( "ExplosionPrototype", GetItemName(ExplName));
	if ( ExplosionPrototype == None )
		ExplosionPrototype = class<Effects>( DynamicLoadObject( ExplName, class'Class'));
}

simulated function InitClassDefaults()
{
	local class<ShockRifle> SR;
	local class<LCShockRifle> LCSR;
	local ENetRole OldRole;
	
	Super.InitClassDefaults();
	SR   = class<ShockRifle>(BaseWeaponClass);
	LCSR = class<LCShockRifle>(LCWeaponClass);
	if ( LCSR != None )
	{
		//Extra loaders
		OldRole = Role;
		Role = ROLE_Authority;
		if ( LCSR == class'LCAdvancedShockRifle' )
		{
			LoadBeam( "AWM_Beta1.sunbeam");
			LoadExplosion( "AWM_Beta1.SunExplo");
			class'LCSunExplo'.default.Texture = ExplosionPrototype.default.Texture;
		}
		else if ( LCSR == class'LCBP_ShockRifle' )
			LoadBeam( "BPSE.BP_ShockBeam");
		Role = OldRole;
	
	
		LCSR.default.BeamPrototype = BeamPrototype;
		if ( SR != None )
			LCSR.default.HitDamage = SR.default.HitDamage;
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
