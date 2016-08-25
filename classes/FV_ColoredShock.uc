class FV_ColoredShock expands Mutator;


function AddMutator(Mutator M)
{
	if ( LCMutator(M) != none )
	{
		SetTimer( 1, false);
		LCMutator(M).bTeamShock = true;
	}


	if ( NextMutator == None )
		NextMutator = M;
	else
		NextMutator.AddMutator(M);
}

event Timer()
{
	local Mutator M;

	if ( Level.Game.BaseMutator == self )
		Level.Game.BaseMutator = NextMutator;
	else
	{
		For ( M=Level.Game.BaseMutator ; M.NextMutator!=none ; M=M.NextMutator )
			if ( M.NextMutator == self )
			{
				M.NextMutator = NextMutator;
				break;
			}
	}
	Destroy();
}