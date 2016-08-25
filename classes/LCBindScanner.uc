class LCBindScanner expands Actor;

var byte CurIdx;
var PlayerPawn LocalPlayer;
var bool bNoBinds;

auto state Scanning
{
Begin:
	While ( LocalPlayer == none )
	{
		FindLocal();
		Sleep(0.1);
	}
	if ( LocalPlayer.IsA('bbPlayer') )
	{
		bNoBinds = true;
//		Destroy();
//		Stop;
	}
	While ( CurIdX != 255 )
	{
		if ( bNoBinds )
			CleanBind( CurIdx);
		else
			AnalyseBind( CurIdx);
		CurIdx++;
		Sleep(0);
	}
	Destroy();
}

function CleanBind( byte Idx)
{
	local string KeyName, KeyBind, Parms, Processed;
	local int i;
	local bool bSave;

	KeyName = LocalPlayer.ConsoleCommand("KeyName "$ Idx);
	KeyBind = LocalPlayer.ConsoleCommand("KeyBinding "$ KeyName);

	//This bind contains Mutate and Getweapon
	if ( (InStr(Caps(KeyBind), " GETWEAPON ") >= 0) && (InStr(Caps(KeyBind), "MUTATE ") >= 0) )
	{
		While ( KeyBind != "" )
		{
			Parms = class'LCStatics'.static.NextParameter( KeyBind, "|");
			ClearSpaces( Parms);
			if ( Left(Parms,17) ~= "mutate getweapon " )
				bSave = true;
			else
				Processed = Processed $ "|" $ Parms;
		}
		if ( bSave )
		{
			Processed = Mid( Processed, 1);
			LocalPlayer.ConsoleCommand("Set Input"@ KeyName @ Processed);
		}
	}
}

function AnalyseBind( byte Idx)
{
	local string KeyName, KeyBind, Parms, Processed, Saved[16];
	local bool bSave, bAppend;
	local byte bEdited;
	local int i, j, k;

	KeyName = LocalPlayer.ConsoleCommand("KeyName "$ Idx);
	KeyBind = LocalPlayer.ConsoleCommand("KeyBinding "$ KeyName);
	//Weapon bind here
	if ( InStr(CAPS(KeyBind), "WEAPON") >= 0 )
	{
//		LocalPlayer.ClientMessage("Found Weapon bind: "$ KeyBind $ " on " $ KeyName );
		While ( KeyBind != "" ) //Dissasemble Bind
			Saved[j++] = class'LCStatics'.static.NextParameter( KeyBind, "|");
		For ( i=0 ; i<j ; i++ )
		{
			Parms = GetTheWord( Saved[i]);
			if ( Parms ~= "GetWeapon" )
			{
				Processed = MutatedVersion( GetTheWord2( Saved[i]) );
//				LocalPlayer.ClientMessage(">> Processing "$ Saved[i] $ " >> "$ Processed );
				if ( Processed == "" )
					continue;
				bAppend = true;
				For ( k=0 ; k<j ; k++ )
				{
					if ( (GetTheWord(Saved[k]) ~= "Mutate") && (GetTheWord2(Saved[k]) ~= "GetWeapon") && (GetTheWord3(Saved[k]) ~= Processed) )
					{
						bAppend = false;
						break;
					}
				}
				if ( !bAppend )
					continue;
				bSave = true;
				For ( k=j ; k>i ; k-- )
					Saved[k] = Saved[k-1];
				j++;
				Saved[i++] = "Mutate GetWeapon "$Processed;
			}
		}		
		if ( bSave )
		{
			For ( i=0 ; i<j ; i++ )
				KeyBind = KeyBind $ "|" $ Saved[i];
			KeyBind = Mid(KeyBind,1);
			LocalPlayer.ConsoleCommand("Set Input"@ KeyName @ KeyBind);
		}
	}
}

function string MutatedVersion( string WeapName)
{
	if ( InStr(Caps(WeapName),"SNIPERRIFLE") >= 0 )
		return "zp_sn";
	if ( InStr(Caps(WeapName),"SHOCKRIFLE") >= 0 )
		return "zp_sh";
	if ( InStr(Caps(WeapName),"ENFORCER") >= 0 )
		return "zp_e";
	if ( InStr(Caps(WeapName),"ASMDPULSERIFLE") >= 0 )
		return "lc_apr";
	if ( InStr(Caps(WeapName),"MINIGUN") >= 0 )
		return "lc_m";
	if ( InStr(Caps(WeapName),"SIEGEINSTAGIBRIFLE") >= 0 )
		return "lc_sir";
	if ( InStr(Caps(WeapName),"IMPACTHAMMER") >= 0 )
		return "lc_ih";
}

function FindLocal()
{
	local PlayerPawn P;

	ForEach AllActors (class'PlayerPawn', P)
	{
		if ( ViewPort(P.Player) != none )
		{
			LocalPlayer = P;
			return;
		}
	}
}


static function ClearSpaces(out string Text)
{
	while ( InStr(Text," ") == 0 )
		Text = Mid(Text,1);
}
static function string GetTheWord(string Text)
{
	local int i;
	ClearSpaces(Text);
	i = InStr( Text, " ");
	if ( i < 0 )
		return Text;
	return Left(Text,i);
}
static function string GetTheWord2( string Text)
{
	local int i;

	ClearSpaces(Text);
	i = InStr( Text, " ");
	if ( i < 0 )
		return "";
	Text = Mid( Text, i);
	ClearSpaces(Text);
	return GetTheWord(Text);
}
static function string GetTheWord3( string Text)
{
	local int i;

	ClearSpaces(Text);
	i = InStr( Text, " ");
	if ( i < 0 )
		return "";
	Text = Mid( Text, i);
	ClearSpaces(Text);
	return GetTheWord2(Text);
}

defaultproperties
{
	bNetTemporary=False
	bHidden=True
	bAlwaysRelevant=False
	NetPriority=2
	LifeSpan=50
	RemoteRole=ROLE_None
	CurIdx=1
}