# Godot Palette Lighting
Palette-based lighting system for Godot 4.7 inspired by Sonic Adventure for Dreamcast's Lantern Engine

Each surface samples a diffuse and additive color based on its angle to a light direction. You can give shaded surfaces a different hue, add colored highlights, or brighten both ends of the palette or "color ramp".

## How it works
The shader maps the full normal/light dot product onto a 256-color ramp, then combines the sampled colors with the texture:

```text
final color = texture * tint * diffuse ramp + additive ramp
```

Additive lighting can brighten dark parts of a texture. It doesn't cast light onto other objects.

By default, the ramps are sampled per vertex and the resulting colors are interpolated across triangles. Pixel sampling is available too, though it gives a different look on coarse meshes. Encoded RGB arithmetic is the default; you can switch to linear arithmetic in the material inspector.

## Add to scene
1. Create a `PaletteLightingMaterial` and assign it to a mesh's **Material Override** or a surface material.
2. Set its base texture and tint.
3. Add a `PaletteLightingEnvironment` node to the scene.
4. Assign a profile from `profiles/` to the controller's `profile` property.
5. Add your material to the controller's `materials` array.

Several meshes can share one material. Give them separate materials if they need different palette slots or settings. For independent lighting in different scenes, use separate material resources as well.

The controller supplies the light direction and profile blend. The material controls which diffuse and additive ramps it uses. Start with both slots at 0; the demo uses diffuse slot 2 for its figure to show how objects can have different lighting within the same scene.

Normal Godot lights don't supply the palette colors. The basic setup works with just the controller. Existing environment fog and post-processing still affect the result.

## Create profile
Create a `PaletteLightingProfile`, enable `is_using_gradients`, and assign diffuse and additive `Gradient` resources. Edit their color stops in the inspector. `profiles/authored_example.tres` is a starting point.

Generated profiles use the same ramp pair for all eight slots. To give different slots their own colors, supply a **256 * 16 PNG atlas**:

- Row `2 * slot` holds the diffuse ramp.
- Row `2 * slot + 1` holds the additive ramp.
- 0 is toward light; 255 is away.

Import atlases with **lossless compression**, **mipmaps disabled**, and **automatic 3D compression disabled**. Keep the import settings included with the sample palettes. Alpha is ignored.

## Shadows
Enable `is_shadow_receiving_enabled` on the material and add one shadow-enabled `DirectionalLight3D`. Align it with the controller's light direction: `direction_toward_light` points toward the source, while the light emits rays in the opposite direction.

`shadow_strength` sets how much palette lighting is removed in a cast shadow. At 0 there's no darkening; at 1 a fully shadowed surface can go black. Shadows are off by default on new materials.

Use one directional light for this setup. Multiple directional lights add together, and point/spot lights are ignored. **Force Vertex Shading** must be disabled for shadow receiving to work.

## Limitations
The material supports opaque surfaces and alpha cutout, but not translucent blending. It replaces a mesh's material lighting, so custom shaders need their own integration.

For that, `palette_lighting.gdshaderinc` exposes the ramp lookup and color-combination functions. The controller can also register ordinary `ShaderMaterial` resources that use its uniforms.

Leave vertex-color multiplication off unless your mesh stores colors there. Data such as material IDs needs to be handled separately.
