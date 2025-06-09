@vs vs
layout(binding=0) uniform vs_params {
    mat4 viewMatrix;
    vec4 textureVec;
};

in vec4 position0;
in vec4 color0;
in vec4 texcoord0;

out vec4 color;
out vec4 uv;

void main() {
    gl_Position = viewMatrix * position0;
    color = color0;
    uv = texcoord0 / textureVec;
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

@program texture vs fs