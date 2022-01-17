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
        mCamera.SetReplacementShader(shader, "");//ʹ��shader������Ⱦ
        Shader.SetGlobalTexture("_ShadowMap", mCamera.targetTexture);//�õ�shadowMap, ����Ϊȫ�ֹ�shaderʹ��
   
        
    }

    // Update is called once per frame
    void Update()
    {
        
        Shader.SetGlobalMatrix("_ShadowLauncherMatrix", transform.worldToLocalMatrix);//���潫��������ת������Դ����ľ���
        Shader.SetGlobalVector("_ShadowLauncherParam", new Vector4(mCamera.orthographicSize, mCamera.nearClipPlane, mCamera.farClipPlane));//�洢����ڲ�
        Shader.SetGlobalVector("_ShadowLightDirection", mCamera.transform.forward);
    }
}
