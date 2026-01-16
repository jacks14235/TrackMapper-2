#include <metal_stdlib>
using namespace metal;

kernel void warp(
    texture2d<float, access::sample> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    // contains:   [topleft x, topleft y, right vector x, right vector y, down vector x, down vector y,
    //              number of points, xTrans, yTrans, xScale, yScale]
    device const float *info [[buffer(0)]],
    device const float *points [[buffer(1)]], // nx2 matrix in column-major order
    device const float *D [[buffer(2)]], // 3x2 matrix in column-major order
    device const float *c [[buffer(3)]], // 2xn matrix in column-major order
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float width = float(outTexture.get_width());
    float height = float(outTexture.get_height());
    float2 uv = float2(float(gid.x) / float(width), float(gid.y) / float(height));
    
    int n = int(info[6]);
    float2 upperLeft = float2(info[0], info[1]);
    float2 rightVec = float2(info[2], info[3]);
    float2 downVec = float2(info[4], info[5]);
    float2 coord = upperLeft + uv.x * rightVec + uv.y * downVec;
    
    // left = P @ D, where P is the coordinate with a 1 appended to the 3rd dim
    float2 left = float2(0, 0);
    left[0] = coord[0] * D[0] + coord[1] * D[1] + D[2];
    left[1] = coord[0] * D[3] + coord[1] * D[4] + D[5];
    
    // right = c @ phi, phi is d*d*log(d) where d is distance
    float2 right = float2(0, 0);
    for (int i = 0; i < n; i++) {
        float2 point = float2(points[i], points[i+n]);
        float distance = length(coord - point);
        float phi = distance * distance * log(distance);
        right.x += c[i*2] * phi;
        right.y += c[i*2 + 1] * phi;
    }
    
    float2 result = left - right;
    result.x = result.x / info[9];
    result.y = result.y / info[10];
    result.x = result.x - info[7];
    result.y = result.y - info[8];
    if (result.x < 0 || result.x > 1 || result.y < 0 || result.y > 1) {
        outTexture.write(float4(0.0,0.0,0.0,0.0), gid);
        return;
    }
    
    constexpr sampler s(filter::bicubic, address::clamp_to_edge);
    float4 color = inTexture.sample(s, result);

    outTexture.write(color, gid);
}

