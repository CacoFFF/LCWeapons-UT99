class XC_CEffectsSN expands SpawnNotify;

var XC_CompensatorChannel Channel;
var XC_ElementAdvancer Advancer;
var Actor LastTrailer;

function Setup( XC_CompensatorChannel COwner, XC_ElementAdvancer EAdv)
{
	Channel = COwner;
	Advancer = EAdv;
}

/** Spawn Notification
 *
 * Owner (remote actor) is not yet set, so we need to defer checking until after UChannel::ReceivedBunch
 * Also, even if the owner is set (client authoritative), the owner/instigator of the owner may be a remote actor!!!
 *
 * Deferred check does not need to happen on next frame, but simply the entire server data is processed.
 * So we can hold a single reference and process it when the next effect has been has been spawned.
 *
 * TODO: Reject conditions match 100%, but not all of the 'accepted' trailers may have an owner registered in the element advancer.
 * Find a way to apply a secondary reject without causing lags!
*/

event Actor SpawnNotification( Actor A)
{
	ProcessLastTrailer();
	if ( (A.Physics == PHYS_Trailer) && !ProcessTrailer(A) )
	{
		LastTrailer = A;
		Enable('Tick');
	}
	return A;
}

//If trailer fails to process, try again next tick (or until another trailer overrides it)
event Tick( float DeltaTime)
{
	ProcessLastTrailer();
}

function ProcessLastTrailer()
{
	if ( (LastTrailer != None) && ProcessTrailer( LastTrailer) )
	{
		LastTrailer = None;
		Disable('Tick');
	}
}


function bool ProcessTrailer( Actor Trailer)
{
	local Actor Master;

	// Defer check for later
	Master = Trailer.Owner;
	if ( Master == None )
		return false;
		
	// Attached directly to Pawn
	if ( Pawn( Master) != None )
	{
		if ( Master != Channel.LocalPlayer )
			Advancer.RegisterTrailer( Trailer);
	}
	// Attached to an autonomous viewtarget (Warhead)
	else if ( Master.Role == ROLE_AutonomousProxy )
	{
	}
	// Attached to something else (Projectile, etc)
	else if ( Projectile( Master) != None )
	{
		if ( (Master.Instigator == Channel.LocalPlayer) || (Master.Owner == Channel.LocalPlayer) )
		{
			// Register trailer if projectile visible and owned by local player
			if ( Master.FastTrace( Channel.LocalPlayer.Location + vect(0,0,1) * Channel.LocalPlayer.EyeHeight) )
				Advancer.RegisterTrailer( Trailer);
		}
		else if ( (Master.LifeSpan == Master.default.LifeSpan) && (Master.LifeSpan > 0)
		&& (Master.Instigator == None) && (Master.Owner == None) ) //Defer if projectile has no owner/instigator during spawn frame
			return false;
	}
	return true;
}


defaultproperties
{
    ActorClass=class'Effects'
    RemoteRole=ROLE_None
}