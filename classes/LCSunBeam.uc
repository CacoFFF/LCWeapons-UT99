//================================================================================
//================================================================================
class LCSunBeam expands LCShockBeam2;

var bool bTexLoaded;

simulated function Timer()
{
	local ShockBeam r;

	if ( (Owner != None) && (Owner.Role == 3) )
		return;
	
	if (NumPuffs>0)
	{
		r = Spawn(class'LCSunBeam',,,Location+MoveAmount);
		r.RemoteRole = ROLE_None;
		r.NumPuffs = NumPuffs -1;
		r.MoveAmount = MoveAmount;
	}
}
