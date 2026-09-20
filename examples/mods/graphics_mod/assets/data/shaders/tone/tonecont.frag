// tonecont.frag -- версия шейдера из мода.
// Модлоадер подсовывает её вместо data/shaders/tone/tonecont.frag.
// Этот вариант используется, когда DOF выключен (по умолчанию).
//
// Добавлено: резкость (unsharp mask). Параметрами пресета такого не сделать:
// нужны соседние точки картинки, а это уже сам шейдер.

//
// tone mapping
//
uniform sampler2D texUnit0;
uniform sampler2D texUnit1;
uniform sampler2D texUnit2;
uniform float blurOpacity;
uniform float hdrIntencity;
uniform vec4 mulColor;
uniform float brightMax;
//
// contrast+vignette
//
uniform float bright;
uniform float saturate;
uniform float contrast;
uniform float avgLumR;
uniform float avgLumG;
uniform float avgLumB;
uniform float afterBlur;
uniform float vignetteInner;  // 0.7 by default
uniform float vignetteOuter;  // 1.75 by default
uniform float vignetteAdjust; // 1.25 by default
//
// contrast+vignette
//
//vec4 desaturate(vec3 color, float desaturation)
//{
//   const vec3 grayxfer=vec3(0.3, 0.59, 0.11);
//   vec3 gray=vec3(dot(grayxfer, color));
//   return vec4(mix(color, gray, Desaturation), 1.0);
//}
   
// vignetting effect (makes corners of image darker)
float vignette(vec2 pos, float inner, float outer)
{
   float r=length(pos);
   r=vignetteAdjust-smoothstep(inner, outer, r);
   return r;
}

// For all settings: 1.0 = 100% 0.5=50% 1.5 = 150%
vec3 contrastSaturationBrightness(vec3 color, float brt, float sat, float con)
{
   //Increase or decrease theese values to adjust r, g and b color channels seperately
   //const float avglumr=0.5;
   //const float avglumg=0.5;
   //const float avglumb=0.5;
   
   const vec3 lumcoeff=vec3(0.2125, 0.7154, 0.0721);
   
   vec3 avglumin=vec3(avgLumR, avgLumG, avgLumB);
   vec3 brtcolor=color*brt;
   vec3 intensity=vec3(dot(brtcolor, lumcoeff));
   vec3 satcolor=mix(intensity, brtcolor, sat);
   vec3 concolor=mix(avglumin, satcolor, con);
   return concolor;
}
  
void main()
{
   //
   // tone mapping
   //
   vec4 color0=texture2D(texUnit0, gl_TexCoord[0].xy);
   vec4 color1=texture2D(texUnit1, gl_TexCoord[1].xy);
   vec4 color2=texture2D(texUnit2, gl_TexCoord[2].xy);
   color0+=color1*blurOpacity;
   //float y=dot(vec4(0.30, 0.59, 0.11, 0.0), color0);
   float yd=hdrIntencity*(hdrIntencity/brightMax+1.0)/(hdrIntencity+1.0);
   color0*=yd/vignetteAdjust+color2*mulColor;
   //
   // contrast+vignette
   //
   color0.xyz=contrastSaturationBrightness(color0.xyz, bright, saturate, contrast);
   //
   // sharpen (unsharp mask)
   //
   // Шаг в экранных координатах: размер текстуры шейдеру не передают, поэтому берём под 1920x1080.
   const float texel=0.00052; // step - имя встроенной функции GLSL, брать его нельзя
   const float amount=0.35;
   vec3 around=texture2D(texUnit0, gl_TexCoord[0].xy+vec2( texel, 0.0)).xyz
              +texture2D(texUnit0, gl_TexCoord[0].xy+vec2(-texel, 0.0)).xyz
              +texture2D(texUnit0, gl_TexCoord[0].xy+vec2( 0.0, texel)).xyz
              +texture2D(texUnit0, gl_TexCoord[0].xy+vec2( 0.0,-texel)).xyz;
   color0.xyz+=(color0.xyz-around*0.25)*amount;
   color0=mix(color0, color1, vec4(afterBlur));
   // vignette effect
   vec2 crd=2.0*gl_TexCoord[0].xy-1.0;
   color0*=vignette(crd, vignetteInner, vignetteOuter);
   gl_FragColor=color0;
}