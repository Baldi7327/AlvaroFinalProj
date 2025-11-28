Shader "Unlit/WaterShader"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0, 1, 1, 1)  // Default is light blue
        _MainTex ("Water Texture", 2D) = "white" {}
        _Freq ("Wave Frequency", Range(0, 5)) = 3.0
        _Speed ("Wave Speed", Range(0, 10)) = 1.0
        _Amp ("Wave Amplitude", Range(0, 1)) = 0.1

        //add the properties for scrolling water ----------------
        _MainTex2 ("Water", 2D) = "white" {}
        _FoamTex ("Foam", 2D) = "white" {}
        _ScrollX ("Scroll X", Range(-5,5)) = 1
        _ScrollY ("Scroll Y", Range(-5,5)) = 1
        //---------------------------------------
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" "RenderType" = "Opaque" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Include URP core functionality
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;  // Object space position
                float2 uv : TEXCOORD0;         // Texture coordinates
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION; // Homogeneous clip-space position
                float2 uv : TEXCOORD0;            // Pass UVs to fragment
            };

            // Declare properties for base color, texture, and wave parameters
            float4 _BaseColor;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            //add texture variables for scrolling water----------------
            TEXTURE2D(_MainTex2);
            SAMPLER(sampler_MainTex2);

            TEXTURE2D(_FoamTex);
            SAMPLER(sampler_FoamTex);

            float _ScrollX;
            float _ScrollY;
            //---------------

            float _Freq;
            float _Speed;
            float _Amp;

            // Vertex Shader with wave animation
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //Add component of scrolling water --------------
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);  // Transform object position to clip space
                //------------------------------------------------

                // Time-based animation for water waves
                float wave = sin(_Time.y * _Speed + IN.positionOS.x * _Freq) * _Amp;

                // Adjust the vertex y position for wave effect
                float3 displacedPos = IN.positionOS.xyz;
                displacedPos.y += wave;

                // Transform the displaced position to clip space
                OUT.positionHCS = TransformObjectToHClip(displacedPos);

                // Pass UV coordinates to the fragment shader
                OUT.uv = IN.uv;

                return OUT;
            }

            // Fragment Shader to apply texture and base color tint
            half4 frag(Varyings IN) : SV_Target
            {
                //Add components for water scrolling -------------------------------------
                 // Scroll UVs over time
                float2 scrolledUV = IN.uv + float2(_ScrollX, _ScrollY) * _Time.y;

                // Scroll UVs for foam texture at a different rate
                float2 scrolledFoamUV = IN.uv + float2(_ScrollX, _ScrollY) * (_Time.y * 0.5);

                // Sample both textures using the scrolled UV coordinates
                half4 water = SAMPLE_TEXTURE2D(_MainTex2, sampler_MainTex2, scrolledUV);
                half4 foam = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, scrolledFoamUV);

                // Blend both textures
                half4 finalColor = (water + foam) * 0.5;
                //-----------------------------------------------------------------

                // Sample the texture and multiply by base color
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                return (texColor * _BaseColor), finalColor;
            }

            ENDHLSL
        }
    }
}