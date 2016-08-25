//Render weapon stuff in PURE based games
class LCWeaponHUD extends Mutator;

var PlayerPawn LocalPlayer;

simulated event PostBeginPlay()
{
	SetTimer( 5, false); //Wait for PURE to replace stuff
}

simulated event Timer()
{
	//Hud was replaced
	if ( InStr(caps(string(LocalPlayer.myHud)),"PURE") > 0 )
	{
		NextHUDMutator = LocalPlayer.myHud.HUDMutator;
		LocalPlayer.myHud.HUDMutator = self;
	}
	else
		Destroy();
}

simulated event PostRender (Canvas Canvas)
{
	if ( (LocalPlayer != None) && (LocalPlayer.Weapon != None) )
		LocalPlayer.Weapon.PostRender(Canvas);
}
