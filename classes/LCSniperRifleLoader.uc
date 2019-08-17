class LCSniperRifleLoader expands LCClassLoader;

var Texture ExtraSkins[6]; //4 is pickup skin, 5 is crosshair

replication
{
	reliable if ( Role==ROLE_Authority )
		ExtraSkins;
}

//This allows clients to attempt to load missing resources
function SetSkin( string SkinName, int Idx)
{
	if ( ExtraSkins[Idx] == None )
	{
		SetPropertyText( "Skin", SkinName);
		if ( Skin == None )
			SetPropertyText( "Skin", GetItemName(SkinName));
		if ( Skin != None )
		{
			ExtraSkins[Idx] = Skin;
			Skin = None;
		}
		else
			ExtraSkins[Idx] = Texture( DynamicLoadObject( SkinName, class'Texture'));
	}
}

simulated function InitClassDefaults()
{
	local int i;
	local class<LCSniperRifle> LCSR;
	local ENetRole OldRole;
	
	Super.InitClassDefaults();
	LCSR = class<LCSniperRifle>(LCWeaponClass);
	if ( LCSR != None )
	{
		//Extra loaders
		OldRole = Role;
		Role = ROLE_Authority;
		if ( LCSR == class'LCChamRifle' )
		{
			ExtraSkins[2] = BaseWeaponClass.default.MultiSkins[4];
			ExtraSkins[5] = BaseWeaponClass.default.MultiSkins[7];
			LCSR.default.PickupViewMesh = class'SniperRifle'.default.PickupViewMesh;
			LCSR.default.PlayerViewMesh = class'SniperRifle'.default.PlayerViewMesh;
		}
		else if ( LCSR == class'LCNYACovertSniper' )
		{
			SetSkin( "NYACovertSniper.Rifle.WolfRifle2A0", 0);
			SetSkin( "NYACovertSniper.Rifle.WolfRifle2B0", 1);
			SetSkin( "NYACovertSniper.Crosshair", 5);
		}
		else if ( LCSR == class'LC_AARV17' )
			SetSkin( "AARV17.AlienMesh", 4);
		else if ( LCSR == class'LCMH2Rifle' )
		{
			SetSkin( "MonsterHunt2Gold.Rifle.AA", 0);
			SetSkin( "MonsterHunt2Gold.Rifle.SR", 1);
			SetSkin( "MonsterHunt2Gold.Rifle.Rifle2c", 2);
			SetSkin( "MonsterHunt2Gold.Rifle.Rifle2d", 3);
			SetSkin( "MonsterHunt2Gold.Skins.RifleFloor", 4);
			SetSkin( "MonsterHunt2Gold.Crosshair", 5);
		}
		Role = OldRole;
		
		
		For ( i=0 ; i<4 ; i++ )
			LCSR.default.FirstPersonSkins[i] = ExtraSkins[i];
		if ( ExtraSkins[4] != None )
			LCSR.default.MultiSkins[2] = ExtraSkins[4];
		if ( ExtraSkins[5] != None )
			LCSR.default.Crosshair = ExtraSkins[5];

	}
}

simulated function InitProperties( Weapon W)
{
	local LCSniperRifle SR;
	local int i;
	
	SR = LCSniperRifle(W);
	if ( SR != None )
	{
		For ( i=0 ; i<4 ; i++ )
			SR.FirstPersonSkins[i] = SR.default.FirstPersonSkins[i];
		SR.Crosshair = SR.default.Crosshair;
	}
}
