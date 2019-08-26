class XC_ClientSettings expands Object
	config
	perobjectconfig;

	
var() config bool bUseLagCompensation;
var() config int ForcePredictionCap;
var() config bool bHighFidelityMode;


defaultproperties
{
	bUseLagCompensation=True
	ForcePredictionCap=-1
}
