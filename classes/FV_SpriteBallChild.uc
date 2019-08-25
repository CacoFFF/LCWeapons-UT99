class FV_SpriteBallChild expands FV_SpriteBallExplosion;


function PostBeginPlay()
{
	Texture = SpriteAnim[Rand(5)];
	DrawScale = FRand()*0.5+0.9;
}



defaultproperties
{
     bHighDetail=True
     LightType=LT_None
     LightEffect=LE_None
     SpriteAnim(3)=Texture'Botpack.UT_Explosions.Exp5_a00'
     SpriteAnim(4)=Texture'Botpack.UT_Explosions.Exp4_a00'
     DrawScale=1.200000
	 RemoteRole=ROLE_None
}
