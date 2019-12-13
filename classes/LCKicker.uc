//
// Clientside version of a kicker
// Only affects the local player
//

class LCKicker expands Triggers;

var vector KickVelocity;
var name KickedClasses;
var bool bKillVelocity;
var PlayerPawn LocalPlayer;

replication
{
	reliable if ( Role==ROLE_Authority )
		KickVelocity, bKillVelocity, KickedClasses;
}


function LCKicker ServerSetup( Kicker Other)
{
	Disable('Touch');
	SetCollisionSize(Other.CollisionHeight, Other.CollisionRadius);
	SetLocation( Other.Location);
	KickVelocity = Other.KickVelocity;
	bKillVelocity = Other.bKillVelocity;
	KickedClasses = Other.KickedClasses;
	return self;
}

simulated event PostNetBeginPlay()
{
	//UT v469 doesn't need LCKickers
	if ( int(Level.EngineVersion) >= 469 )
		LifeSpan = 0.1;
	SetCollision( True, False, False);
	SetTimer( 1, false);
}

simulated event Timer()
{
	local PlayerPawn P;
	ForEach AllActors (class'PlayerPawn', P)
	{
		if ( ViewPort(P.Player) != none )
		{
			LocalPlayer = P;
			break;
		}
	}
}


simulated event Touch(Actor other)
{
	if ( (Level.NetMode != NM_Client) || !Other.IsA(KickedClasses) )
		return;
	if ( Other == LocalPlayer )
	{
//		if ( !LocalPlayer.bUpdating && LocalPlayer.bCanTeleport )
//			LocalPlayer.PlaySound(BoostSound); //TRIGGER EVENT NOW!!
		if ( LocalPlayer.bCanTeleport )
		{
			PendingTouch = LocalPlayer.PendingTouch;
			LocalPlayer.PendingTouch = self;
		}
		return;
	}
	if ( !Other.bIsPawn && (Other.Role != ROLE_DumbProxy) )
	{
		PendingTouch = Other.PendingTouch;
		Other.PendingTouch = self;
	}
}

//Serverside Touch
simulated event PostTouch(Actor other)
{
	local bool bWasFalling;
	local vector Push;
	local float PMag;

//	if ( Other == LocalPlayer )
//	{
		bWasFalling = ( Other.Physics == PHYS_Falling );
		if ( bKillVelocity )
			Push = -1 * Other.Velocity;
		else
			Push.Z = -1 * Other.Velocity.Z;
		Push += KickVelocity;
		Other.SetPhysics(PHYS_Falling);
		Other.Velocity += Push;
//	}
}

defaultproperties
{
    bAlwaysRelevant=True
    bNetTemporary=True
    RemoteRole=ROLE_SimulatedProxy
    bCollideActors=False
}