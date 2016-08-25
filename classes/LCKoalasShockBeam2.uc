class LCKoalasShockBeam2 extends LCKoalasShockBeam;

var PlayerPawn LocalPlayer;

replication
{
	reliable if ( bNetInitial && ROLE==Role_Authority )
		LocalPlayer;
}

event PreBeginPlay()
{
	Super.PreBeginPlay();
	if ( !bDeleteMe )
		LocalPlayer = PlayerPawn(Owner);
}

simulated function PostNetBeginPlay()
{
	if ( ViewPort(LocalPlayer.Player) != none )
	{
		SetTimer(0,false);
		Destroy();
	}
}

defaultproperties
{
	bOwnerNoSee=True
}