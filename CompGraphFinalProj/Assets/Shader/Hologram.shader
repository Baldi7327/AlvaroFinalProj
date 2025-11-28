Shader "Unlit/HologramExtended"
{
    Properties
    {
        _MainTex        ("Main Texture", 2D) = "white" {}
        _MainTint       ("Main Tint", Color) = (0.5, 1, 1, 1)

        _LineColor      ("Line Color", Color) = (0, 1, 1, 1)  // Scan lines
        _FresnelColor   ("Fresnel Color", Color) = (0, 0.8, 1, 1)
        _RimIntensity   ("Rim Intensity", Float) = 1.5
        _FresnelPower   ("Fresnel Power", Range(1, 5)) = 2.0
        _LineSpeed      ("Line Speed", Float) = 1.0
        _LineFrequency  ("Line Frequency", Float) = 10.0

        _Transparency   ("Base Transparency", Range(0, 1)) = 0.5

        _NoiseTex       ("Noise Texture", 2D) = "white" {}  // greyscale noise
        _NoiseScale     ("Noise UV Scale", Float) = 4.0
        _NoiseSpeed     ("Noise Scroll Speed", Float) = 1.0
        _NoiseIntensity ("Noise Intensity", Range(0, 1)) = 0.5  // how strong the flicker is

        _EmissionColor    ("Emission Color", Color) = (0, 1, 1, 1)
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 1.0

        _DistanceFadeStart ("Fade Start Distance", Float) = 5.0
        _DistanceFadeEnd   ("Fade End Distance", Float) = 20.0

        _DissolveHeight   ("Dissolve Height", Float) = 0.0
        _DissolveSoftness ("Dissolve Softness", Float) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD1;
                float3 viewDirWS   : TEXCOORD2;
                float2 uv          : TEXCOORD0;
                float3 positionWS  : TEXCOORD3;
            };

            // Textures
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            // Material variables
            float4 _MainTint;

            float4 _LineColor;
            float4 _FresnelColor;
            float  _RimIntensity;
            float  _FresnelPower;
            float  _LineSpeed;
            float  _LineFrequency;
            float  _Transparency;

            float4 _EmissionColor;
            float  _EmissionStrength;

            float  _NoiseScale;
            float  _NoiseSpeed;
            float  _NoiseIntensity;

            float  _DistanceFadeStart;
            float  _DistanceFadeEnd;

            float  _DissolveHeight;
            float  _DissolveSoftness;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionWS  = posWS;
                OUT.positionHCS = TransformWorldToHClip(posWS);

                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.viewDirWS = normalize(GetWorldSpaceViewDir(posWS));
                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half3 baseColor = texColor.rgb * _MainTint.rgb;

                // Fresnel
                half3 n = normalize(IN.normalWS);
                half3 v = normalize(IN.viewDirWS);
                half fresnel = pow(1.0h - saturate(dot(v, n)), _FresnelPower);
                half3 fresnelColor = _FresnelColor.rgb * fresnel * _RimIntensity;

                // Scan-line effect
                float lineValue = sin(IN.uv.y * _LineFrequency + _Time.y * _LineSpeed);
                half3 lineColor = _LineColor.rgb * step(0.5, lineValue);

                // Noise-based flicker / glitch
                float2 noiseUV = IN.uv * _NoiseScale + float2(0.0, _Time.y * _NoiseSpeed);
                half noiseSample = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).r;
                // Map noise to [1 - intensity, 1 + intensity]
                half noiseFactor = 1.0h + (noiseSample - 0.5h) * 2.0h * _NoiseIntensity;

                // Distance-based fade
                float3 camPosWS = GetCameraPositionWS();
                float dist = distance(camPosWS, IN.positionWS);

                float distFade = 1.0f;
                if (_DistanceFadeEnd > _DistanceFadeStart)
                {
                    distFade = saturate((_DistanceFadeEnd - dist) /
                                        (_DistanceFadeEnd - _DistanceFadeStart));
                }

                // Height-based dissolve
                float h = IN.positionWS.y;
                float dissolveMask = smoothstep(_DissolveHeight,
                                                _DissolveHeight + _DissolveSoftness,
                                                h);
                // 1 = visible, 0 = dissolved
                float dissolveFactor = 1.0f - dissolveMask;

                // Combine color contributions
                half3 finalColor = baseColor + fresnelColor + lineColor;

                finalColor += _EmissionColor.rgb * _EmissionStrength;

                // base transparency * effects
                half alpha = _Transparency;
                alpha *= noiseFactor;
                alpha *= distFade;
                alpha *= dissolveFactor;

                return half4(finalColor, saturate(alpha));
            }

            ENDHLSL
        }
    }
}