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
 vec3 mid=texture(ground_color,uv*.31).rgb;
 vec3 macro=texture(ground_color,uv*.083).rgb;
 vec3 far_dune=texture(ground_color,uv*.028).rgb;
 vec3 stone=texture(rock_color,uv*.7).rgb;
 float rock_mix=smoothstep(.045,.35,slope)*.72;
 if(biome==1){rock_mix=max(rock_mix,(1.0-smoothstep(-6.0,12.0,world.y))*.42);}
 // Soft dune ridges / height mottling without extra textures.
 float ridge=sin(world.x*.045)*cos(world.z*.038)*.5+.5;
 float wash=sin((world.x+world.z)*.018)*.5+.5;
 vec3 sand_blend=near_col*(.55+macro*.35+mid*.25);
 sand_blend=mix(sand_blend,far_dune*1.05,ridge*.22);
 sand_blend=mix(sand_blend,sand_blend*vec3(1.08,.98,.88),wash*.18);
 ALBEDO=mix(sand_blend,stone*(.85+macro*.2),rock_mix);
 if(biome==0){ALBEDO*=vec3(1.06,1.0,.92);}
 if(biome==1){ALBEDO*=vec3(.62,.72,.88);}
 if(biome==2){ALBEDO*=vec3(1.05,.88,.78);}
 if(biome==3){
  ALBEDO*=vec3(.48,.58,.78);
  // Cool moon wash + faint oasis glow near water pocket (x~120,z~-40).
  float oasis=1.0-smoothstep(70.0,160.0,length(world.xz-vec2(120.0,-40.0)));
  ALBEDO=mix(ALBEDO,ALBEDO*vec3(.7,1.05,1.15),oasis*.35);
 }
 NORMAL_MAP=texture(ground_normal,uv).rgb;
 NORMAL_MAP_DEPTH=biome==3?.55:.78;
 ROUGHNESS=clamp(texture(ground_rough,uv).r*(biome==3?.92:1.0)+rock_mix*.12,.18,.97);
}
