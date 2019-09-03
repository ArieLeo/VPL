using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InstantRadiosity : MonoBehaviour
{
    GameObject vplsGo;
	void Start ()
    {
        this.GenerateVPLs();
	}

    public int photonNum = 16;
    public int bounces = 8;

    List<Light> vpls = new List<Light>();
    void GenerateVPLs()
    {
        RaycastHit raycastHit = new RaycastHit();

        for (int i = 0; i < photonNum; i++)
        {
            Vector3 dir = this.GenerateHemisphereDir(Vector3.down);

            Color lightCol = Color.white;

            for (int j = 0; j < bounces; j++)
            {
                if (Physics.Raycast(this.transform.position, dir, out raycastHit))
                {
                    MeshRenderer renderer = raycastHit.transform.GetComponent<MeshRenderer>();
                    if(renderer != null)
                    {
                        lightCol *= renderer.sharedMaterial.color;

                        this.CreateVirtualPointLight(raycastHit.point + raycastHit.normal * 0.001f, lightCol, 1.0f / photonNum);

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
    }

    Vector3 GenerateHemisphereDir(Vector3 normal)
    {
        Vector3 dir = Random.onUnitSphere;

        if (Vector3.Dot(dir, normal) < 0)
            dir = -dir;

        return dir;
    }

    void CreateVirtualPointLight(Vector3 pos, Color color, float intensity)
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
        light.range = 1000;
        light.color = color;
        light.intensity = intensity;
        light.lightmapBakeType = LightmapBakeType.Realtime;
        light.shadows = LightShadows.Hard;

        this.vpls.Add(light);
    }
}
