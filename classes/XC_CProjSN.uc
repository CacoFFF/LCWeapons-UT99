class XC_CProjSN expands SpawnNotify;

var XC_CompensatorChannel Channel;
var XC_ElementAdvancer Advancer;
var Projectile Stored[256];
var float RemainingAdv[256];
var int iStored, iHighest;

var XC_ProjSimulator Simulators[32];
var int iSimul;

var Projectile PendingTrailers[16];
var int iTrailer;

function Setup( XC_CompensatorChannel COwner, XC_ElementAdvancer EAdv)
{
	Channel = COwner;
	Advancer = EAdv;
}

event Actor SpawnNotification( Actor A)
{
//	if ( A.Role == ROLE_Authority && A.RemoteRole == ROLE_None ) //Spawned by client with authoritary control (not for simulation purposes)
//		return A;

	if ( Channel.ProjAdv > 0 )
	{
		if ( XC_ProjSimulator(A) != none )
		{
			Simulators[iSimul++] = XC_ProjSimulator(A);
			XC_ProjSimulator(A).Notify = self;
			XC_ProjSimulator(A).ssCounter = Channel.cAdv; //Temporary, requires bWeaponAnim
			XC_ProjSimulator(A).ssPredict = Channel.ProjAdv;
		}
		else if ( A.default.bNetTemporary || A.default.RemoteRole == ROLE_SimulatedProxy )
		{
			if ( iStored < ArrayCount(Stored) )
			{
				RemainingAdv[iStored] = Channel.ProjAdv;
				Stored[iStored++] = Projectile(A);
			}
		}
		else //Guided warheads?
			Advancer.RegisterAdvance( A);
	}
	return A;
}

event Tick( float DeltaTime)
{
	local int i, j;
	local float RemAdj;
	local Projectile P;
	local XC_ProjSimulator PJ;
	local Effects Trail;

	RemAdj = fClamp( DeltaTime / Level.TimeDilation, 0.01, 0.05) * Level.TimeDilation;

//	i=0;
	while ( i<iSimul )
	{
		if ( Simulators[i] == none || Simulators[i].bDeleteMe )
		{
			Simulators[i] = Simulators[--iSimul];
			Simulators[iSimul] = none;
			continue;
		}
		Simulators[i].SimTag = i;
		i++;
	}

	//Make sure lowest slot of new ones is candidate
	while ( (iHighest < ArrayCount(Stored)) && (Stored[iHighest] != none) && (Stored[iHighest].Instigator != Channel.LocalPlayer) )
		iHighest++;
	//Now move candidate upwards to replace non-candidates, compacting the block
	//RemainingAdv is identical in all cases!!
	for ( i=iHighest+1 ; i<iStored ; i++ )
		if ( (Stored[i] == none) || (Stored[i].Instigator != Channel.LocalPlayer) )
		{
			P = Stored[iHighest];
			Stored[iHighest++] = Stored[i];
			Stored[i] = P;
		}
	
	//Check the new ones (all have the player as instigator)
	for ( i=iHighest ; i<iStored ; i++ )
	{
		PJ = none;
		for ( j=0 ; j<iSimul ; j++ )
			Simulators[j].AssessProjectile( Stored[i], PJ);
		if ( PJ != none ) //Capture
		{
			PJ.Assimilate( Stored[i]);
			Simulators[PJ.SimTag] = Simulators[--iSimul];
			Simulators[iSimul] = none;
		}
		else //Not captured by a simulator, use element advancer instead!
		{
			if ( iTrailer < ArrayCount(PendingTrailers) )
				PendingTrailers[iTrailer++] = Stored[i];
			Advancer.RegisterAdvance( Stored[i] );
		}
		//In all cases we get rid of our projectile, let next loop cleanup this mess
		Stored[i] = none;
	}

	i=0;
	while ( i<iStored )
	{
		if ( Stored[i] == none || Stored[i].bDeleteMe )
		{
			REMOVE_ELEMENT:
			Stored[i] = Stored[--iStored];
			RemainingAdv[i] = RemainingAdv[iStored];
			Stored[iStored] = none;
			continue;
		}
		
		if ( RemainingAdv[i] <= 0 || Stored[i].Velocity == Vect(0,0,0) )
			Goto REMOVE_ELEMENT;
		if ( RemainingAdv[i] > RemAdj )
		{
			RemainingAdv[i] -= RemAdj;
			Stored[i].AutonomousPhysics( RemAdj);
		}
		else
		{
			Stored[i].AutonomousPhysics( RemainingAdv[i]);
			Goto REMOVE_ELEMENT;
		}
		i++;
	}
	iHighest = iStored;

	if ( iTrailer > 0 )
	{
		if ( PendingTrailers[i] != none && !PendingTrailers[i].bDeleteMe )
		{
			foreach PendingTrailers[i].ChildActors( class'Effects', Trail)
				if ( !Trail.bCollideActors && (Trail.Physics == PHYS_Trailer) )
					Advancer.RegisterTrailer( Trail);
		}
		for ( i=1 ; i<iTrailer ; i++ )
			PendingTrailers[i-1] = PendingTrailers[i];
		PendingTrailers[--iTrailer] = none;
	}
	
/*	For ( i=0 ; i<iStored ; i++ )
	{
		if ( Stored[i] == none )
			continue;
		Remaining = Channel.ProjAdv;
		while ( Remaining > 0 )
		{
			Stored[i].AutonomousPhysics( Channel.ProjAdv);
		}
		Stored[i] = none;
	}*/
}


defaultproperties
{
    ActorClass=class'Projectile'
    RemoteRole=ROLE_None
}