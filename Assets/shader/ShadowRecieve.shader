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


        /*-------�Զ�����Ӱ-------*/
        #define EPS 1e-3
        //�����ܶ�
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
        //����Ӱ
        float _findBlocker(float4 shadowPos)
        {
            float4 shadowCoord = shadowPos;
            poissonDiskSamples(shadowCoord.xy);

            float textureSize = 400.0;

            //ע�� block �Ĳ���Ҫ�� PCSS �е� PCF ������һЩ���������ɵ�����Ӱ��������
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
                    shadowCount++; //����δ���ڵ��Ĳ���������
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
                float2 clipalpha = saturate((0.5-abs(sampleCoord - 0.5))*20);//�޶���0-1֮��
                shadowAlpha *= clipalpha.x * clipalpha.y;//��Ӱ����ü�
                float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
                if(depth+0.005<shadowCoord.z)
                {
                    unBlockCount++; //����δ���ڵ��Ĳ���������
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
                float2 clipalpha = saturate((0.5-abs(sampleCoord - 0.5))*20);//�޶���0-1֮��
                shadowAlpha *= clipalpha.x * clipalpha.y;//��Ӱ����ü�
                float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
                if(depth+0.005<shadowCoord.z)
                {
                    unBlockCount++; //����δ���ڵ��Ĳ���������
                }

            }
            return float(unBlockCount)/float(NUM_SAMPLES)*shadowAlpha;
        }
        //����shadowmap��Ӳ��Ӱ
        float HardShadow(v2f i)
        {
            float4 shadow = tex2Dproj(_ShadowMap,i.shadowPos);//�õ������ڹ�Դ�����µ����
            float shadowAlpha = shadow.r;//�õ����ֵ
            float2 clipalpha = saturate((0.5-abs(i.shadowPos.xy - 0.5))*20);//�޶���0-1֮��
            shadowAlpha *= clipalpha.x * clipalpha.y;

            float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
            shadowAlpha*=step(depth,i.shadowPos.z);//���depth<shadowPos��û�б��ڵ�
            return shadowAlpha;
        }




        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);//MVP����
            float4 worldPos = mul(unity_ObjectToWorld,v.vertex);//ģ�Ϳռ�ת��������ռ�,�൱�ڽ�����model����
            float4 shadowPos = mul(_ShadowLauncherMatrix,worldPos);//���������굽��Դ����
            shadowPos.xy = (shadowPos.xy/_ShadowLauncherParam.x+1)/2;//�ٽ�-1,1��Χת����0,1��Χ���ڶ�ȡshadowMap�е����
            shadowPos.z = (shadowPos.z / shadowPos.w - _ShadowLauncherParam.y)  / (_ShadowLauncherParam.z - _ShadowLauncherParam.y);//��ʼ�����
            

            o.shadowPos = shadowPos;
            o.uv = TRANSFORM_TEX(v.shadowUV, _MainTex);//��ȡuv
			//UNITY_TRANSFER_FOG(o,o.vertex);
            return o;
        }      
        float4 frag(v2f i):SV_Target
        {
            float4 color = tex2D(_MainTex,i.uv);//�õ�����ɫ

            float shadowAlpha=0.0;
            //shadowAlpha = HardShadow(i);  
            //shadowAlpha = PCF(i);  
            shadowAlpha = PCSS(i);   


            color.rgb *=(1-shadowAlpha)*_BaseColor.rgb;//��Ӱ�ܼ��ȼ��ϲ��ʱ������ɫ
            
            //UNITY_APPLY_FOG(i.fogCoord,color);
            return color;
        }

  

        ENDCG
        }
    }
}
