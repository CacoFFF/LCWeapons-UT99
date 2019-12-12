//Keep all basic weapon replacement and standalone implementations here
class LCMutator expands XC_LagCompensation;

var Weapon ReplaceThis, ReplaceWith;
var LCSpawnNotify ReplaceSN;
var bool bApplySNReplace;
var bool bTeamShock;
var string LoadedClasses;

//Find known custom arenas, replace with LC arenas
event PreBeginPlay()
{
	local Mutator M, old;

	Super.PreBeginPlay(); //XC_LagCompensation will hook the monsters

	//New arena is hooked right before this LCMutator
	if ( FoundArena( Level.Game.BaseMutator) )
	{
		M = Level.Game.BaseMutator;
		Level.Game.BaseMutator = M.nextMutator;
		M.Destroy();
	}
	old = Level.Game.BaseMutator;
	For ( M=old.NextMutator ; M!=none ; M=M.nextMutator )
	{
		if ( FoundArena( M) )
		{
			old.NextMutator = M.NextMutator;
			M.Destroy();
		}
		else
			old = M;
	}
}

function AddMutator(Mutator M)
{
	//Do not add this arena if it can be replaced
	if ( FoundArena(M) || M==self )
	{
		return;
	}

	if ( FV_ColoredShock(M) != none )
	{
		bTeamShock = true;
		M.Destroy();
		return;
	}

	if ( NextMutator == None )
		NextMutator = M;
	else
		NextMutator.AddMutator(M);
}

event PostBeginPlay()
{
	ReplaceSN = Spawn(class'LCSpawnNotify');
	ReplaceSN.Mutator = self;
}

function ModifyPlayer( Pawn Other)
{
	local XC_LagCompensator XCLC;
	Super.ModifyPlayer(Other);

	if ( ffFindCompFor(Other) == none )
		ffInsertNewPlayer( Other);
}

function Class<Weapon> MyDefaultWeapon()
{
	if ( Level.Game.DefaultWeapon == class'ImpactHammer' )
		return class'LCImpactHammer';
	return Level.Game.DefaultWeapon;
}

function bool IsRelevant( Actor Other, out byte bSuperRelevant)
{
	local int Result;

	if ( ScriptedPawn(Other) != None )
	{
		SetupPosList( Other );
		return true;
	}

	Result = LCReplacement(Other); //0 = replace, 1 = no replace, 2 = delayed replace
	if ( Result == 1 && (NextMutator != None) ) //Do not let mutators alter delayed replacements
		Result = int(NextMutator.IsRelevant(Other, bSuperRelevant));

	return (Result > 0);
}

function int LCReplacement( Actor Other)
{
	local Weapon W;
	
	W = Weapon(Other);
	if ( W == none )
		return 1;

	if ( W.GetPropertyText("LCChan") != "" )
	{
		W.KillCredit(self);
		return 1;
	}
		
	if ( W.Class == class'ImpactHammer' )
		return DoReplace(W,class'LCImpactHammer');
	else if ( ClassIsChildOf( W.Class, class'Enforcer') )
	{
		if ( W.Class == class'Enforcer' )		return DoReplace(W,class'LCEnforcer');
		else if ( W.IsA('sgEnforcer') )			return DoReplace(W,class'LCEnforcer',,,true);
	}
	else if ( ClassIsChildOf( W.Class, class'ShockRifle') )
	{
		if ( W.Class == class'ShockRifle' )			return DoReplace(W,class'LCShockRifle');
		if ( W.Class == class'SuperShockRifle' )	return DoReplace(W,class'LCSuperShockRifle',class'LCShockRifleLoader');
		if ( W.IsA('AdvancedShockRifle') )			return DoReplace(W,class'LCAdvancedShockRifle',class'LCShockRifleLoader');
		if ( W.IsA('BP_ShockRifle') )				return DoReplace(W,class'LCBP_ShockRifle',class'LCShockRifleLoader');
		if ( W.IsA('RainbowShockRifle') )			return DoReplace(W,class'LCRainbowShockRifle',class'LCShockRifleLoader');
	}
	else if ( W.default.Mesh == LodMesh'Botpack.RiflePick' )	//This is a sniper rifle!
	{
		if ( ClassIsChildOf( W.Class, class'SniperRifle') )
		{
			if ( W.Class == class'SniperRifle' )	return DoReplace(W,class'LCSniperRifle');
			else if ( W.IsA('SniperRifle2x') ) 		return DoReplace(W,class'LCSniperRifle',,,true); //AWM_Beta1 rifle
			else if ( W.IsA('BP_SniperRifle') )		return DoReplace(W,class'LCBP_SniperRifle',class'LCSniperRifleLoader');
		}
		else if ( W.IsA('MH2Rifle') )
		{
			class'LCMH2Rifle'.default.RifleDamage = int(W.GetPropertyText("RifleDamage"));
			if ( class'LCMH2Rifle'.default.RifleDamage == 0 )
				class'LCMH2Rifle'.default.RifleDamage = 50;
			return DoReplace(W,class'LCMH2Rifle',class'LCSniperRifleLoader');
		}
		else if ( W.IsA('NYACovertSniper') )		return DoReplace(W,class'LCNYACovertSniper',class'LCSniperRifleLoader');
		else if ( W.IsA('ChamV2SniperRifle') )		return DoReplace(W,class'LCChamRifle',class'LCSniperRifleLoader');
		else if ( string(W.class) ~= "h4xRiflev3.h4x_Rifle" )	return DoReplace(W,class'LC_v3_h4xRifle',class'LCSniperRifleLoader');
		else if ( W.IsA('AlienAssaultRifle') )					return DoReplace(W,class'LC_AARV17',class'LCSniperRifleLoader');
	}
	else if ( ClassIsChildOf( W.Class, class'minigun2') )
	{
		if ( W.Class == class'minigun2' )			return DoReplace(W,class'LCMinigun2');
		else if ( W.IsA('Minigun_2x') )				return DoReplace(W,class'LCMinigun2',,,true);
		else if ( W.IsA('BP_Minigun') )				return DoReplace(W,class'LCBP_Minigun',class'LCClassLoader');
		else if ( W.IsA('sgMinigun') )				return SiegeMini(W);
	}
	else if ( W.default.Mesh == LodMesh'UnrealI.minipick' )	//This is an old minigun!
	{
		if ( (W.Class == Class'UnrealI.Minigun') || W.IsA('OLMinigun') )
			return DoReplace( W, class'LCMinigun');
		else if ( W.IsA('LMinigun') ) //Liandri minigun
		{
			Class'LCLiandriMinigun'.default.OrgClass = class<TournamentWeapon>(W.Class);
			return DoReplace( W, class'LCLiandriMinigun');
		}
	}
	else if ( W.IsA('AsmdPulseRifle') ) //SiegeXtreme
	{
		Class'LCAsmdPulseRifle'.default.OrgClass = class<TournamentWeapon>(W.Class);
		return DoReplace( W, class'LCAsmdPulseRifle');
	}
	else if ( W.IsA('SiegeInstagibRifle') ) //SiegeUltimate
	{
		Class'LCSiegeInstagibRifle'.default.OrgClass = class<TournamentWeapon>(W.Class);
		return DoReplace( W, class'LCSiegeInstagibRifle');
	}


	return 1;
}

function int SiegeMini( Weapon Other)
{
	local Weapon W;

	W = W.Spawn(class'LCMinigun2', W.Owner, W.Tag);
	if ( W != none )
	{
		LCMinigun2(W).SlowSleep = 0.14;
		LCMinigun2(W).FastSleep = 0.09;
		W.SetCollisionSize( W.CollisionRadius, W.CollisionHeight);
		W.Tag = W.Tag;
		W.Event = W.Event;
		if ( W.MyMarker != none )
		{
			W.MyMarker = W.MyMarker;
			W.MyMarker.markedItem = W;
		}
		W.bHeldItem = W.bHeldItem;
		W.RespawnTime = W.RespawnTime;
		W.PickupAmmoCount = W.PickupAmmoCount;
		W.AmmoName = W.AmmoName;
		W.bRotatingPickup = W.bRotatingPickup;
		SetReplace( Other, W);
		return int(bApplySNReplace) * 2;
	}
	return 1;
}

function int DoReplace
(
	Weapon Other,
	class<Weapon> NewWeapClass,
	optional class<LCClassLoader> LoaderClass,
	optional bool bFullAmmo,
	optional bool bCopyAmmo
)
{
	local Weapon W;

	if ( LoaderClass != None )
		SetupLoader( Other.Class, NewWeapClass, LoaderClass);
	
	W = Other.Spawn(NewWeapClass, Other.Owner, Other.Tag);
	if ( W != none )
	{
		W.SetCollisionSize( Other.CollisionRadius, Other.CollisionHeight);
		W.Tag = Other.Tag;
		W.Event = Other.Event;
		if ( Other.MyMarker != none )
		{
			W.MyMarker = Other.MyMarker;
			W.MyMarker.markedItem = W;
		}
		W.bHeldItem = Other.bHeldItem;
		W.RespawnTime = Other.RespawnTime;
		W.PickupAmmoCount = Other.PickupAmmoCount;
		if ( bCopyAmmo )
			W.AmmoName = Other.AmmoName;
		if ( bFullAmmo )
			W.PickupAmmoCount = W.AmmoName.default.MaxAmmo;
		W.bRotatingPickup = Other.bRotatingPickup;
		SetReplace( Other, W);
		return int(bApplySNReplace) * 2;
	}
	return 1;
}

function SetReplace( Weapon Other, Weapon With)
{
	ReplaceThis = Other;
	ReplaceWith = With;
	if ( ReplaceThis != none && ReplaceWith != none)
		ReplaceSN.ActorClass = ReplaceThis.class;
	else
		ReplaceSN.ActorClass = class'LCDummyWeapon';
}

function SetupLoader( class<Weapon> OrgW, class<Weapon> NewW, class<LCClassLoader> LoaderClass)
{
	if ( (LoaderClass != None) && (InStr(LoadedClasses, ";" $ NewW.Name $ ";") == -1) )
	{
		LoadedClasses = LoadedClasses $ NewW.Name $ ";";
		Spawn( LoaderClass).Setup( OrgW, NewW);
	}
}

//***************************************************
//This function is massive, deal with each known case
//***************************************************
function bool FoundArena( Mutator M)
{
	local LCArenaMutator LCArena;

	if ( M == none )
		return false;

	if ( Arena(M) != none )
	{
		if ( M.IsA('SniperArena') )
		{
			LCArena = Spawn( class'LCArenaMutator');
			LCArena.SetupWeaponReplace( class'SniperRifle', class'LCSniperRifle');
			LCArena.AddPropertyWeapon( "bCanThrow", "0");
		}
		else if ( M.IsA('ShockArena') )
		{
			LCArena = Spawn( class'LCArenaMutator');
			LCArena.SetupWeaponReplace( class'ShockRifle', class'LCShockRifle');
			LCArena.AddPropertyWeapon( "bCanThrow", "0");
		}
		else if ( M.IsA('impactarena') )
		{
			LCArena = Spawn( class'LCArenaMutator');
			LCArena.SetupWeaponReplace( class'ImpactHammer', class'LCImpactHammer');
		}
		else if ( M.IsA('InstaGibDM') )
		{
			LCArena = Spawn( class'LCArenaMutator');
			LCArena.SetupWeaponReplace( class'SuperShockRifle', class'LCSuperShockRifle');
			if ( !ChainMutatorBeforeThis(LCArena) )
				return false;
			LCArena.LCMutator = self;
			LCArena.SetupWeaponRespawn( true, true, true, true, true, true);
			LCArena.SetupPickups( true, true, false, true);
			LCArena.AddPropertyWeapon( "bNoAmmoDeplete", "1");
			LCArena.AddPropertyWeapon( "bCanThrow", "0");
			SetupLoader( LCArena.OldWeapClass, LCArena.MainWeapClass, class'LCShockRifleLoader');
			return true;
		}

		if ( LCArena != none )
		{
			if ( !ChainMutatorBeforeThis(LCArena) )
				return false;
			LCArena.LCMutator = self;
			LCArena.SetupWeaponRespawn( true, true, true, true);
			LCArena.SetupPickups( false, false, false, true);
			return true;
		}
	}
	else if ( M.IsA('NYACovertSniper_RIFLEMutator') )
	{
		LCArena = Spawn( class'LCArenaMutator');
		LCArena.SetupWeaponReplace( class<Weapon>(DynamicLoadObject("NYACovertSniper.NYACovertSniper",class'class')), class'LCNYACovertSniper');
		if ( !ChainMutatorBeforeThis(LCArena) )
			return false;
		LCArena.LCMutator = self;
		LCArena.SetupWeaponRespawn( true, true, true, true);
		LCArena.SetupPickups( false, false, false, true);
		LCArena.AddPropertyWeapon( "bCanThrow", "0");
		SetServerPackage( "NYACovertSniper");
		SetupLoader( LCArena.OldWeapClass, LCArena.MainWeapClass, class'LCSniperRifleLoader');
		return true;
	}
	else if ( string(M.Class) ~= "ChamRifle_v2.Rifle_HeadshotMut" )
	{
		LCArena = Spawn( class'LCArenaMutator');
		LCArena.SetupWeaponReplace( class<Weapon>(DynamicLoadObject("ChamRifle_v2.ChamV2SniperRifle",class'class')), class'LCChamRifle');
		if ( !ChainMutatorBeforeThis(LCArena) )
			return false;
		LCArena.LCMutator = self;
		LCArena.SetupWeaponRespawn( true, true, true, true);
		LCArena.SetupPickups( false, false, false, true);
		LCArena.AddPropertyWeapon( "bCanThrow", "0");
		SetServerPackage( "ChamRifle_v2");
		SetupLoader( LCArena.OldWeapClass, LCArena.MainWeapClass, class'LCSniperRifleLoader');
		return true;
	}
	else if ( string(M.Class) ~= "h4xRiflev3.h4x_HeadshotMut" )
	{
		LCArena = Spawn( class'LCArenaMutator');
		LCArena.SetupWeaponReplace( class<Weapon>(DynamicLoadObject("h4xRiflev3.h4x_Rifle",class'class')), class'LC_v3_h4xRifle');
		if ( !ChainMutatorBeforeThis(LCArena) )
			return false;
		LCArena.LCMutator = self;
		LCArena.SetupWeaponRespawn( true, true, true, true);
		LCArena.SetupPickups( true, false, false, false);
		LCArena.SetupCustomXLoc( class<Translocator>(DynamicLoadObject("h4xRiflev3.h4x_Xloc",class'class')), true);
		LCArena.AddPropertyWeapon( "bCanThrow", "0");
		SetServerPackage( "h4xRiflev3");
		SetupLoader( LCArena.OldWeapClass, LCArena.MainWeapClass, class'LCSniperRifleLoader');
		return true;
	}
	else if ( string(M.Class) ~= "AARV17.AlienRifleMutator" )
	{
		LCArena = Spawn( class'LCArenaMutator');
		LCArena.SetupWeaponReplace( class<Weapon>(DynamicLoadObject("AARV17.AlienAssaultRifle",class'class')), class'LC_AARV17');
		if ( !ChainMutatorBeforeThis(LCArena) )
			return false;
		LCArena.LCMutator = self;
		LCArena.SetupWeaponRespawn( true, true, true, true, true);
//		LCArena.SetupPickups( false, false, false, false);
		LCArena.AddPropertyWeapon( "bCanThrow", "0");
		SetServerPackage( "AARV17");
		SetupLoader( LCArena.OldWeapClass, LCArena.MainWeapClass, class'LCSniperRifleLoader');
		return true;
	}

	
}

function bool ChainMutatorBeforeThis( Mutator M)
{
	local Mutator MU;
	M.NextMutator = self;
	if ( Level.Game.BaseMutator == self )
	{
		Level.Game.BaseMutator = M;
		return true;
	}

	For ( MU=Level.Game.BaseMutator ; MU.NextMutator != none ; MU=MU.NextMutator )
	{
		if ( MU.NextMutator == self )
		{
			MU.NextMutator = M;
			return true;
		}
	}

	Level.Game.BaseMutator.AddMutator( M);
	return true;
}


//*******************************
//******************* MUTATE

//Mimicking ZP because ppl gets used to stuff
function Mutate (string MutateString, PlayerPawn Sender)
{
	if ( !bNoBinds && Left(MutateString, 10) ~= "getweapon " )
	{
		if ( (MutateString ~= "getweapon zp_SniperRifle") || (MutateString ~= "getweapon zp_sn") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCSniperRifle');
		else if ( (MutateString ~= "getweapon zp_ShockRifle") || (MutateString ~= "getweapon zp_sh") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCShockRifle');
		else if ( (MutateString ~= "getweapon zp_Enforcer") || (MutateString ~= "getweapon zp_e") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCEnforcer');
		else if ( (MutateString ~= "getweapon lc_apr") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCAsmdPulseRifle');
		else if ( (MutateString ~= "getweapon lc_sir") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCSiegeInstagibRifle');
		else if ( (MutateString ~= "getweapon lc_m") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCMinigun2');
		else if ( (MutateString ~= "getweapon lc_ih") )
			Class'LCStatics'.static.FindBasedWeapon( Sender, class'LCImpactHammer');
	}
	else if ( MutateString ~= "zp_Off" )
	{
		Sender.ClientMessage("Zeroping disabled.");
		Sender.ClientMessage("Type 'mutate zp_on' to restore.");
		ffFindCompFor(Sender).CompChannel.ClientChangeLC(false);
	}
	else if ( MutateString ~= "zp_On" )
	{
		Sender.ClientMessage("Zeroping enabled.");
		Sender.ClientMessage("Type 'mutate zp_off' to disable.");
		ffFindCompFor(Sender).CompChannel.ClientChangeLC(true);
	}
	else if ( MutateString ~= "state" )
		Sender.ClientMessage("Weapon State:" @ string(Sender.Weapon.GetStateName()));
	Super.Mutate(MutateString,Sender);
}

//******************************************
//****************** DYNAMIC PACKAGE LOADING
//*** Platform friendly function, change this code for Unreal 227

final function SetServerPackage( string Pkg)
{
	if ( LCS.default.XCGE_Version >= 11 )
		AddToPackageMap( Pkg);
}


defaultproperties
{
     LoadedClasses=";"
}
