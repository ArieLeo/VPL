Shader "VPL/IRDiffuse" {
	Properties{
		_Color("Main Color", Color) = (1,1,1,1)
		_MainTex("Base (RGB)", 2D) = "white" {}
		[MaterialEnum(On,0, Off,2)] _Cull("2-Sided", Int) = 2
	}


		SubShader
		{
			Tags {"Queue" = "Geometry" "RenderType" = "Opaque" }
			Cull[_Cull]

			// ---- forward rendering base pass:
			Pass
			{
				Name "FORWARD"
				Tags { "LightMode" = "ForwardBase" }

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase noshadowmask nodynlightmap nodirlightmap novertexlight

				#define UNITY_PASS_FORWARDBASE
				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "AutoLight.cginc"

				sampler2D _MainTex;
				float4 _MainTex_ST;
				half4 _Color;

				struct v2f
				{
					UNITY_POSITION(pos);
					float2 uv0 : TEXCOORD0; // _MainTex
					float3 worldPos : TEXCOORD1;
					half3 worldNormal : TEXCOORD2;
					UNITY_SHADOW_COORDS(3)
				};

				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_INITIALIZE_OUTPUT(v2f, o);

					o.uv0 = TRANSFORM_TEX(v.texcoord, _MainTex);

					float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

					o.pos = UnityWorldToClipPos(worldPos);
					o.worldPos = worldPos;

					float3 worldNormal = UnityObjectToWorldNormal(v.normal);
					o.worldNormal = worldNormal;

					UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy); // pass shadow coordinates to pixel shader
					return o;
				}


				fixed4 frag(v2f IN) : SV_Target
				{
					fixed4 albedo = tex2D(_MainTex, IN.uv0);
					albedo *= _Color;

					float3 worldPos = IN.worldPos;

					// compute lighting & shadowing factor
					UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
					fixed4 c = 0;

					fixed3 worldNormal = IN.worldNormal;

					// realtime lighting: call lighting function
					#ifndef USING_DIRECTIONAL_LIGHT
						fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
					#else
						fixed3 lightDir = _WorldSpaceLightPos0.xyz;
					#endif
					fixed diffuse = max(0, dot(worldNormal, lightDir));
					//c.rgb += (albedo * _LightColor0.rgb) * (diffuse * atten);

					c.a = 1.0f;
					return 0;
				}
				ENDCG
			}

			// ---- forward rendering additive lights pass:
			Pass
			{
				Name "FORWARD"

				Tags { "LightMode" = "ForwardAdd" }
				ZWrite Off Blend One One
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				//#pragma multi_compile_fwdadd
				#pragma multi_compile_fwdadd_fullshadows 

				#define UNITY_PASS_FORWARDADD
				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "AutoLight.cginc"

				sampler2D _MainTex;
				float4 _MainTex_ST;
				half4 _Color;

				struct v2f
				{
					UNITY_POSITION(pos);
					float2 uv0 : TEXCOORD0; // _MainTex
					float3 worldNormal : TEXCOORD1;
					float3 worldPos : TEXCOORD2;
					UNITY_SHADOW_COORDS(4)
				};

				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_INITIALIZE_OUTPUT(v2f, o);

					float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
					float3 worldNormal = UnityObjectToWorldNormal(v.normal);

					o.pos = UnityWorldToClipPos(worldPos);

					o.uv0 = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.worldPos = worldPos;
					o.worldNormal = worldNormal;

					UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy); // pass shadow coordinates to pixel shader
					return o;
				}

				// fragment shader
				fixed4 frag(v2f IN) : SV_Target
				{
					fixed4 albedo = tex2D(_MainTex, IN.uv0);
					albedo *= _Color;

					float3 worldPos = IN.worldPos;
					float3 worldNormal = IN.worldNormal;

					#ifndef USING_DIRECTIONAL_LIGHT
						float3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
					#else
						float3 lightDir = _WorldSpaceLightPos0.xyz;
					#endif

#ifdef POINT
					fixed shadow = UNITY_SHADOW_ATTENUATION(IN, worldPos); 

					float3 posToLight = _WorldSpaceLightPos0.xyz - worldPos;
					float distanceSqure = dot(posToLight, posToLight);
					fixed atten = 1.0f / (1 + distanceSqure);
					atten = 1.0f / max(distanceSqure, 1.0f);
					atten *= shadow;
#else
					UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
#endif
					fixed4 c = 0;
					fixed diffuse = max(0, dot(worldNormal, lightDir));
					c.rgb = (albedo * _LightColor0.rgb * 3.14) * (diffuse * atten);

					c.a = albedo.a;

					return c;
				}

				ENDCG
			}

			// ---- shadow caster pass:
			Pass
			{
				Name "ShadowCaster"
				Tags { "LightMode" = "ShadowCaster" }
				ZWrite On ZTest LEqual

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma fragmentoption ARB_precision_hint_fastest
				#pragma multi_compile_shadowcaster

				#define UNITY_PASS_SHADOWCASTER
				#include "UnityCG.cginc"

				struct v2f
				{
					V2F_SHADOW_CASTER;
					//float2 uv0 : TEXCOORD1; // _MainTex
				};

				// vertex shader
				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_INITIALIZE_OUTPUT(v2f, o);

					//o.uv0 = TRANSFORM_TEX(v.texcoord, _MainTex);
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					return o;
				}

				// fragment shader
				fixed4 frag(v2f IN) : SV_Target
				{
				//#ifdef ALPHATEST_ON
				//	fixed4 albedo = tex2D(_MainTex, IN.uv0);
				//	clip(albedo.a - _Cutoff);
				//#endif

					SHADOW_CASTER_FRAGMENT(IN)
				}

				ENDCG

			}
		}

		Fallback Off
}
