Shader "Unlit/RimLightingExtended"
{
    Properties
    {
        _BaseColor      ("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap        ("Base Map", 2D) = "white" {}

        _RimColor       ("Rim Color", Color) = (0, 0.5, 0.5, 1)
        _RimPower       ("Rim Power", Range(0.5, 8.0)) = 3.0
        _RimIntensity   ("Rim Intensity", Range(0, 5)) = 1.0
        _RimWidth       ("Rim Width", Range(0.01, 1)) = 0.5

        _PulseSpeed     ("Rim Pulse Speed", Float) = 0.0
        _PulseAmplitude ("Rim Pulse Amplitude", Range(0,1)) = 0.0

        _EmissionColor    ("Emission Color", Color) = (0, 0, 0, 1)
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 viewDirWS   : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float2 uv          : TEXCOORD2;
            };

            // Textures
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;

                float4 _RimColor;
                float  _RimPower;
                float  _RimIntensity;
                float  _RimWidth;

                float  _PulseSpeed;
                float  _PulseAmplitude;

                float4 _EmissionColor;
                float  _EmissionStrength;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(worldPos);

                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.viewDirWS = normalize(GetCameraPositionWS() - worldPos);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                half3 viewDirWS = normalize(IN.viewDirWS);

                // Base albedo from texture * color
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half3 baseAlbedo = baseTex.rgb * _BaseColor.rgb;

                // Simple main light diffuse
                Light mainLight = GetMainLight();
                half3 lightColor = mainLight.color;
                half3 lightDirWS = normalize(-mainLight.direction);

                half NdotL = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = baseAlbedo * lightColor * NdotL;

                half rimFactor = 1.0h - saturate(dot(viewDirWS, normalWS));

                // Shape rim thickness by width
                // rimFactor in [0,1] -> sharpen around the edge based on _RimWidth
                // When _RimWidth small -> thinner rim
                rimFactor = saturate((rimFactor - (1.0h - _RimWidth)) / _RimWidth);

                // power shaping
                rimFactor = pow(rimFactor, _RimPower);

                half pulse = 1.0h;
                if (_PulseSpeed != 0.0f && _PulseAmplitude > 0.0f)
                {
                    pulse += sin(_Time.y * _PulseSpeed) * _PulseAmplitude;
                }

                rimFactor *= _RimIntensity * pulse;

                half3 rimColor = _RimColor.rgb * rimFactor;

                half3 emission = _EmissionColor.rgb * _EmissionStrength;

                // Final color
                half3 finalColor = diffuse + rimColor + emission;

                return half4(finalColor, _BaseColor.a * baseTex.a);
            }

            ENDHLSL
        }
    }
}