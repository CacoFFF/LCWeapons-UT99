//=============================================================================
// ECM_ImpactPush.
// ECM Element containing a fixed velocity push event.
// TODO: Move to base ECM
//=============================================================================
class ECM_ImpactPush expands ECM_Element;

var float PushTimeStamp;
var vector PushVelocity;


event Tick( float DeltaTime)
{
	if ( ECM == None || ECM.LocalPlayer == None )
		Error( "Bad client ECM");
		
	if ( ECM.LocalPlayer.CurrentTimeStamp >= PushTimeStamp )
	{
		bActive = false;
		Destroy();
	}
}

function ClientUpdatePosition( PlayerPawn Client, SavedMove CurrentMove)
{
	local float NextTimeStamp;

	if ( CurrentMove.NextMove != None )
		NextTimeStamp = CurrentMove.NextMove.TimeStamp;
	else
		NextTimeStamp = Level.TimeSeconds;
		
	if ( (PushTimeStamp >= CurrentMove.TimeStamp) && (PushTimeStamp < NextTimeStamp) )
		ProcessPush( Client);
}

function SetupPush( vector NewPushVel)
{
	PushTimeStamp = Level.TimeSeconds;
	PushVelocity = NewPushVel;
	ProcessPush( ECM.LocalPlayer);
}

function ProcessPush( PlayerPawn Client)
{
	if ( Client.Physics == PHYS_Walking )
		Client.SetPhysics( PHYS_Falling);
	Client.Velocity += PushVelocity;
}



defaultproperties
{
	bActive=True
}
