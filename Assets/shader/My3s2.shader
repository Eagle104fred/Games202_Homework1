Shader "Custom/My3s2"
{
    Properties
    {
        [HideInInspector] _simpleUI ("SimpleUI", Int ) = 0
        [HideInInspector] _utsVersion ("Version", Float ) = 2.08
        [HideInInspector] _utsTechnique ("Technique", int ) = 0 //DWF
        [Enum(OFF,0,FRONT,1,BACK,2)] _CullMode("Cull Mode", int) = 2  //OFF/FRONT/BACK
        _MainTex ("BaseMap", 2D) = "white" {}
        [HideInInspector] _BaseMap ("BaseMap", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        //v.2.0.5 : Clipping/TransClipping for SSAO Problems in PostProcessing Stack.
        //If you want to go back the former SSAO results, comment out the below line.
        [HideInInspector] _Color ("Color", Color) = (1,1,1,1)
        //
        [Toggle(_)] _Is_LightColor_Base ("Is_LightColor_Base", Float ) = 1
        _1st_ShadeMap ("1st_ShadeMap", 2D) = "white" {}
        //v.2.0.5
        //ʹ������ͼ����һ����Ӱ��ͼ
        [Toggle(_)] _Use_BaseAs1st ("Use BaseMap as 1st_ShadeMap", Float ) = 0
        _1st_ShadeColor ("1st_ShadeColor", Color) = (1,1,1,1)
        //���������ɫ
        [Toggle(_)] _Is_LightColor_1st_Shade ("Is_LightColor_1st_Shade", Float ) = 1
        _2nd_ShadeMap ("2nd_ShadeMap", 2D) = "white" {}
        //v.2.0.5
        //�Ƿ�ʹ�ö�����Ӱ��ͼ
        [Toggle(_)] _Use_1stAs2nd ("Use 1st_ShadeMap as 2nd_ShadeMap", Float ) = 0
        _2nd_ShadeColor ("2nd_ShadeColor", Color) = (1,1,1,1)
        //���������ɫ
        [Toggle(_)] _Is_LightColor_2nd_Shade ("Is_LightColor_2nd_Shade", Float ) = 1
        
        //v.2.0.4.4
        //ʹ�ù���˥��
        [Toggle(_)] _Set_SystemShadowsToBase ("Set_SystemShadowsToBase", Float ) = 1
        _Tweak_SystemShadowsLevel ("Tweak_SystemShadowsLevel", Range(-0.5, 0.5)) = 0
        //v.2.0.6
        //һ��Ӱ�ķ�Χ
        _BaseColor_Step ("BaseColor_Step", Range(0, 1)) = 0.5
        //����ɫ��һ��Ӱ����Ч��
        _BaseShade_Feather ("Base/Shade_Feather", Range(0.0001, 1)) = 0.0001
        //����Ӱ��Χ
        _ShadeColor_Step ("ShadeColor_Step", Range(0, 1)) = 0
        //һ��Ӱ�Ͷ���Ӱ����Ч��
        _1st2nd_Shades_Feather ("1st/2nd_Shades_Feather", Range(0.0001, 1)) = 0.0001
        [HideInInspector] _1st_ShadeColor_Step ("1st_ShadeColor_Step", Range(0, 1)) = 0.5
        [HideInInspector] _1st_ShadeColor_Feather ("1st_ShadeColor_Feather", Range(0.0001, 1)) = 0.0001
        [HideInInspector] _2nd_ShadeColor_Step ("2nd_ShadeColor_Step", Range(0, 1)) = 0
        [HideInInspector] _2nd_ShadeColor_Feather ("2nd_ShadeColor_Feather", Range(0.0001, 1)) = 0.0001


        [Header(Line)]
        _OutlineWidth ("Outline Width", Range(0.0, 10)) = 0
        _OutlineColor ("Outline Color", color) = (0, 0, 0, 1)
        _InnerStrokeIntensity ("Inner Stroke Intensity", Range(0.0, 3)) = 1
       
    }
    SubShader
    {
       Tags{"RenderType" = "Openge"}
      pass //KS: ���� 
        {
            CULL Front //KS: ǰ���޳� 
            CGPROGRAM
            
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 vertColor : COLOR;
                float4 tangent : TANGENT;
            };
            struct v2f
            {
                float4 pos: SV_POSITION;
            };
            
            fixed _OutlineWidth;
            fixed4 _OutlineColor;
            
            v2f vert(a2v v)
            {

                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);//��ʼ��Ϊ0
                float4 pos = UnityObjectToClipPos(v.vertex);
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV,  v.normal.xyz);
                float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) * pos.w;//�����߱任��NDC�ռ�
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//�����ü������Ͻ�λ�õĶ���任���۲�ռ�
                ndcNormal.x*=abs(nearUpperRight.y/nearUpperRight.x);//����Ļ�Ŀ�߱�(������ΪNDC�ռ��xy�Ƿ�Χ��[0,1]������������Ĵ��ڷֱ�����16��9)
            
                pos.xy += 0.01 * _OutlineWidth * ndcNormal.xy;
                o.pos = pos;
                return o;
                
            }
            fixed4 frag(v2f i): SV_Target
            {
                return _OutlineColor;
            }
            
            ENDCG
            
        }



       Pass{//ģ����Ⱦ
            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            
            
           #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile_fog
           
            #pragma target 3.0

            #include "MyDoubleShade.cginc"
            ENDCG
       }
        
       
    }
}