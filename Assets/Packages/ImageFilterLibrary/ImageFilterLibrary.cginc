﻿#ifndef IMAGE_FILTER_LIBRARY_INCLUDED
#define IMAGE_FILTER_LIBRARY_INCLUDED

static const float PrewittFilterKernelH[9] =
{ -1, 0, 1,
  -1, 0, 1,
  -1, 0, 1 };

static const float PrewittFilterKernelV[9] =
{ -1, -1, -1,
   0,  0,  0,
   1,  1,  1 };

static const float SobelFilterKernelH[9] =
{ -1, 0, 1,
  -2, 0, 2,
  -1, 0, 1 };

static const float SobelFilterKernelV[9] =
{ -1, -2, -1,
   0,  0,  0,
   1,  2,  1 };

static const float Gaussian3FilterKernel[9] =
{ 0.0625, 0.1250, 0.0625,
  0.1250, 0.2500, 0.1250,
  0.0625, 0.1250, 0.0625 };

static const float LaplacianFilterKernel[9] =
{ -1, -1, -1,
  -1,  8, -1,
  -1, -1, -1 };

static const float4x4 DitherMatrixDot =
{ 0.74, 0.27, 0.40, 0.60,
  0.80, 0.00, 0.13, 0.94,
  0.47, 0.54, 0.67, 0.34,
  0.20, 1.00, 0.87, 0.07 };

static const float4x4 DitherMatrixBayer =
{ 0.000, 0.500, 0.125, 0.625,
  0.750, 0.250, 0.875, 0.375,
  0.187, 0.687, 0.062, 0.562,
  0.937, 0.437, 0.812, 0.312 };

float4 PrewittFilter(sampler2D tex, float2 texCoord, float2 texelSize)
{
    float4 sumHorizontal = float4(0, 0, 0, 1);
    float4 sumVertical   = float4(0, 0, 0, 1);
    float2 coordinate;
    int    count = 0;

    for (int x = -1; x <= 1; x++)
    {
        for (int y = -1; y <= 1; y++)
        {
            coordinate = float2(texCoord.x + texelSize.x * x, texCoord.y + texelSize.y * y);
            sumHorizontal.rgb += tex2D(tex, coordinate).rgb * PrewittFilterKernelH[count];
            sumVertical.rgb   += tex2D(tex, coordinate).rgb * PrewittFilterKernelV[count];
            count++;
        }
    }

    return sqrt(sumHorizontal * sumHorizontal + sumVertical * sumVertical);
}

float4 SobelFilter(sampler2D tex, float2 texCoord, float2 texelSize)
{
    float4 sumHorizontal = float4(0, 0, 0, 1);
    float4 sumVertical   = float4(0, 0, 0, 1);
    float2 coordinate;
    int    count = 0;

    for (int x = -1; x <= 1; x++)
    {
        for (int y = -1; y <= 1; y++)
        {
            coordinate = float2(texCoord.x + texelSize.x * x, texCoord.y + texelSize.y * y);
            sumHorizontal.rgb += tex2D(tex, coordinate).rgb * SobelFilterKernelH[count];
            sumVertical.rgb   += tex2D(tex, coordinate).rgb * SobelFilterKernelV[count];
            count++;
        }
    }

    return sqrt(sumHorizontal * sumHorizontal + sumVertical * sumVertical);
}

float4 LaplacianFilter(sampler2D tex, float2 texCoord, float2 texelSize)
{
    float4 color = float4(0, 0, 0, 1);
    int count = 0;

    for (int x = -1; x <= 1; x++)
    {
        for (int y = -1; y <= 1; y++)
        {
            texCoord = float2(texCoord.x + texelSize.x * x,
                              texCoord.y + texelSize.y * y);
            color.rgb += tex2D(tex, texCoord).rgb * LaplacianFilterKernel[count];
            count++;
        }
    }

    return color;
}

float4 MovingAverageFilter(sampler2D tex, float2 texCoord, float2 texelSize, int halfFilterSizePx)
{
    float4 color = float4(0, 0, 0, 1);
    float2 coordinate;

    for (int x = -halfFilterSizePx; x <= halfFilterSizePx; x++)
    {
        for (int y = -halfFilterSizePx; y <= halfFilterSizePx; y++)
        {
            color.rgb += tex2D(tex, float2(texCoord.x + texelSize.x * x,
                                            texCoord.y + texelSize.y * y)).rgb;
        }
    }

    int filterSizePx = halfFilterSizePx * 2 + 1;

    color.rgb /= filterSizePx * filterSizePx;

    return color;
}

float4 Gaussian3Filter(sampler2D tex, float2 texCoord, float2 texelSize)
{
    float4 color = float4(0, 0, 0, 1);
    int count = 0;

    for (int x = -1; x <= 1; x++)
    {
        for (int y = -1; y <= 1; y++)
        {
            texCoord = float2(texCoord.x + texelSize.x * x,
                              texCoord.y + texelSize.y * y);
            color.rgb += tex2D(tex, texCoord).rgb * Gaussian3FilterKernel[count];
            count++;
        }
    }

    return color;
}

float4 SymmetricNearestNeighbor
    (float4 centerColor, sampler2D tex, float2 texCoord, float2 texCoordOffset)
{
    float4 color0 = tex2D(tex, texCoord + texCoordOffset);
    float4 color1 = tex2D(tex, texCoord - texCoordOffset);
    float3 d0 = color0.rgb - centerColor.rgb;
    float3 d1 = color1.rgb - centerColor.rgb;

    return dot(d0, d0) < dot(d1, d1) ? color0 : color1;
}

float4 SymmetricNearestNeighborFilter
    (sampler2D tex, float2 texCoord, float2 texelSize, int halfFilterSizePx)
{
    // NOTE:
    // SymmetricNearestNeighborFilter algorithm compare the pixels with point symmetry.
    // So, the result of upper left side and lower right side shows same value.
    // This means the doubled upper left value is same as sum total.

    float  pixels = 1.0f;
    float4 centerColor = tex2D(tex, texCoord);
    float4 outputColor = centerColor;

    for (int y = -halfFilterSizePx; y < 0; y++)
    {
        float texCoordOffsetY = y * texelSize.y;

        for (int x = -halfFilterSizePx; x <= halfFilterSizePx; x++)
        {
            float2 texCoordOffset = float2(x * texelSize.x, texCoordOffsetY);

            outputColor += SymmetricNearestNeighbor
                (centerColor, tex, texCoord, texCoordOffset) * 2.0f;

            pixels += 2.0f;
        }
    }

    for (int x = -halfFilterSizePx; x < 0; x++)
    {
        float2 texCoordOffset = float2(x * texelSize.x, 0.0f);

        outputColor += SymmetricNearestNeighbor
            (centerColor, tex, texCoord, texCoordOffset) * 2.0f;

        pixels += 2.0f;
    }

    outputColor /= pixels;

    return outputColor;
}

float4 DitheringFilterDot(sampler2D tex, float2 texCoord, int2 texSize)
{
    // NOTE:
    // Use NTSC gray because it doesnt use division.

    float4 color = tex2D(tex, texCoord);
    float  gray  = 0.298912f * color.r + 0.586611f * color.g + 0.114478f * color.b;

    int2 texCoordPx = int2(round((texCoord.x * texSize.x) + 0.5) % 4,
                           round((texCoord.y * texSize.y) + 0.5) % 4);

    #ifdef _DITHER_BAYER

    return DitherMatrixBayer[texCoordPx.x][texCoordPx.y] < gray ? float4(0, 0, 0, color.a) : float4(1, 1, 1, color.a);

    #else // _DITHER_DOT

    return DitherMatrixDot[texCoordPx.x][texCoordPx.y] < gray ? float4(0, 0, 0, color.a) : float4(1, 1, 1, color.a);

    #endif
}

#endif // IMAGE_FILTER_LIBRARY_INCLUDED