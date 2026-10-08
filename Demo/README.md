# RealityHD demo (visionOS)


`Demo/` holds a visionOS app (xcodegen; `.xcodeproj` is gitignored). The menu window lists scenes, sky
and seed; each opens a full ImmersiveSpace with the scene's camera hint at the viewer's feet.

```sh
cd Demo && xcodegen generate && open RealityHDDemo.xcodeproj
# simulator: launch args -scene forest-glade -sky golden -seed 2 -yaw -30 -hideMenu YES
```
