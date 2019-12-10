//
//  Base position holder actor, designed for lag compensation
/////////////////////////////////////////////////////////////
class XC_PosList expands Info;

var XC_LagCompensation Mutator;
var vector ActorSphere;



function int FindTopSlot( float Delayed);

//Fix pause
function CorrectTimeStamp( float Offset);


// Quick reject of whether a line can hit the bounding sphere of the compensated actor
function bool CanHit( vector Start, vector OldPos, vector X, vector Y, vector Z)
{
	OldPos -= Start;
	if ( OldPos dot X < 0 )
		return false;
	X.X = 0;
	X.Y = OldPos dot Y;
	X.Z = OldPos dot Z;
	return VSize(X) <= VSize(ActorSphere);
}
