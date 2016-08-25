class FV_AdaptiveBeam expands ShockBeam;

simulated function Timer()
{
	local ShockBeam r;
	
	if (NumPuffs>0)
	{
		r = Spawn(class'FV_AdaptiveBeam',,,Location+MoveAmount);
		r.Texture = Texture;
		r.Skin = Skin;
		r.Mesh = Mesh;
		r.Style = Style;
		r.DrawScale = DrawScale;
		r.RemoteRole = ROLE_None;
		r.NumPuffs = NumPuffs -1;
		r.MoveAmount = MoveAmount;
	}
}
