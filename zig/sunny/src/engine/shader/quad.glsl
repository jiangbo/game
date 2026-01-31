@vs vs
layout(binding=0) uniform vs_params {
    mat4 viewMatrix;
    vec4 textureVec;
};

in vec2 vertex_position; // X Y 像素坐标
in float vertex_radian; // 旋转的弧度
in float padding; // 占位
in vec2 vertex_scale; // 缩放，像素尺寸
in vec2 vertex_pivot; // 旋转中心，归一化坐标
in vec4 vertex_texture; // 纹理坐标，xy是偏移量，zw是缩放
in vec4 vertex_color; // 颜色

out vec4 color;
out vec2 uv;

void main() {
    // 顶点
    vec2 corner = vec2(gl_VertexIndex & 1, gl_VertexIndex >> 1 & 1);

    // 先缩放，缩放必须要在旋转之前做
    vec2 scaledCorner = corner * vertex_scale;
    vec2 scaledPivot  = vertex_pivot * vertex_scale;
    vec2 scaled = scaledCorner - scaledPivot;
    // 再应用旋转
    float cosA = cos(vertex_radian);
    float sinA = sin(vertex_radian);
    vec2 rotated = mat2(cosA, sinA, -sinA, cosA) * scaled;
    // 最后平移回原位
    vec2 localPos = rotated + scaledPivot;
    vec4 depthPosition = vec4(localPos + vertex_position.xy, 0, 1);
    gl_Position = viewMatrix * depthPosition;

    // 纹理
    color = vertex_color;
    uv = vertex_texture.xy + corner * vertex_texture.zw;
    uv *= textureVec.xy;
}
@end

@fs fs

layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec4 color;
in vec2 uv;
out vec4 frag_color;

void main() {
     frag_color = texture(sampler2D(tex, smp), uv) * color;
}
@end

@program quad vs fs