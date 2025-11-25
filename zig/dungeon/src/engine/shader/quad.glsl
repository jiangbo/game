@vs vs
layout(binding=0) uniform vs_params {
    mat4 viewMatrix;
    vec4 textureVec;
};

in vec4 vertex_position;
in vec2 vertex_size;
in vec4 vertex_texture;
in vec4 vertex_color;

out vec4 color;
out vec2 uv;

void main() {
    // 顶点
    vec2 corner = vec2(gl_VertexIndex & 1, gl_VertexIndex >> 1 & 1);
    vec2 position = corner * vertex_size;
    vec4 depthPosition = vec4(position, 0, 0) + vertex_position;
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