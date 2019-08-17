class LCClassLoader expands ReplicationInfo;

var class<Weapon> BaseWeaponClass;
var class<Weapon> LCWeaponClass;
var string BaseWeaponClassString;

replication
{
	reliable if ( Role==ROLE_Authority )
		BaseWeaponClass, LCWeaponClass, BaseWeaponClassString;
}


//Must be done before spawning LC variations in server
function Setup( class<Weapon> InBase, class<Weapon> InLC)
{
	BaseWeaponClass = InBase;
	LCWeaponClass = InLC;
	BaseWeaponClassString = string(InBase);
	InitClassDefaults();
}

//Do not override
simulated event PostNetBeginPlay()
{
	local Actor W;
	
	if ( BaseWeaponClass == None )
		BaseWeaponClass = class<Weapon>( DynamicLoadObject(BaseWeaponClassString,class'Class',true));

	if ( (BaseWeaponClass != None) && (LCWeaponClass != None) )
	{
		InitClassDefaults();
		ForEach AllActors( LCWeaponClass, W)
			if ( W.Class == LCWeaponClass )
				InitProperties( Weapon(W));
	}
	LifeSpan = 0.1;
}

//Initialize default values of this class
simulated function InitClassDefaults()
{
	local int i;
	local class<TournamentWeapon> TLC, TBase;
	
	//Actor
	LCWeaponClass.default.Skin            = BaseWeaponClass.default.Skin;
	LCWeaponClass.default.Texture         = BaseWeaponClass.default.Texture;
	For ( i=0 ; i<8 ; i++ )
		LCWeaponClass.default.MultiSkins[i] = BaseWeaponClass.default.MultiSkins[i];
		
	//Inventory
	LCWeaponClass.default.AutoSwitchPriority = BaseWeaponClass.default.AutoSwitchPriority;
	LCWeaponClass.default.InventoryGroup  = BaseWeaponClass.default.InventoryGroup;
	LCWeaponClass.default.PickupMessage   = BaseWeaponClass.default.PickupMessage;
	LCWeaponClass.default.ItemName        = BaseWeaponClass.default.ItemName;
	LCWeaponClass.default.ItemArticle     = BaseWeaponClass.default.ItemArticle;
	LCWeaponClass.default.RespawnTime     = BaseWeaponClass.default.RespawnTime;
	LCWeaponClass.default.PlayerViewOffset = BaseWeaponClass.default.PlayerViewOffset;
	LCWeaponClass.default.PlayerViewMesh  = BaseWeaponClass.default.PlayerViewMesh;
	LCWeaponClass.default.PlayerViewScale = BaseWeaponClass.default.PlayerViewScale;
	LCWeaponClass.default.BobDamping      = BaseWeaponClass.default.BobDamping;
	LCWeaponClass.default.PickupViewMesh  = BaseWeaponClass.default.PickupViewMesh;
	LCWeaponClass.default.PickupViewScale = BaseWeaponClass.default.PickupViewScale;
	LCWeaponClass.default.ThirdPersonMesh = BaseWeaponClass.default.ThirdPersonMesh;
	LCWeaponClass.default.ThirdPersonScale = BaseWeaponClass.default.ThirdPersonScale;
	LCWeaponClass.default.StatusIcon      = BaseWeaponClass.default.StatusIcon;
	LCWeaponClass.default.MaxDesireability = BaseWeaponClass.default.MaxDesireability;
	LCWeaponClass.default.PickupSound     = BaseWeaponClass.default.PickupSound;
	LCWeaponClass.default.RespawnSound    = BaseWeaponClass.default.RespawnSound;
	LCWeaponClass.default.PickupMessageClass = BaseWeaponClass.default.PickupMessageClass;
	
	//Weapon
	LCWeaponClass.default.AmmoName        = BaseWeaponClass.default.AmmoName;
	LCWeaponClass.default.PickupAmmoCount = BaseWeaponClass.default.PickupAmmoCount;
	LCWeaponClass.default.bWarnTarget     = BaseWeaponClass.default.bWarnTarget;
	LCWeaponClass.default.bAltWarnTarget  = BaseWeaponClass.default.bAltWarnTarget;
	LCWeaponClass.default.bSplashDamage   = BaseWeaponClass.default.bSplashDamage;
	LCWeaponClass.default.bCanThrow       = BaseWeaponClass.default.bCanThrow;
	LCWeaponClass.default.bRecommendSplashDamage = BaseWeaponClass.default.bRecommendSplashDamage;
	LCWeaponClass.default.bRecommendAltSplashDamage = BaseWeaponClass.default.bRecommendAltSplashDamage;
	LCWeaponClass.default.FireOffset      = BaseWeaponClass.default.FireOffset;
	LCWeaponClass.default.ProjectileClass = BaseWeaponClass.default.ProjectileClass;
	LCWeaponClass.default.AltProjectileClass = BaseWeaponClass.default.AltProjectileClass;
	LCWeaponClass.default.MyDamageType    = BaseWeaponClass.default.MyDamageType;
	LCWeaponClass.default.AltDamageType   = BaseWeaponClass.default.AltDamageType;
	LCWeaponClass.default.FireSound       = BaseWeaponClass.default.FireSound;
	LCWeaponClass.default.AltFireSound    = BaseWeaponClass.default.AltFireSound;
	LCWeaponClass.default.CockingSound    = BaseWeaponClass.default.CockingSound;
	LCWeaponClass.default.SelectSound     = BaseWeaponClass.default.SelectSound;
	LCWeaponClass.default.Misc1Sound      = BaseWeaponClass.default.Misc1Sound;
	LCWeaponClass.default.Misc2Sound      = BaseWeaponClass.default.Misc2Sound;
	LCWeaponClass.default.Misc3Sound      = BaseWeaponClass.default.Misc3Sound;
	LCWeaponClass.default.MessageNoAmmo   = BaseWeaponClass.default.MessageNoAmmo;
	LCWeaponClass.default.DeathMessage    = BaseWeaponClass.default.DeathMessage;
	LCWeaponClass.default.NameColor       = BaseWeaponClass.default.NameColor;
	
	TLC = class<TournamentWeapon>(LCWeaponClass);
	TBase = class<TournamentWeapon>(BaseWeaponClass);
	if ( (TLC != None) && (TBase != None) )
	{
		TLC.default.InstFog = TBase.default.InstFog;
		TLC.default.InstFlash = TBase.default.InstFlash;
	}
	
	//XC_Engine: make ammo relevant
	if ( (Role == ROLE_Authority) && (class'LCStatics'.default.XCGE_Version > 0) && (LCWeaponClass.default.AmmoName != None) )
		ConsoleCommand("set"@LCWeaponClass.default.AmmoName@"bSuperClassRelevancy 1");
}

//Initialize values for existing weapons
simulated function InitProperties( Weapon W)
{
	local int i;
	//Actor
	W.Skin            = W.default.Skin;
	W.Texture         = W.default.Texture;
	For ( i=0 ; i<8 ; i++ )
		W.MultiSkins[i] = W.default.MultiSkins[i];
	
	//Inventory
	W.AutoSwitchPriority = W.default.AutoSwitchPriority;
	W.InventoryGroup  = W.default.InventoryGroup;
	W.PickupMessage   = W.default.PickupMessage;
	W.ItemName        = W.default.ItemName;
	W.ItemArticle     = W.default.ItemArticle;
	W.PlayerViewOffset = W.default.PlayerViewOffset;
	W.PlayerViewMesh  = W.default.PlayerViewMesh;
	W.PlayerViewScale = W.default.PlayerViewScale;
	W.BobDamping      = W.default.BobDamping;
	W.PickupViewMesh  = W.default.PickupViewMesh;
	W.PickupViewScale = W.default.PickupViewScale;
	W.ThirdPersonMesh = W.default.ThirdPersonMesh;
	W.ThirdPersonScale = W.default.ThirdPersonScale;
	W.StatusIcon      = W.default.StatusIcon;
	W.MaxDesireability = W.default.MaxDesireability;
	W.PickupSound     = W.default.PickupSound;
	W.RespawnSound    = W.default.RespawnSound;
	W.PickupMessageClass = W.default.PickupMessageClass;

	//Weapon
	W.AmmoName        = W.default.AmmoName;
	W.PickupAmmoCount = W.default.PickupAmmoCount;
	W.bWarnTarget     = W.default.bWarnTarget;
	W.bAltWarnTarget  = W.default.bAltWarnTarget;
	W.bSplashDamage   = W.default.bSplashDamage;
	W.bCanThrow       = W.default.bCanThrow;
	W.bRecommendSplashDamage = W.default.bRecommendSplashDamage;
	W.bRecommendAltSplashDamage = W.default.bRecommendAltSplashDamage;
	W.FireOffset      = W.default.FireOffset;
	W.ProjectileClass = W.default.ProjectileClass;
	W.AltProjectileClass = W.default.AltProjectileClass;
	W.MyDamageType    = W.default.MyDamageType;
	W.AltDamageType   = W.default.AltDamageType;
	W.FireSound       = W.default.FireSound;
	W.AltFireSound    = W.default.AltFireSound;
	W.CockingSound    = W.default.CockingSound;
	W.SelectSound     = W.default.SelectSound;
	W.Misc1Sound      = W.default.Misc1Sound;
	W.Misc2Sound      = W.default.Misc2Sound;
	W.Misc3Sound      = W.default.Misc3Sound;
	W.MessageNoAmmo   = W.default.MessageNoAmmo;
	W.DeathMessage    = W.default.DeathMessage;
	W.NameColor       = W.default.NameColor;
}




defaultproperties
{
	bNetTemporary=True
}