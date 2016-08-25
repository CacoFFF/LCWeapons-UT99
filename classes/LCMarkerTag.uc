class LCMarkerTag expands Actor;

var(Debug) Pawn POwner;
var XC_LagCompensation Mutator;
var XC_LagCompensator LCComp;
var float fPing;
var(Debug) float PingIncrement, PingMult;


replication
{
	reliable if ( Role == ROLE_Authority )
		SetPOwner;
	reliable if ( role < ROLE_Authority )
		MarkSpot;
}

event PostBeginPlay()
{
	ForEach AllActors (class'XC_LagCompensation', Mutator)
		break;
	
}

simulated event Tick( float DeltaTime) 
{
	if ( Owner == none || Owner.bDeleteMe )
		return;

	if ( Level.NetMode == NM_Client )
	{
		if ( POwner != none )
			MarkSpot( POwner.Location);
		return;
	}

	if ( FRand() < 0.1 && POwner != none )
	{
		SetPOwner( POwner);
		if ( LCComp == none || LCComp.ffOwner != POwner )
		{
			ForEach POwner.ChildActors (class'XC_LagCompensator', LCComp)
				break;
		}
	}
	else if ( POwner == none )
		LCComp = none;

	fPing = float( Owner.ConsoleCommand("GetPing") );
	fPing /= 1000;
	fPing = fPing * PingMult + PingIncrement;

	if ( LCComp != none )
	{
		Mutator.PingMult = PingMult;
		Mutator.PingAdd = PingIncrement;
		Mutator.ffUnlagSPosition(LCComp, fPing);
	}
}

function MarkSpot( vector NewSpot)
{
	SetLocation( NewSpot);
}


simulated function SetPOwner( pawn Other)
{
	POwner = Other;
}



defaultproperties
{
	NetUpdateFrequency=2
	Texture=Texture'S_Ammo'
	RemoteRole=ROLE_SimulatedProxy
	PingMult=1
}
