Shader "Custom/My3s2"
{
    Properties
    {
        [Header(Texture)]
        _MainTex ("Main Tex", 2D) = "white" { }//模型贴图
       
    }
    SubShader
    {
       Tags{"RenderType" = "Openge"}
       Pass{
            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct a2v
            {
                float4 vertex:POSITION;
                float3 normal:NORMAL;
                float2 uv:TEXCOORD0;
            };
            struct v2f
            {
                float4 pos:SV_POSITION;
                float3 normal:TEXCOORD0;
                float2 uv:TEXCOORD1;
                float3 worldPos:TEXCOORD2;
            };
            sampler2D _MainTex;
            float4 _MainTex_ST;// TRANSFORM_TEX需要调用


            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
               float4 brightCol = tex2D(_MainTex,i.uv);
               float4 finalCol = brightCol;
               return float4(finalCol.rgb,1);
            }
            ENDCG
       }
        
       
    }
}