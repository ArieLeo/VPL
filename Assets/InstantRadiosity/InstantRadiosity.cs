using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class InstantRadiosity : MonoBehaviour
{
    public Light sourceLight;
    public int photonNum = 16;
    public int bounces = 8;

    public LightShadowResolution shadowResolution = LightShadowResolution.Medium;

    private Material material;

	void Start ()
    {
        material = new Material(Shader.Find("VPL/IRPostProcess"));
        material.SetFloat("_PhotonNum", this.photonNum);

        this.GenerateVPLs();
	}

    List<Light> vpls = new List<Light>();
    void GenerateVPLs()
    {
        if (this.sourceLight == null)
            return;

        this.sourceLight.enabled = false;

        Vector3 sourceLightPos = this.sourceLight.transform.position;
        float sourceIntensity = this.sourceLight.intensity;

        RaycastHit raycastHit = new RaycastHit();

        for (int i = 0; i < photonNum; i++)
        {
            Color lightCol = this.sourceLight.color;

            //direct Light
            this.CreateVirtualPointLight(sourceLightPos, lightCol, sourceIntensity, this.sourceLight.range);

            Vector3 dir = this.GenerateHemisphereDir(Vector3.down);

            float intensity = sourceIntensity;

            for (int j = 0; j < bounces; j++)
            {
                if (Physics.Raycast(sourceLightPos, dir, out raycastHit))
                {
                    MeshRenderer renderer = raycastHit.transform.GetComponent<MeshRenderer>();
                    if(renderer != null)
                    {
                        lightCol *= renderer.sharedMaterial.color;

                        //intensity *= Mathf.Clamp01(Vector3.Dot(raycastHit.normal, -dir));
                        this.CreateVirtualPointLight(raycastHit.point + raycastHit.normal * 0.001f, lightCol, intensity, 10);

                        dir = this.GenerateHemisphereDir(raycastHit.normal);
                    }
                    else
                    {
                        Debug.LogError("Raycast a collider without renderer " + raycastHit.transform.name);
                        break;
                    }
                }
                else
                    break;
            }
        }

        Debug.Log(this.vpls.Count);
    }

    Vector3 GenerateHemisphereDir(Vector3 normal)
    {
        Vector3 dir = Random.onUnitSphere;

        if (Vector3.Dot(dir, normal) < 0)
            dir = -dir;

        return dir;

        //Vector3 dir = Random.onUnitSphere;
        //while (Vector3.Dot(dir, normal) < 0)
        //{
        //    dir = Random.onUnitSphere;
        //}

        //return dir;
    }


    GameObject vplsGo;
    void CreateVirtualPointLight(Vector3 pos, Color color, float intensity, float range)
    {
        GameObject go = new GameObject();
        go.transform.position = pos;
        go.name = "VPL";

        if (this.vplsGo == null)
        {
            this.vplsGo = new GameObject();
            this.vplsGo.transform.position = Vector3.zero;
            this.vplsGo.name = "VPLs";
        }
        go.transform.transform.parent = this.vplsGo.transform;

        Light light = go.AddComponent<Light>();
        light.type = LightType.Point;
        light.range = range;
        light.color = color;
        light.intensity = intensity;
        light.shadowResolution = this.shadowResolution;
        light.lightmapBakeType = LightmapBakeType.Realtime;
        light.shadows = LightShadows.Hard;

        this.vpls.Add(light);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material);
    }
}
