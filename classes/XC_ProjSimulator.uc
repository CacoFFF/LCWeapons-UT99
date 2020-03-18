//=============================================================================
// XC_ProjSimulator.
// Locally simulate a projectile before it's been spawned by the server
//=============================================================================
class XC_ProjSimulator expands Projectile;

var XC_CProjSN Notify;
var XC_ProjSimulator NextSimulator;
var vector SpawnedAt, InitialVelocity;
var class<Projectile> ExpectedProj;
var float ssPredict;
var float ssCounter;
var float CurScore;

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

function AssessProjectile( Projectile P, out XC_ProjSimulator BestSim)
{
	// Assess any projectile if none expected
	if ( (ExpectedProj != None) && !ClassIsChildOf( P.Class, ExpectedProj) )
		return; 
		
	// Asses by position
	CurScore 
	= (2+VSize(SpawnedAt-P.Location))
	* (1+FMax(VSize(InitialVelocity-P.Velocity),1)) //Velocity may have an error of up to 1 unit, make up for it.
	* ssCounter * ssCounter;
//	Log( "LD="$VSize(SpawnedAt-P.Location)$", VD="$VSize(InitialVelocity-P.Velocity)$", T="$ssCounter$", Score="$CurScore );
	if ( CurScore < 5 && (BestSim == none || (CurScore < BestSim.CurScore)) )
		BestSim = self; //Take this simulator
}

function AssesProjectileNoCheck( Projectile P, out XC_ProjSimulator BestSim)
{
	// Assess any projectile if none expected
	if ( (ExpectedProj != None) && !ClassIsChildOf( P.Class, ExpectedProj) )
		return; 
		
	// It makes sense that a recently spawned projectile is associated with the last dummy
	BestSim = self;
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

event Destroyed()
{
	local XC_ProjSimulator Sim;
	
	if ( Notify == None )
		return;
		
	if ( Notify.SimulatorList == self )
		Notify.SimulatorList = NextSimulator;
	else
	{
		For ( Sim=Notify.SimulatorList ; Sim!=None ; Sim=Sim.NextSimulator )
			if ( Sim.NextSimulator == self )
			{
				Sim.NextSimulator = NextSimulator;
				break;
			}
	}
}

defaultproperties
{
    Damage=-1
}