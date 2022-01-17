using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]

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
        Shader.SetGlobalVector("_ShadowLightDirection", mCamera.transform.forward);
    }
}
