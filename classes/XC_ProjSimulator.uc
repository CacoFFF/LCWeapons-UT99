//=============================================================================
// XC_ProjSimulator.
// Locally simulate a projectile before it's been spawned by the server
//=============================================================================
class XC_ProjSimulator expands Projectile;

var vector SpawnedAt, InitialVelocity;
var class<Projectile> ExpectedProj;
var XC_CProjSN Notify;
var float ssPredict;
var float ssCounter;
var float CurScore;
var int SimTag; //Internal

event Tick( float DeltaTime)
{
	if ( (ssCounter -= DeltaTime) < (-0.30 * Level.TimeDilation) ) //Maximum error
	{
		Destroy();
		return;
	}
	if ( bHidden && (ssCounter <= ssPredict) )
		StartMoving();
}


function AssessProjectile( Projectile P, out XC_ProjSimulator PJ)
{
	if ( (ExpectedProj != None) && !ClassIsChildOf( P.Class, ExpectedProj) )
		return; //Assess any projectile if none expected
	CurScore = (2+VSize(SpawnedAt-P.Location)) * (2+VSize(InitialVelocity-P.Velocity)) * ssCounter * ssCounter;
//	Log( "LD="$VSize(SpawnedAt-P.Location)$", VD="$VSize(InitialVelocity-P.Velocity)$", T="$ssCounter$", Score="$CurScore );
	if ( CurScore < 5 && (PJ == none || (CurScore < PJ.CurScore)) )
		PJ = self; //Take this projectile
}

function Assimilate( Projectile P)
{
	local float Dist;
	local vector NewPos;
	
	if ( !bHidden ) //Don't even assimilate if I didn't start moving
	{
		Dist = VSize( Location - SpawnedAt);
		NewPos = P.Location + Normal(P.Velocity) * Dist;
		P.Velocity = Normal(P.Velocity) * VSize(Velocity);
		P.SetLocation(NewPos);
	}
	Destroy();
}

function SetupProj( class<Projectile> Proj)
{
	ExpectedProj = Proj;
	SetCollisionSize( Proj.default.CollisionRadius, Proj.default.CollisionHeight);
	SetCollision( false);
	Mesh = Proj.default.Mesh;
	Texture = Proj.default.Texture;
	Skin = Proj.default.Skin;
	Style = Proj.default.Style;
	Speed = Proj.default.Speed;
	MaxSpeed = Proj.default.MaxSpeed;
	DrawType = Proj.default.DrawType;
	DrawScale = Proj.default.DrawScale;
	ScaleGlow = Proj.default.ScaleGlow;
	InitialVelocity = Vector(Rotation) * Speed;

	//Stop here
	SetPhysics( PHYS_None);
	SpawnedAt = Location;
	bHidden = true;
}

function StartMoving()
{
	bHidden = false;
	Velocity = InitialVelocity;
	SetPhysics( ExpectedProj.default.Physics);
	SetCollision( true);
}
