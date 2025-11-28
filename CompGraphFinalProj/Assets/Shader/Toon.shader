Shader "Unlit/ToonExtended"
{
    Properties
    {
        _BaseColor   ("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap     ("Base Map", 2D) = "white" {}          // NEW
        _NormalMap   ("Normal Map", 2D) = "bump" {}         // NEW
        _NormalScale ("Normal Strength", Range(0, 2)) = 1   // NEW

        _RampTex     ("Ramp Texture", 2D) = "white" {}

        _ShadowColor ("Shadow Color", Color) = (0.1, 0.1, 0.1, 1) // NEW

        _RimColor    ("Rim Color", Color) = (1, 1, 1, 1)
        _RimPower    ("Rim Power", Range(0.1, 8.0)) = 1.5

        _EmissionColor    ("Emission Color", Color) = (0, 0, 0, 1) // NEW
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 0   // NEW

        _ScrollSpeed      ("Scroll Speed (XY)", Vector) = (0, 0, 0, 0) // NEW
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
                float4 tangentOS  : TANGENT;     // NEW (for normal map)
                float2 uv         : TEXCOORD0;   // NEW (for textures)
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
                float3 tangentWS   : TEXCOORD1;
                float3 bitangentWS : TEXCOORD2;
                float3 viewDirWS   : TEXCOORD3;
                float2 uv          : TEXCOORD4;
            };

            // Textures & samplers
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _NormalMap_ST;

                float4 _ShadowColor;

                float4 _RimColor;
                float  _RimPower;

                float4 _EmissionColor;
                float  _EmissionStrength;

                float2 _ScrollSpeed;   // xy used
                float  _NormalScale;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // World position & clip space
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(posWS);

                // World-space normal/tangent/bitangent for normal mapping
                OUT.normalWS  = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.tangentWS = normalize(TransformObjectToWorldDir(IN.tangentOS.xyz));
                OUT.bitangentWS = normalize(cross(OUT.normalWS, OUT.tangentWS) * IN.tangentOS.w);

                // View direction in world space
                OUT.viewDirWS = normalize(GetWorldSpaceViewDir(posWS));

                // Base UV with tiling/offset + scrolling
                float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                uv += _ScrollSpeed.xy * _Time.y; // scroll over time
                OUT.uv = uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // -------------------------------------------------------
                // Lighting / main light
                // -------------------------------------------------------
                Light mainLight = GetMainLight();
                half3 lightDirWS = normalize(mainLight.direction);
                half3 lightColor = mainLight.color;

                // -------------------------------------------------------
                // Normal mapping (tangent space -> world space)
                // -------------------------------------------------------
                half3 normalWS = normalize(IN.normalWS); // fallback if no normal map

                // Sample normal map in tangent space
                half3 normalTS = UnpackNormal(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv)
                );

                // Scale normal strength
                normalTS.xy *= _NormalScale;
                normalTS.z = sqrt(saturate(1.0h - dot(normalTS.xy, normalTS.xy)));

                // TBN matrix
                float3x3 TBN = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
                normalWS = normalize(mul(TBN, normalTS));

                // -------------------------------------------------------
                // Base color / albedo from texture
                // -------------------------------------------------------
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half3 baseColor = _BaseColor.rgb * baseTex.rgb;

                // Toon step via ramp + custom shadow color
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half rampValue = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NdotL, 0)).r;

                // Interpolate between shadow color and base color using the ramp
                half3 toonColor = lerp(_ShadowColor.rgb, baseColor, rampValue);

                half3 finalColor = toonColor * lightColor;

                // -------------------------------------------------------
                // Rim light
                // -------------------------------------------------------
                half3 viewDir = normalize(IN.viewDirWS);
                half rimDot = 1.0h - saturate(dot(viewDir, normalWS));
                half rimFactor = pow(rimDot, _RimPower);
                finalColor += _RimColor.rgb * rimFactor;

                // -------------------------------------------------------
                // Emission
                // -------------------------------------------------------
                finalColor += _EmissionColor.rgb * _EmissionStrength;

                return half4(finalColor, _BaseColor.a * baseTex.a);
            }

            ENDHLSL
        }
    }
}