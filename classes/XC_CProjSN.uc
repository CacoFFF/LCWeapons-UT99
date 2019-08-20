class XC_CProjSN expands SpawnNotify;

var XC_CompensatorChannel Channel;
var XC_ElementAdvancer Advancer;
var Projectile Stored[256];
var float RemainingAdv[256];
var int iStored, iStoredNew;

var XC_ProjSimulator SimulatorList;


function Setup( XC_CompensatorChannel COwner, XC_ElementAdvancer EAdv)
{
	Channel = COwner;
	Advancer = EAdv;
}

event Actor SpawnNotification( Actor A)
{
	local XC_ProjSimulator Sim;
//	if ( A.Role == ROLE_Authority && A.RemoteRole == ROLE_None ) //Spawned by client with authoritary control (not for simulation purposes)
//		return A;

	if ( (Channel.ProjAdv > 0) && (Projectile(A).default.Damage != 0) )
	{
		Sim = XC_ProjSimulator(A);
		if ( Sim != none )
		{
			Sim.Notify = self;
			Sim.NextSimulator = SimulatorList;
			SimulatorList = Sim;
			Sim.ssCounter = Channel.cAdv; //Temporary, requires bWeaponAnim
			Sim.ssPredict = Channel.ProjAdv;
		}
		else if ( A.default.bNetTemporary || A.default.RemoteRole == ROLE_SimulatedProxy )
		{
			if ( iStoredNew < ArrayCount(Stored) )
			{
				RemainingAdv[iStoredNew] = Channel.ProjAdv;
				Stored[iStoredNew++] = Projectile(A);
			}
		}
		else //Guided warheads?
			Advancer.RegisterAdvance( A);
	}
	return A;
}

event Tick( float DeltaTime)
{
	local int i;
	local Effects Trail;
	local PlayerPawn Client;
	local bool bVisible;
	local vector ClientView;

	Client = Channel.LocalPlayer;
	if ( Client == None || DeltaTime == 0.0 || iStoredNew == 0 )
		return;
	
	ClientView = Client.Location;
	ClientView.Z += Client.EyeHeight;
	
	// Remove deleted and pre-processed entries:
	// - Assimilated projectiles are advanced according to assimilator
	// - Advanced (owned) projectiles are given to the element advancer
	// - Non-visible projectiles are advanced in full
	// Note: RemainingAdv is identical in all entries
	for ( i=iStoredNew-1 ; i>=iStored ; i-- )
	{
		if ( Stored[i] == None || Stored[i].bDeleteMe )
		{
			REMOVE_NEW:
			Stored[i] = Stored[--iStoredNew];
			Stored[iStoredNew] = None;
		}
		else
		{
			bVisible = Stored[i].FastTrace( ClientView);
			if ( Stored[i].Instigator == Client )
			{
				if ( AssimilateProjectile( Stored[i]) )
					Goto REMOVE_NEW;
				if ( bVisible )
				{
					Advancer.RegisterAdvance( Stored[i]); //Immediately register
					Goto REMOVE_NEW;
				}
			}

			if ( !bVisible )
			{
				AdvanceProjectile( Stored[i], RemainingAdv[i]);
				Goto REMOVE_NEW;
			}
		}
	}
	
	//Compact and update list
	DeltaTime *= 1.25;
	for ( i=iStoredNew-1 ; i>=0 ; i-- )
	{
		if ( Stored[i] == None || Stored[i].bDeleteMe || (Stored[i].Physics == PHYS_None) )
		{
			REMOVE_OLD:
			Stored[i] = Stored[--iStoredNew];
			RemainingAdv[i] = RemainingAdv[iStoredNew];
			Stored[iStoredNew] = None;
		}
		else
		{
			AdvanceProjectile( Stored[i], FMin( RemainingAdv[i], DeltaTime));
			if ( (RemainingAdv[i] -= DeltaTime) <= 0 )
				Goto REMOVE_OLD;
		}
	}
	iStored = iStoredNew;

}

function bool AssimilateProjectile( Projectile P)
{
	local XC_ProjSimulator Sim, BestSim;

	for ( Sim=SimulatorList ; Sim!=None ; Sim=Sim.NextSimulator )
		Sim.AssessProjectile( P, BestSim);
		
	if ( BestSim != None )
	{
		BestSim.Assimilate( P);
		return true;
	}
	return false;
}

function AdvanceProjectile( Projectile P, float AdvanceAmount)
{
	P.AutonomousPhysics( AdvanceAmount);
	if ( P.bNetTemporary ) //This is a projectile i have simulated control over
	{
		if ( P.LifeSpan > FMax( AdvanceAmount, 1) )
			P.LifeSpan -= AdvanceAmount;
		if ( (P.TimerRate > 0) && (P.bTimerLoop || (P.TimerRate - P.TimerCounter > FMax(AdvanceAmount, 1))) )
			class'LCStatics'.static.SetTimerCounter( P, P.TimerCounter + AdvanceAmount);
	}
}


defaultproperties
{
    ActorClass=class'Projectile'
    RemoteRole=ROLE_None
}