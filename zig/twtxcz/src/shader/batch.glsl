#pragma sokol @header const zm = @import("zmath")
#pragma sokol @ctype mat4 zm.Mat
#pragma sokol @ctype vec4 zm.Vec

@vs vs
layout(binding=0) uniform vs_params {
    mat4 vp;
};

struct BatchInstance
{
    vec4 position;
    float width;
    float height;
    float rotation;
    float padding;
    vec4 texcoord;
    vec4 color;
};

layout(binding=0) readonly buffer SSBO {
    BatchInstance dataBuffer[];
};

out vec4 color;
out vec2 uv;

const uint triangleIndices[6] = {0, 1, 2, 3, 2, 1};
const vec2 vertexPos[4] = {
    {0.0f, 0.0f},
    {1.0f, 0.0f},
    {0.0f, 1.0f},
    {1.0f, 1.0f}
};

void main() {

    const uint VertexIndex = uint(gl_VertexIndex);
    uint vert = triangleIndices[VertexIndex % 6];
    BatchInstance sprite = dataBuffer[VertexIndex / 6];

    vec4 uvwh = sprite.texcoord;
    vec2 texcoord[4] = {
        {uvwh.x,          uvwh.y         },
        {uvwh.x + uvwh.z, uvwh.y         },
        {uvwh.x,          uvwh.y + uvwh.w},
        {uvwh.x + uvwh.z, uvwh.y + uvwh.w}
    };

    float c = cos(sprite.rotation);
    float s = sin(sprite.rotation);

    vec2 coord = vertexPos[vert];
    coord *= vec2(sprite.width, sprite.height);
    mat2 rotation = mat2(c, -s, s, c);
    coord = coord * rotation;

    vec3 coordWithDepth = vec3(coord + sprite.position.xy, sprite.position.z);

    gl_Position = vp * vec4(coordWithDepth, 1.0);
    color = sprite.color;
    uv = texcoord[vert];
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

@program batch vs fs