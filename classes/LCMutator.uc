//Keep all basic weapon replacement and standalone implementations here
class LCMutator expands XC_LagCompensation;

var Weapon ReplaceThis, ReplaceWith;
var LCSpawnNotify ReplaceSN;
var bool bApplySNReplace;
var bool bTeamShock;

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

function bool IsRelevant(Actor Other, out byte bSuperRelevant)
{
	local int Result;

	if ( Other.bIsPawn && Other.IsA('ScriptedPawn') )
	{	AddGenericPos( Other);
		return true;	}

	Result = LCReplacement(Other); //0 = replace, 1 = no replace, 2 = delayed replace
	if ( Result == 1 && (NextMutator != None) ) //Do not let mutators alter delayed replacements
		Result = int(NextMutator.IsRelevant(Other, bSuperRelevant));

	return (Result > 0);
}

function int LCReplacement (Actor Other)
{
	if ( Weapon(Other) == none )
		return 1;

	if ( Other.GetPropertyText("LCChan") != "" )
	{
		Other.KillCredit(self);
		return 1;
	}
		
	if ( Other.Class == class'ImpactHammer' )
		return DoReplace(Weapon(Other),class'LCImpactHammer');
	else if ( ClassIsChildOf( Other.Class, class'Enforcer') )
	{
		if ( Other.Class == class'Enforcer' )
			return DoReplace(Weapon(Other),class'LCEnforcer');
		else if ( Other.IsA('sgEnforcer') )
			return DoReplace(Weapon(Other),class'LCEnforcer',,true);
	}
	else if ( ClassIsChildOf( Other.Class, class'ShockRifle') )
	{
		if ( Other.Class == class'ShockRifle' )
			return DoReplace(Weapon(Other),class'LCShockRifle');
		if ( Other.Class == class'SuperShockRifle' )
			return DoReplace(Weapon(Other),class'LCSuperShockRifle');
		if ( Other.IsA('AdvancedShockRifle') )
			return DoReplace(Weapon(Other),class'LCAdvancedShockRifle');
	}
	else if ( Other.default.Mesh == LodMesh'Botpack.RiflePick' )	//This is a sniper rifle!
	{
		if ( ClassIsChildOf( Other.Class, class'SniperRifle') )
		{
			if ( Other.Class == class'SniperRifle' )
				return DoReplace(Weapon(Other),class'LCSniperRifle');
			else if ( Other.IsA('SniperRifle2x') ) //AWM_Beta1 rifle
				return DoReplace(Weapon(Other),class'LCSniperRifle',,true);
		}
		else if ( Other.IsA('MH2Rifle') )
		{
			class'LCMH2Rifle'.default.RifleDamage = int(Other.GetPropertyText("RifleDamage"));
			if ( class'LCMH2Rifle'.default.RifleDamage == 0 )
				class'LCMH2Rifle'.default.RifleDamage = 50;
			class'LCMH2Rifle'.default.OrgClass = class<TournamentWeapon>(Other.Class);
			return DoReplace(Weapon(Other),class'LCMH2Rifle',,true);
		}
		else if ( Other.IsA('NYACovertSniper') )
			return DoReplace(Weapon(Other),class'LCNYACovertSniper',,true);
		else if ( Other.IsA('ChamV2SniperRifle') )
			return DoReplace(Weapon(Other),class'LCChamRifle',,true);
		else if ( string(Other.class) ~= "h4xRiflev3.h4x_Rifle" )
			return DoReplace(Weapon(Other),class'LC_v3_h4xRifle');
	}
	else if ( ClassIsChildOf( Other.Class, class'minigun2') )
	{
		if ( Other.Class == class'minigun2' )
			return DoReplace(Weapon(Other),class'LCMinigun2');
		else if ( Other.IsA('Minigun_2x') )
			return DoReplace(Weapon(Other),class'LCMinigun2',,true);
		else if ( Other.IsA('sgMinigun') )
			return SiegeMini(Weapon(Other));
	}
	else if ( Other.default.Mesh == LodMesh'UnrealI.minipick' )	//This is an old minigun!
	{
		if ( (Other.Class == Class'UnrealI.Minigun') || Other.IsA('OLMinigun') )
			return DoReplace( Weapon(Other), class'LCMinigun');
		else if ( Other.IsA('LMinigun') ) //Liandri minigun
		{
			Class'LCLiandriMinigun'.default.OrgClass = class<TournamentWeapon>(Other.Class);
			return DoReplace( Weapon(Other), class'LCLiandriMinigun');
		}
	}
	else if ( Other.IsA('AsmdPulseRifle') ) //SiegeXtreme
	{
		Class'LCAsmdPulseRifle'.default.OrgClass = class<TournamentWeapon>(Other.Class);
		return DoReplace( Weapon(Other), class'LCAsmdPulseRifle');
	}
	else if ( Other.IsA('SiegeInstagibRifle') ) //SiegeUltimate
	{
		Class'LCSiegeInstagibRifle'.default.OrgClass = class<TournamentWeapon>(Other.Class);
		return DoReplace( Weapon(Other), class'LCSiegeInstagibRifle');
	}


	return 1;
}

function int SiegeMini( Weapon Other)
{
	local Weapon W;

	W = Other.Spawn(class'LCMinigun2', Other.Owner, Other.Tag);
	if ( W != none )
	{
		LCMinigun2(W).SlowSleep = 0.14;
		LCMinigun2(W).FastSleep = 0.09;
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
		W.AmmoName = Other.AmmoName;
		W.bRotatingPickup = Other.bRotatingPickup;
		SetReplace( Other, W);
		return int(bApplySNReplace) * 2;
	}
	return 1;
}

function int DoReplace( Weapon Other, class<Weapon> NewWeapClass, optional bool bFullAmmo, optional bool bCopyAmmo)
{
	local Weapon W;

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


//***************************************************
//This function is massive, deal with each known case
//***************************************************
function bool FoundArena( mutator M)
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
}
