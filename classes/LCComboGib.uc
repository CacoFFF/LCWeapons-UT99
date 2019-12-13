//=============================================================================
// LCComboGib.
// Noob coders, noob coders everywhere
//=============================================================================
class LCComboGib expands LCArenaMutator
	config(LCWeapons);

var() config float ForceBallDamage;
var() config float LolPushChance; //Push a player's corpse far away instead of gibbing(0-100)
var() config bool bLolAffectsTeam;
var() config bool bKeepBoots;
var() config int LimitBalls; //It doesn't make a bit of difference guys, the balls are inert - Piccolo


function AddMutator( Mutator M)
{
	if ( LCMutator(M) != None )
		LCMutator = LCMutator(M);
	Super.AddMutator(M);
}

event PostBeginPlay()
{
	SetupWeaponReplace( class'ShockRifle', class'LCShockRifle');
	SetupWeaponRespawn( true, true, true, true, true, true);
	SetupPickups( true, true, !bKeepBoots, false);
	AddPropertyWeapon("bNoAmmoDeplete","1");
	AddPropertyWeapon("MyDamageType","joltedgib");
	NextDamageMutator = Level.Game.DamageMutator;
	Level.Game.DamageMutator = self;
	SetTimer(20,true);
	SaveConfig();
}

event Timer()
{
	default.ForceBallDamage = ForceBallDamage;
	SaveConfig(); //Save config every 20 seconds
	//This mutator's config is applied entirely on the fly
	//Meaning it can be edited ingame and the effects will be seen and saved
}

function Weapon GiveWeapon( Pawn PlayerPawn, class<Weapon> WeaponClass, optional bool bNoProps )
{
	local Weapon NewWeapon;

	NewWeapon = Super.GiveWeapon( PlayerPawn, WeaponClass,bNoProps);
	if ( !bNoProps && (FRand()*100.0 < LolPushChance) )
	{
		NewWeapon.MyDamageType = 'joltedlol';
		if ( ShockRifle(NewWeapon) != None )
			ShockRifle(NewWeapon).HitDamage = 10;
		if ( LCShockRifle(NewWeapon) != None )
			LCShockRifle(NewWeapon).bLolRifle = true;
	}
	return NewWeapon;
}

function MutatorTakeDamage( out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, 
						out Vector Momentum, name DamageType)
{
	local float BallDamage;

	if ( DamageType == 'joltedlol' )
	{
		if ( bLolAffectsTeam || ActualDamage > 0 )
		{
			if ( ActualDamage > 0 )
				ActualDamage = Clamp( Victim.Health, 25, 300);
			Momentum *= 7;
		}
	}
	else if ( DamageType == 'joltedgib' ) //Ensure kill
	{
		if ( ActualDamage > 0 )
			ActualDamage = 999;
	}
	else if ( ActualDamage > 0 && DamageType == 'jolted' ) //Combos and other jolted damages
	{
		BallDamage = 55;
		if ( (DeathMatchPlus(Level.Game) != None) && DeathMatchPlus(Level.Game).bHardcoreMode )
			BallDamage *= 1.5;

		if ( ActualDamage > BallDamage )
			ActualDamage = ForceBallDamage + (ActualDamage - BallDamage) * 5;
		else if ( ForceBallDamage > 0 )
			ActualDamage = ForceBallDamage;
	}

	if ( NextDamageMutator != None )
		NextDamageMutator.MutatorTakeDamage( ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType );
}


defaultproperties
{
	LolPushChance=10
	LimitBalls=4
	ForceBallDamage=0.100000
	bKeepBoots=true
}
