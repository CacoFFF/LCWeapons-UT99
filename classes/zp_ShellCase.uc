//================================================================================
// zp_ShellCase.
// Higor, actually is not copy. This one autodeletes too
//================================================================================
class zp_ShellCase expands UT_ShellCase;
/*
simulated function PostBeginPlay()
{
	if ( Owner != none && Owner.Role == ROLE_AutonomousProxy )
	{}//	Destroy();
	else
		Super.PostBeginPlay();
}
*/

defaultproperties
{
    bOwnerNoSee=True
}
