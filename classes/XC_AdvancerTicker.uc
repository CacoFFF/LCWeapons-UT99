//=============================================================================
// AdvancerTicker.
//=============================================================================
class XC_AdvancerTicker expands Info;

var XC_ElementAdvancer Advancer;

event PostBeginPlay()
{
	SetTimer( 2, true);
}


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
	Advancer.NextHUDMutator = none;
	Advancer.RegisterHUDMutator();
}

