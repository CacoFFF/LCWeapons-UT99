class FV_AdaptiveBeam expands ShockBeam;

var bool bIsLC;

replication
{
	reliable if ( bNetOwner && (Role==ROLE_Authority) )
		bIsLC;
}

simulated event PostNetBeginPlay()
{
	//Texture=None causes a crash
	if ( (bIsLC && (Owner != None) && (Owner.Role == ROLE_AutonomousProxy)) || (Texture == None) )
	{
		bHidden = true;
		SetTimer( 0, false);
		LifeSpan = 0.001;
		LightType = LT_None;
	}
}

simulated function Timer()
{
	local ShockBeam r;
	
	if ( NumPuffs > 0 )
	{
		r = Spawn(class'FV_AdaptiveBeam',,,Location+MoveAmount);
		r.Texture = Texture;
		r.Skin = Skin;
		r.Mesh = Mesh;
		r.Style = Style;
		r.DrawScale = DrawScale;
		r.RemoteRole = ROLE_None;
		r.NumPuffs = NumPuffs - 1;
		r.MoveAmount = MoveAmount;
	}
}

simulated function AdaptFrom( class<Effects> Other)
{
	if ( Other.default.Texture != None )
		Texture = Other.default.Texture;
	Skin = Other.default.Skin;
	Mesh = Other.default.Mesh;
	Style = Other.default.Style;
	DrawScale = Other.default.DrawScale;
}
