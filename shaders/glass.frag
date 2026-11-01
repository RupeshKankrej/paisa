#include <flutter/runtime_effect.glsl>

// Bends the backdrop near a rounded rectangle's edge, as a glass lens does.
// As an image filter, frag coords and uSize are physical pixels of the screen.
uniform vec2 uSize; // set by the engine
uniform vec4 uRect; // x, y, width, height
uniform float uRadius;
uniform float uMagnify; // 1 leaves the middle as it is
uniform float uFringe; // colour split at the bent edge
uniform float uBend; // 0 no bending, 1 full
uniform float uBand; // how far in from the edge the bending reaches
uniform sampler2D uTexture;

out vec4 fragColor;

float edgeDistance(vec2 p, vec2 half_, float r) {
  vec2 q = abs(p) - half_ + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 half_ = uRect.zw * 0.5;
  vec2 p = frag - uRect.xy - half_;
  float r = min(uRadius, min(half_.x, half_.y));
  float d = edgeDistance(p, half_, r);

  float band = min(min(half_.x, half_.y) * 0.9, uBand);
  float t = clamp(1.0 + d / band, 0.0, 1.0);
  vec2 slope = vec2(
    edgeDistance(p + vec2(1.0, 0.0), half_, r) -
      edgeDistance(p - vec2(1.0, 0.0), half_, r),
    edgeDistance(p + vec2(0.0, 1.0), half_, r) -
      edgeDistance(p - vec2(0.0, 1.0), half_, r)
  );
  vec2 bend = normalize(slope + 0.0001) * t * t * t * band * 0.8 * uBend;

  // Each channel bends a little differently, the fringe real glass shows.
  vec2 source = uRect.xy + half_ + p / uMagnify;
  vec4 g = texture(uTexture, (source - bend) / uSize);
  fragColor = vec4(
    texture(uTexture, (source - bend * (1.0 + uFringe)) / uSize).r,
    g.g,
    texture(uTexture, (source - bend * (1.0 - uFringe)) / uSize).b,
    g.a
  );
}
