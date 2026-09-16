shader_type spatial;
uniform sampler2D ground_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int biome = 0;
varying vec3 world;
varying float slope;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;slope=1.0-NORMAL.y;}
void fragment(){
 vec2 uv=world.xz/24.0;
 vec3 near_col=texture(ground_color,uv).rgb;
 vec3 macro=texture(ground_color,uv*.083).rgb;
 vec3 stone=texture(rock_color,uv*.7).rgb;
 float rock_mix=smoothstep(.045,.35,slope)*.7;
 if(biome==1){rock_mix=max(rock_mix,(1.0-smoothstep(-6.0,12.0,world.y))*.4);}
 ALBEDO=mix(near_col*(.65+macro*.6),stone,rock_mix);
 if(biome==1){ALBEDO*=.68;}
 NORMAL_MAP=texture(ground_normal,uv).rgb;
 NORMAL_MAP_DEPTH=.65;
 ROUGHNESS=texture(ground_rough,uv).r;
}
