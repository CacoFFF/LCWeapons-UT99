//*************************************************
//**** ZP Shock Rifle team color data
//**** Made by Higor
//*************************************************

#exec OBJ LOAD FILE=..\Textures\FV_ColorShock.utx

class FVTeamShock expands Object;


var Texture BeamTex[5];
var Texture ExploSkin[5];
var Texture sExploSkin[5];
var Texture mSkin[5];
var Texture mSkin3[5];
var Texture mSkin4[5];
var class<Projectile> tProjs[5];

static function SetStaticSkins( ShockRifle S)
{
	local int Team;
	Team = Class'LCStatics'.static.FVOwnerTeam( S);
	S.MultiSkins[1] = default.mSkin[ Team ];
	S.MultiSkins[7] = S.MultiSkins[1]; //PLACEHOLDER!!!
	S.MultiSkins[2] = default.mSkin3[ Team ];
	S.MultiSkins[3] = default.mSkin4[ Team ];
	S.AltProjectileClass = default.tProjs[ Team ];
}

static function AsmdPR_SetStaticProj( LCAsmdPulseRifle S)
{
	local int Team;
	Team = Class'LCStatics'.static.FVOwnerTeam( S);
	S.AltProjectileClass = default.tProjs[ Team ];
}

defaultproperties
{
	BeamTex(0)=Texture'FV_ColorShock.shockbeam_0'
	BeamTex(1)=Texture'FV_ColorShock.shockbeam_1'
	BeamTex(2)=Texture'FV_ColorShock.shockbeam_2'
	BeamTex(3)=Texture'FV_ColorShock.shockbeam_3'
	BeamTex(4)=Texture'FV_ColorShock.shockbeam_255'
	ExploSkin(0)=Texture'FV_ColorShock.ASaRing_0'
	ExploSkin(1)=Texture'FV_ColorShock.ASaRing_1'
	ExploSkin(2)=Texture'FV_ColorShock.ASaRing_2'
	ExploSkin(3)=Texture'FV_ColorShock.ASaRing_3'
	ExploSkin(4)=Texture'FV_ColorShock.ASaRing_255'
	sExploSkin(0)=Texture'FV_ColorShock.pSuperRing_0'
	sExploSkin(1)=Texture'FV_ColorShock.pSuperRing_1'
	sExploSkin(2)=Texture'FV_ColorShock.pSuperRing_2'
	sExploSkin(3)=Texture'FV_ColorShock.pSuperRing_3'
	sExploSkin(4)=Texture'FV_ColorShock.pSuperRing_255'
	mSkin(0)=Texture'FV_ColorShock.ASMD_t_0'
	mSkin(1)=Texture'FV_ColorShock.ASMD_t_1'
	mSkin(2)=Texture'FV_ColorShock.ASMD_t_2'
	mSkin(3)=Texture'FV_ColorShock.ASMD_t_3'
	mSkin(4)=Texture'FV_ColorShock.ASMD_t_255'
	mSkin3(0)=Texture'FV_ColorShock.ASMD_t3_0'
	mSkin3(1)=Texture'FV_ColorShock.ASMD_t3_1'
	mSkin3(2)=Texture'FV_ColorShock.ASMD_t3_2'
	mSkin3(3)=Texture'FV_ColorShock.ASMD_t3_3'
	mSkin3(4)=Texture'FV_ColorShock.ASMD_t3_255'
	mSkin4(0)=Texture'FV_ColorShock.ASMD_t4_0'
	mSkin4(1)=Texture'FV_ColorShock.ASMD_t4_1'
	mSkin4(2)=Texture'FV_ColorShock.ASMD_t4_2'
	mSkin4(3)=Texture'FV_ColorShock.ASMD_t4_3'
	mSkin4(4)=Texture'FV_ColorShock.ASMD_t4_255'
	tProjs(0)=Class'FV_RedShockProj'
	tProjs(1)=Class'FV_BlueShockProj'
	tProjs(2)=Class'FV_GreenShockProj'
	tProjs(3)=Class'FV_GoldShockProj'
	tProjs(4)=Class'FV_NoteamShockProj'
}
