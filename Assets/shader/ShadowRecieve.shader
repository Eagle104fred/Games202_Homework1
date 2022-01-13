Shader "Custom/ShadowRecieve"
{

    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
    }
    SubShader
    {
    Tags { "RenderType"="Opaque" }
        Pass
        {
        

        CGPROGRAM
        #pragma vertex vert
		#pragma fragment frag
		// make fog work
		#pragma multi_compile_fog
		#pragma enable_d3d11_debug_symbols

		#include "UnityCG.cginc"

        struct appdata{
            float4 vertex : POSITION;
            float2 shadowUV : TEXCOORD0;

        };

        struct v2f
        {
            float2 uv:TEXCOORD0;
            UNITY_FOG_COORDS(1)
            float4 vertex : SV_POSITION;
            float4 shadowPos:TEXCOORD1;
        };

        sampler2D _MainTex;
        float4 _MainTex_ST;
        sampler2D _ShadowMap;
        float4x4 _ShadowLauncherMatrix;
        float3 _ShadowLauncherParam;
        float4 _BaseColor;


        /*-------自定义阴影-------*/
        #define EPS 1e-3
        //采样密度
        #define NUM_SAMPLES 150
        #define NUM_RINGS 10
        #define pi 3.141592653589793
        #define pi2 6.283185307179586
        
        float2 poissonDisk[NUM_SAMPLES];

        float rand_2to1(float2 uv )
        { 
          // 0 - 1
	        const float a = 12.9898, b = 78.233, c = 43758.5453;
	        float dt = dot( uv.xy, float2( a,b ) ), sn = fmod( dt, pi );
	        return frac(sin(sn) * c);
        }
        void poissonDiskSamples(const in float2 randomSeed )
        {
            float ANGLE_STEP = pi2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
            float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );
            float angle = rand_2to1( randomSeed ) * pi2;
            float radius = INV_NUM_SAMPLES;
            float radiusStep = radius;

            for( int i = 0; i < NUM_SAMPLES; i ++ )
            {
                poissonDisk[i] = float2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
                radius += radiusStep;
                angle += ANGLE_STEP;
            }
        }
        //软阴影
        float _findBlocker(float4 shadowPos)
        {
            float4 shadowCoord = shadowPos;
            poissonDiskSamples(shadowCoord.xy);

            float textureSize = 400.0;

            //注意 block 的步长要比 PCSS 中的 PCF 步长长一些，这样生成的软阴影会更加柔和
            float filterStride = 20.0;
            float filterRange = 1.0 / textureSize * filterStride;

            int shadowCount = 0;
            float blockDepth = 0.0;
            for(int i=0;i<NUM_SAMPLES;i++)
            {
                float2 sampleCoord = poissonDisk[i]*filterRange+shadowCoord.xy;
                float shadow = tex2D(_ShadowMap,sampleCoord);
                float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
                if(depth+0.01<shadowCoord.z)
                {
                    blockDepth+=depth;
                    shadowCount++; //计算未被遮挡的采样点数量
                }
            }
            if(shadowCount==NUM_SAMPLES)return 3.0;
            return blockDepth/float(shadowCount);
            
        }
        float PCSS(v2f i)
        {
            float4 shadowCoord = i.shadowPos;
            // STEP 1: avgblocker depth              
            float zBlocker = _findBlocker(shadowCoord);
            //if(zBlocker<EPS)return 0.0;
            //if(zBlocker>1.0)return 1.0;

            // STEP 2: penumbra size
            float W_LIGHT=1.0;
            float wPenumbra = (shadowCoord.z-zBlocker) * W_LIGHT / zBlocker;

            // STEP 3: PCF
            float textureSize = 1024.0;
            float filterStride = 10.0;
            float filterRange = filterStride/textureSize*wPenumbra;//
            int unBlockCount = 0;
            float shadowAlpha=0.0;
            for(int i=0;i<NUM_SAMPLES;i++)
            {
                float2 sampleCoord = poissonDisk[i]*filterRange+shadowCoord.xy;
                
                float shadow = tex2D(_ShadowMap,sampleCoord);
                shadowAlpha = shadow.r;
                float2 clipalpha = saturate((0.5-abs(sampleCoord - 0.5))*20);//限定在0-1之间
                shadowAlpha *= clipalpha.x * clipalpha.y;//阴影区域裁剪
                float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
                if(depth+0.005<shadowCoord.z)
                {
                    unBlockCount++; //计算未被遮挡的采样点数量
                }

            }
            return float(unBlockCount)/float(NUM_SAMPLES)*shadowAlpha;
        }

        float PCF(v2f i)
        {
            float4 shadowCoord = i.shadowPos;
            poissonDiskSamples(shadowCoord.xy);

            float textureSize = 2048.0;
            float filterStride = 5.0;
            float filterRange = filterStride/textureSize;
            int unBlockCount = 0;
            float shadowAlpha=0.0;
            for(int i=0;i<NUM_SAMPLES;i++)
            {
                float2 sampleCoord = poissonDisk[i]*filterRange+shadowCoord.xy;
                
                float shadow = tex2D(_ShadowMap,sampleCoord);
                shadowAlpha = shadow.r;
                float2 clipalpha = saturate((0.5-abs(sampleCoord - 0.5))*20);//限定在0-1之间
                shadowAlpha *= clipalpha.x * clipalpha.y;//阴影区域裁剪
                float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
                if(depth+0.005<shadowCoord.z)
                {
                    unBlockCount++; //计算未被遮挡的采样点数量
                }

            }
            return float(unBlockCount)/float(NUM_SAMPLES)*shadowAlpha;
        }
        //基于shadowmap的硬阴影
        float HardShadow(v2f i)
        {
            float4 shadow = tex2Dproj(_ShadowMap,i.shadowPos);//拿到坐标在光源场景下的深度
            float shadowAlpha = shadow.r;//拿到深度值
            float2 clipalpha = saturate((0.5-abs(i.shadowPos.xy - 0.5))*20);//限定在0-1之间
            shadowAlpha *= clipalpha.x * clipalpha.y;

            float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
            shadowAlpha*=step(depth,i.shadowPos.z);//如果depth<shadowPos就没有被遮挡
            return shadowAlpha;
        }




        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);//MVP矩阵
            float4 worldPos = mul(unity_ObjectToWorld,v.vertex);//模型空间转换到世界空间,相当于进行了model矩阵
            float4 shadowPos = mul(_ShadowLauncherMatrix,worldPos);//从世界坐标到光源坐标
            shadowPos.xy = (shadowPos.xy/_ShadowLauncherParam.x+1)/2;//再将-1,1范围转换到0,1范围用于读取shadowMap中的深度
            shadowPos.z = (shadowPos.z / shadowPos.w - _ShadowLauncherParam.y)  / (_ShadowLauncherParam.z - _ShadowLauncherParam.y);//初始化深度
            

            o.shadowPos = shadowPos;
            o.uv = TRANSFORM_TEX(v.shadowUV, _MainTex);//读取uv
			//UNITY_TRANSFER_FOG(o,o.vertex);
            return o;
        }      
        float4 frag(v2f i):SV_Target
        {
            float4 color = tex2D(_MainTex,i.uv);//拿到主颜色

            float shadowAlpha=0.0;
            //shadowAlpha = HardShadow(i);  
            //shadowAlpha = PCF(i);  
            shadowAlpha = PCSS(i);   


            color.rgb *=(1-shadowAlpha)*_BaseColor.rgb;//阴影能见度加上材质本身的颜色
            
            //UNITY_APPLY_FOG(i.fogCoord,color);
            return color;
        }

  

        ENDCG
        }
    }
}
