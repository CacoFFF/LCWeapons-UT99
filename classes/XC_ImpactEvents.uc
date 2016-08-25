class XC_ImpactEvents expands Info;
 
var ViewPort Player;
var float PushDelta[2];
var vector Vel[2];
var int iPush;

var bool bNextDelta;
var SavedMove CurMove;
var int CurAdj;
var int OldAdj;

var float CurTimeSeconds;
var float AccMoveTimer;

event PostBeginPlay()
{
	local PlayerPawn P;
	ForEach AllActors( class'PlayerPawn', P)
		if ( ViewPort(P.Player) != none )
		{
			Player = ViewPort(P.Player);
			break;
		}
	SetLocation( vect(30100, 30100, 30100) );
}

event Tick( float DeltaTime)
{
	local int j;
	local SavedMove aMove;

	while ( (j<iPush) && (PushDelta[j] < Player.Actor.CurrentTimeStamp) )
		j++;
	if ( j > 0 )
		PopList(j);

	// Prepare player for next frame
	if ( iPush > 0 )
	{
		class'sg_TouchUtil'.static.SetTouch( Player.Actor, self);
		class'sg_TouchUtil'.static.SetTouch( self, Player.Actor);
	}
}

//This event doesn't appear to be called at all times, this makes it a problem
event UnTouch( Actor Other)
{
	local byte i;
	local int iC;

	if ( Other == Player.Actor && (iPush > 0) )
	{
		if ( !Player.Actor.bCanTeleport ) //ClientAdjustPosition
		{
			bNextDelta = true;
			CurAdj = 0;
			OldAdj = 0;
			CurTimeSeconds = Level.TimeSeconds;
			Player.Actor.MoveTimer = 0;
			CurMove = class'LCStatics'.static.FindMoveBeyond( Player.Actor, Player.Actor.CurrentTimeStamp);
		}
		else if ( Player.Actor.bUpdating ) //Mandatory
		{
			if ( bNextDelta && CurTimeSeconds != Level.TimeSeconds ) //Activator, frame passed and client is adjusting position
			{
				bNextDelta = false;
				AccMoveTimer = 0;
				CurTimeSeconds = Level.TimeSeconds;
			}
			if ( CurMove != none && CurTimeSeconds == Level.TimeSeconds )
			{
				AccMoveTimer -= CurMove.Delta;
				while ( Player.Actor.MoveTimer < AccMoveTimer )
				{
//					Log( "Skipping:" @ CurMove.Name @ Player.Actor.MoveTimer @ AccMoveTimer );
					CurMove = CurMove.NextMove;
					if ( CurMove == none )
						Goto NOPE;
					AccMoveTimer -= CurMove.Delta;
				}
				if ( CurAdj < iPush )
				{
//					Log("DEBUG_3_HERE: "@CurMove.Name@CurMove.TimeStamp@"vs PushDelta["$CurAdj$"]="$PushDelta[CurAdj]@"Timer:"@AccMoveTimer);
					if ( CurMove.TimeStamp >= PushDelta[CurAdj] )
					{
						PendingTouch = none; //Safety cleanup
						PendingTouch = Player.Actor.PendingTouch; //Buffer touch list
						Player.Actor.PendingTouch = self; //Add to first in list
						CurAdj++;
					}
				}
				CurMove = CurMove.NextMove;
				NOPE:
			}
		}
		class'sg_TouchUtil'.static.SetTouch( Other, self);
		class'sg_TouchUtil'.static.SetTouch( self, Other);
	}
}

function AddNewPush( vector PushVel)
{
	local info I;

	if ( Level.NetMode != NM_Client )
		return;

	if ( iPush < 2 )
	{
		PushDelta[iPush] = Level.TimeSeconds;
		Vel[iPush] = PushVel;
		iPush++;
	}
}

event PostTouch( Actor Other)
{
	local int i;
	if ( Other != Player.Actor )
		return;
	For ( i=OldAdj ; i<=CurAdj ; i++ )
	{
		Player.Actor.Velocity += Vel[i];
		if ( Player.Actor.Physics == PHYS_Walking )
			Player.Actor.SetPhysics( PHYS_Falling);
	}
	OldAdj = CurAdj;

	//Allow multiple pendingtouch, since i'm not doing a physics alteration, i will manually call it here
	if ( PendingTouch != none && PendingTouch != self )
	{
		Player.Actor.PendingTouch = PendingTouch;
		PendingTouch.PostTouch( Player.Actor);
		PendingTouch = none;
	}
}

function PopList( int PopCount)
{
	local int i, j;

	assert( iPush > 0 );
	assert( PopCount > 0);
	assert( PopCount <= iPush);
	iPush -= PopCount;
	while ( i < iPush )
	{
		PushDelta[i] = PushDelta[i+PopCount];
		Vel[i] = Vel[i+PopCount];
		i++;
	}
}

defaultproperties
{
    RemoteRole=ROLE_None
    bCollideWorld=False
    bHidden=True
}
