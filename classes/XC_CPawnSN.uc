class XC_CPawnSN expands SpawnNotify;

var XC_CompensatorChannel Channel;
var XC_ElementAdvancer Advancer;

function Setup( XC_CompensatorChannel COwner, XC_ElementAdvancer EAdv)
{
	Channel = COwner;
	Advancer = EAdv;
}

event Actor SpawnNotification( Actor A)
{
	if ( A.default.RemoteRole != ROLE_SimulatedProxy )
		return A;
	if ( StationaryPawn(A) != none )
		return A;
	Advancer.RegisterAdvance( A);
	return A;
}

defaultproperties
{
    ActorClass=class'Pawn'
    RemoteRole=ROLE_None
}