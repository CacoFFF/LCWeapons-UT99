//
// Clientside wrapper for swJumpPads
// Only affects the local player
//

class LC_SWJump expands Triggers;

var Teleporter MyPad;
var PlayerPawn LocalPlayer;

function Setup( Teleporter Other, PlayerPawn P)
{
	Other.SetCollision( false, false, false);
	SetCollisionSize( Other.CollisionRadius, Other.CollisionHeight );
	MyPad = Other;
	LocalPlayer = P;
}

event Touch(Actor other)
{
	if ( Other == LocalPlayer && LocalPlayer.bCanTeleport )
	{
		PendingTouch = LocalPlayer.PendingTouch;
		LocalPlayer.PendingTouch = self;
	}
}

event PostTouch(Actor other)
{
	if ( Other == LocalPlayer )
	{
		MyPad.Role = ROLE_Authority;
		MyPad.PostTouch( Other);
		MyPad.SetPropertyText("JumpActor","");
	}
}

defaultproperties
{
	bCollideActors=True
}