//=============================================================================
// AdvancerTicker.
//=============================================================================
class XC_AdvancerTicker expands Info;

var XC_ElementAdvancer Advancer;
var bool bPendingRemove;
var() bool bNoTick;

event PostBeginPlay()
{
	SetTimer( 2, true);
}
/*
event Tick( float DeltaTime)
{
	if ( bNoTick )
	{
		bNoTick = false;
		return;
	}
	return;
	Advancer.AdvancePositions( DeltaTime);
	if ( Advancer.Channel.bDelayedFire ) //No advancer, fire here
	{
		Advancer.Channel.CurWeapon.KillCredit( Advancer.Channel);
		Advancer.Channel.bDelayedFire = false;
	}
	if ( Advancer.Channel.bDelayedAltFire ) //No advancer, fire here
	{
		Advancer.Channel.CurWeapon.KillCredit( Advancer.Channel);
		Advancer.Channel.bDelayedAltFire = false;
	}
	if ( bPendingRemove )
	{
		Advancer.Ticker = spawn(class'XC_AdvancerTicker');
		Advancer.Ticker.Advancer = Advancer;
		Destroy();
	}
}*/

//HUD Mutator integrity
event Timer()
{
	local PlayerPawn LP;
	local Mutator M;
	if ( (Advancer == none) || (Advancer.Channel == none) )
		return;
	LP = Advancer.Channel.LocalPlayer;
	if ( LP == none || LP.MyHUD == none ) //WTF?
		return;
	for ( M=LP.MyHUD.HUDMutator ; M!=none ; M=M.nextHUDMutator )
		if ( M == Advancer )
			return;
	M.NextHUDMutator = none;
	M.RegisterHUDMutator();
}


defaultproperties
{
    bNoTick=True
}