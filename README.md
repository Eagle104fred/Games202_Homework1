# 介绍
 作业1在Unity上的复现, 实现了基于的硬阴影, PCF, PCSS
 **代码下载:** [https://github.com/Eagle104fred/Games202_Homework1](https://github.com/Eagle104fred/Games202_Homework1)

![在这里插入图片描述](https://img-blog.csdnimg.cn/1100d42b74074fc8aac6af925f6abff3.png?x-oss-process=image/watermark,type_d3F5LXplbmhlaQ,shadow_50,text_Q1NETiBARWFnbGUxMDRmcmVk,size_13,color_FFFFFF,t_70,g_se,x_16)


# 注意事项
- 阴影的shader必须写在阴影的接受物体上例如墙壁等地方, 和模型本身的shader没啥关系
- 注意深度像机的参数设置

# 实现过程
## 1.构建shadowMap以及硬阴影
- 新建unity场景后建立一个Camera, 也可以在下面创建一个光源给模型打光不过不影响阴影效果。
- 新建一个产生阴影的Object和一个接受阴影的Object
- ![在这里插入图片描述](https://img-blog.csdnimg.cn/d0bd2118f7e14512aac849f0014fb0a4.png)

![在这里插入图片描述](https://img-blog.csdnimg.cn/811d4b3c8b864fa19810c34470a2a961.png?x-oss-process=image/watermark,type_d3F5LXplbmhlaQ,shadow_50,text_Q1NETiBARWFnbGUxMDRmcmVk,size_17,color_FFFFFF,t_70,g_se,x_16)
## 2.设置阴影相机参数
需要增加三个文件, 一个是相机的脚本文件用于传递相机的参数和ShadowMap给Shader, 一个是ShadowMap需要新建一个RenderTexture文件来存储, 一个是用于绘制阴影的空Shader

![在这里插入图片描述](https://img-blog.csdnimg.cn/1898987bcad74ae4b63c38c77f6aacd3.png?x-oss-process=image/watermark,type_d3F5LXplbmhlaQ,shadow_50,text_Q1NETiBARWFnbGUxMDRmcmVk,size_9,color_FFFFFF,t_70,g_se,x_16)

**LightCam.cs**
```csharp
public class LightCam : MonoBehaviour
{
    // Start is called before the first frame update
    public Shader shader;
    Camera mCamera;
    
    
    private void Awake()
    {
        mCamera = this.GetComponent<Camera>();
        mCamera.SetReplacementShader(shader, "");//使用shader进行渲染
        Shader.SetGlobalTexture("_ShadowMap", mCamera.targetTexture);//拿到shadowMap, 设置为全局供shader使用
   
        
    }

    // Update is called once per frame
    void Update()
    {
        Shader.SetGlobalMatrix("_ShadowLauncherMatrix", transform.worldToLocalMatrix);//保存将世界坐标转换到光源坐标的矩阵
        Shader.SetGlobalVector("_ShadowLauncherParam", new Vector4(mCamera.orthographicSize, mCamera.nearClipPlane, mCamera.farClipPlane));//存储相机内参
    }
}
```
**ShaderDepth.shader**
```c++
Shader "Custom/ShaderDepth"
{
   SubShader
	{
		Tags { "RenderType"="Opaque" }
		Offset 1,1 //绘制深度时候偏移一点位置
		Pass
		{
		}
	}
}

```
## 3.配置接受物体的shader
![在这里插入图片描述](https://img-blog.csdnimg.cn/1af25278c7ae433d8b8e2407f684941c.png)

**ShaderRecieve.shader**
```cpp
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
            shadowAlpha = HardShadow(i);  
            color.rgb *=(1-shadowAlpha)*_BaseColor.rgb;//阴影能见度加上材质本身的颜色

            return color;
        }
        ENDCG
        }
    }
}


```
## PCF
待续
## PCSS
待续
