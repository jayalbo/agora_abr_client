# iOS App Icon

The iOS app icon set is here:

- `AgoraABRAudience/Resources/Assets.xcassets/AppIcon.appiconset/`

The editable source image is:

- `AgoraABRAudience/Resources/Assets.xcassets/AppIcon.appiconset/app-icon-source-1024.png`

## Replace with your own icon

1. Prepare a PNG file that is:
   - `1024x1024` pixels
   - square
   - PNG format
   - sRGB color profile
   - no transparency (recommended for App Store)
2. Put it at:
   - `AgoraABRAudience/Resources/Assets.xcassets/AppIcon.appiconset/app-icon-source-1024.png`
3. Regenerate all required iOS icon sizes:

```bash
cd agora_abr_ios_client
python3 scripts/generate_ios_app_icons.py
```

Or provide a file directly:

```bash
cd agora_abr_ios_client
python3 scripts/generate_ios_app_icons.py --input /path/to/your-icon-1024.png
```

Then regenerate/open the Xcode project:

```bash
xcodegen generate
open AgoraABRAudience.xcodeproj
```
