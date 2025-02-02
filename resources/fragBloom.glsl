#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;

// Output fragment color
out vec4 finalColor;

uniform float bloom_spread = .5;
uniform float bloom_intensity = .2;

void main()
{
    ivec2 size = textureSize(texture0, 0);

    float uv_x = fragTexCoord.x * size.x;
    float uv_y = fragTexCoord.y * size.y;

    vec4 sum = vec4(0.0);
    for (int n = 0; n < 9; ++n) {
        uv_y = (fragTexCoord.y * size.y) + (bloom_spread * float(n - 4));
        vec4 h_sum = vec4(0.0);
        h_sum += texelFetch(texture0, ivec2(uv_x - (4.0 * bloom_spread), uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x - (3.0 * bloom_spread), uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x - (2.0 * bloom_spread), uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x - bloom_spread, uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x, uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x + bloom_spread, uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x + (2.0 * bloom_spread), uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x + (3.0 * bloom_spread), uv_y), 0);
        h_sum += texelFetch(texture0, ivec2(uv_x + (4.0 * bloom_spread), uv_y), 0);
        sum += h_sum / 9.0;
    }

    finalColor = sum * bloom_intensity; // texture2D(texture0, fragTexCoord) - (sum );
}
