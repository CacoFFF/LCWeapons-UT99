//**********************************************************
// LCArenaMutator
// This multipurpose generic arena will replace other arenas
// Given how enforcer is, it has to be placed before main LC
//**********************************************************

class LCArenaMutator expands Mutator;

var LCMutator LCMutator;

var class<Weapon> OldWeapClass;
var class<Weapon> MainWeapClass;
var class<Ammo> OldAmmoClass;
var class<Ammo> MainAmmoClass;

var bool bReplaceAllWeapons;
var bool bReplaceAllAmmo;
var bool bGiveWeaponOnSpawn;
var bool bKillEnforcers;
var bool bRemoveHealth;
var bool bRemovePickups;
var bool bRemoveBoots;
var bool bRemoveMelee;
var bool bMaxAmmoOnWeap;
var bool bMaxAmmoOnAmmo;

var class<Translocator> CustomXLocClass;
var bool bForceCustomXLoc;

var string wProp[8], wValue[8];
var int iWp;

function Weapon GiveWeapon( Pawn PlayerPawn, class<Weapon> WeaponClass, optional bool bNoProps )
{
	local int i;
	local Weapon NewWeapon;

	NewWeapon = Weapon(PlayerPawn.FindInventoryType(WeaponClass));
	if ( NewWeapon == None )
	{
		NewWeapon = Spawn(WeaponClass);
		if( NewWeapon != None )
		{
			if ( LCMutator.bTeamShock && (NewWeapon.Class == class'LCShockRifle') )
				NewWeapon.SetPropertyText("bTeamColor", "1" ); //Not the best implementation
			NewWeapon.RespawnTime = 0.0;
			NewWeapon.GiveTo(PlayerPawn);
			NewWeapon.bHeldItem = true;
			NewWeapon.GiveAmmo(PlayerPawn);
			NewWeapon.SetSwitchPriority(PlayerPawn);
			NewWeapon.WeaponSet(PlayerPawn);
			NewWeapon.AmbientGlow = 0;
			if ( PlayerPawn.IsA('PlayerPawn') )
				NewWeapon.SetHand(PlayerPawn(PlayerPawn).Handedness);
			else
				NewWeapon.GotoState('Idle');
			PlayerPawn.Weapon.GotoState('DownWeapon');
			PlayerPawn.PendingWeapon = None;
			PlayerPawn.Weapon = NewWeapon;
		}
	}
	if ( !bNoProps && (NewWeapon != None) )
		While ( i<iWp )
		{
			NewWeapon.SetPropertyText( wProp[i], wValue[i]);
			i++;
		}
	
	return NewWeapon;
}


function ModifyPlayer( Pawn Other)
{
	if ( bForceCustomXLoc && ((DeathMatchPlus(Level.Game) == none) || !DeathMatchPlus(Level.Game).bUseTranslocator) )
		GiveWeapon( Other, CustomXLocClass, true);
	if ( bGiveWeaponOnSpawn )
		GiveWeapon( Other, MainWeapClass);

	if ( NextMutator != None )
		NextMutator.ModifyPlayer(Other);
}

// OrgW is the original custom weapon, we'll use it's ammo
// NewW is the lag compensated custom weapon
// OldW is the weapon we're replacing (if none, replace all weapons)
// OldAmmo is the ammo we're replacing with the new ones, (if none, replace all ammos)

function SetupWeaponReplace( class<Weapon> OrgW, class<Weapon> NewW, optional class<Weapon> OldW, optional class<Ammo> OldAmmo)
{
	OldWeapClass = OldW;
	MainWeapClass = NewW;
	MainAmmoClass = OrgW.default.AmmoName;
	MainWeapClass.default.AmmoName = MainAmmoclass;
	OldAmmoClass = OldAmmo;
	if ( OldW == none )
		bReplaceAllWeapons = true;
	if ( OldAmmo == none )
		bReplaceAllAmmo = true;
}

function SetupWeaponRespawn( bool bNoEnforcer, bool bNoMelee, bool bGiveWOnSpawn, bool bFullAmmo, optional bool bRemoveGroundWeapons, optional bool bRemoveGroundAmmo)
{
	local Ammo A;
	local Weapon W;

	bKillEnforcers = bNoEnforcer;
	bRemoveMelee = bNoMelee;
	bGiveWeaponOnSpawn = bGiveWOnSpawn;
	bMaxAmmoOnWeap = bFullAmmo;

	if ( bRemoveGroundWeapons )
		ForEach AllActors (class'Weapon', W)
			if ( W.Owner == none )
				W.Destroy();

	if ( bRemoveGroundAmmo )
		ForEach AllActors (class'Ammo', A)
			if ( A.Owner == none )
				A.Destroy();
}

function SetupPickups( bool bNoHealth, bool bNoPickups, bool bNoBoots, bool bFullAmmo)
{
	bRemoveHealth = bNoHealth;
	bRemovePickups = bNoPickups;
	bRemoveBoots = bNoBoots;
	bMaxAmmoOnAmmo = bFullAmmo;
}

function SetupCustomXLoc( class<Translocator> NewXLoc, optional bool bForceXLoc)
{
	CustomXLocClass = NewXLoc;
	bForceCustomXLoc = bForceXLoc;
}

//Prevent further mutation on our LC variant
function bool AlwaysKeep(Actor Other)
{
	if ( Other.class == MainWeapClass )
	{
		if ( bMaxAmmoOnWeap )
			Weapon(Other).PickupAmmoCount = Weapon(Other).AmmoName.default.MaxAmmo;
		return true;
	}
	if ( Other.class == MainAmmoClass )
	{
		if ( bMaxAmmoOnAmmo )
			Ammo(Other).AmmoAmount = Ammo(Other).MaxAmmo;
		return true;
	}
	if ( NextMutator != None )
		return ( NextMutator.AlwaysKeep(Other) );
	return false;
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	if ( Weapon(Other) != none )
	{
		if ( Other.IsA('Translocator') )
		{
			if ( Other.Class == CustomXLocClass )
				return (bForceCustomXLoc || ((DeathMatchPlus(Level.Game) != none) && DeathMatchPlus(Level.Game).bUseTranslocator));
			if ( bForceCustomXLoc && (CustomXLocClass != none) && (Other.Class != CustomXLocClass) )
				return LCMutator.DoReplace( Weapon(Other), CustomXLocClass) > 0;
			return ((DeathMatchPlus(Level.Game) != none) && DeathMatchPlus(Level.Game).bUseTranslocator);
		}
		if ( Weapon(Other).AmmoName == none ) //Weapons without ammo are utilitary
			return !bRemoveMelee;
		if ( (Enforcer(Other) != none) && bKillEnforcers )
			return false;
		if ( bReplaceAllWeapons || (Other.class == OldWeapClass) )
			return LCMutator.DoReplace( Weapon(Other), MainWeapClass) > 0;
	}
	else if ( Pickup(Other) != none )
	{
		if ( Ammo(Other) != none )
		{
			if ( bReplaceAllAmmo || (Other.class == OldAmmoClass) )
			{
				ReplaceWith( Other, string(MainAmmoClass) );
				return false;
			}
		}
		else
		{
			if ( Other.IsA('Health') || Other.IsA('TournamentHealth') )
				return !bRemoveHealth;
			if ( InStr(caps(string(Other.class)),"BOOTS") >= 0 )
				return !bRemoveBoots;
			return !bRemovePickups;
		}
	}
	return true;
}

function AddPropertyWeapon( string NewWP, string NewWV)
{
	wProp[iWp] = NewWP;
	wValue[iWp++] = NewWV;
}
