Shader "Soil/PBR Smoothness" {
	Properties{
		_MapScale("Scale", Float) = 1

		[NoScaleOffset]_BaseMap("Base Texture", 2D) = "white" {}

		[NoScaleOffset]_BumpMap("Normal/Bump Texture", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1

		_Smoothness("Smoothness Multiplier", Float) = 1
	}
	SubShader{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry"}

		HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			CBUFFER_START(UnityPerMaterial)
			float _MapScale;
			float4 _BaseMap_ST;
			float _Smoothness;
			float _BumpScale;
			CBUFFER_END
		ENDHLSL

		Pass {
			Name "Forward"
			Tags { "LightMode" = "UniversalForward" }

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			// URP Keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile _ _SHADOWS_SOFT

			// Includes
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

			struct Vert
			{
				float4 position;
				float3 normal;
				int indicy;
			};

			struct Varyings {
				float4 positionCS				: SV_POSITION;
				float3 positionWS				: TEXCOORD0;
				float3 normalWS					: TEXCOORD1;
				float3 viewDirWS 				: TEXCOORD2;
			};

			uniform StructuredBuffer<Vert> vertBuffer;
			uniform StructuredBuffer<int> triBuffer;

			Varyings vert(uint id : SV_VertexID) {
				Varyings OUT;
				Vert vertData = vertBuffer[triBuffer[id]];
				OUT.positionWS = vertData.position.xyz;
				OUT.positionCS = TransformObjectToHClip(vertData.position.xyz);
				OUT.viewDirWS = GetWorldSpaceViewDir(vertData.position.xyz);
				OUT.normalWS = TransformObjectToWorldNormal(vertData.normal);

				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target {
				//SURFACEDATA
				SurfaceData surfaceData = (SurfaceData)0;

				half3 blendingFactor = saturate(pow(IN.normalWS, 4));
				blendingFactor /= max(dot(blendingFactor, half3(1, 1, 1)), 0.0001);

				// calculate triplanar uvs
				float2 uvX = IN.positionWS.yz * _MapScale;
				float2 uvY = IN.positionWS.zx * _MapScale;
				float2 uvZ = IN.positionWS.xy * _MapScale;

				// offset UVs to prevent obvious mirroring
				uvY += 0.33;
				uvZ += 0.67;

				// minor optimization of sign(). prevents return value of 0
				half3 axisSign = IN.normalWS < 0 ? -1 : 1;

				// flip UVs horizontally to correct for back side projection
				uvX.x *= axisSign.x;
				uvY.x *= axisSign.y;
				uvZ.x *= -axisSign.z;

				half4 cx = SampleAlbedoAlpha(uvX, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)) * blendingFactor.x;
				half4 cy = SampleAlbedoAlpha(uvY, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)) * blendingFactor.y;
				half4 cz = SampleAlbedoAlpha(uvZ, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)) * blendingFactor.z;
				half4 diffuse = cx + cy + cz;
				surfaceData.albedo = diffuse.rgb;
				surfaceData.smoothness = diffuse.a * _Smoothness;
				surfaceData.occlusion = 1.0;

				//INPUTDATA
				InputData inputData = (InputData)0;

				inputData.positionWS = IN.positionWS;

				// tangent space normal maps
				half3 nxT = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvX), _BumpScale) * blendingFactor.x;
				half3 nyT = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvY), _BumpScale) * blendingFactor.y;
				half3 nzT = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvZ), _BumpScale) * blendingFactor.z;

				// flip normal maps' x axis to account for flipped UVs
				nxT.x *= axisSign.x;
				nyT.x *= axisSign.y;
				nzT.x *= -axisSign.z;

				// swizzle tangent normal map to match world normals
				half3 nx = half3(0.0, nxT.yx);
				half3 ny = half3(nyT.x, 0.0, nyT.y);
				half3 nz = half3(nzT.xy, 0.0);

				// apply world space sign to tangent space Z
				nx.z *= axisSign.x;
				ny.z *= axisSign.y;
				nz.z *= axisSign.z;

				half3 normal = normalize(nx + ny + nz + IN.normalWS);

				inputData.normalWS = normal;
				inputData.viewDirectionWS = IN.viewDirWS;
				inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);

				half4 color = UniversalFragmentPBR(inputData, surfaceData);

				return color;
			}

			ENDHLSL
		}
	}
}