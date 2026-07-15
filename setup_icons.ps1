# Icon Setup Script for new_flutter
# Run this script to copy icons from .tmp_icons to the Flutter project

$tmpIcons = "..\. tmp_icons"
$flutterRoot = $PSScriptRoot

# Android icon sizes and destinations
$androidMipmaps = @(
    @{ src = "android\mipmap-ldpi\ic_launcher.png"; dst = "android\app\src\main\res\mipmap-ldpi\ic_launcher.png" },
    @{ src = "android\mipmap-mdpi\ic_launcher.png"; dst = "android\app\src\main\res\mipmap-mdpi\ic_launcher.png" },
    @{ src = "android\mipmap-hdpi\ic_launcher.png"; dst = "android\app\src\main\res\mipmap-hdpi\ic_launcher.png" },
    @{ src = "android\mipmap-xhdpi\ic_launcher.png"; dst = "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" },
    @{ src = "android\mipmap-xxhdpi\ic_launcher.png"; dst = "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" },
    @{ src = "android\mipmap-xxxhdpi\ic_launcher.png"; dst = "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" }
)

Write-Host "Setting up Android icons..."
foreach ($item in $androidMipmaps) {
    $srcPath = Join-Path "..\. tmp_icons" $item.src
    $dstPath = Join-Path $flutterRoot $item.dst
    if (Test-Path $srcPath) {
        $dstDir = Split-Path $dstPath
        New-Item -ItemType Directory -Force $dstDir | Out-Null
        Copy-Item $srcPath $dstPath -Force
        Write-Host "  Copied: $($item.dst)"
    } else {
        Write-Host "  Missing: $srcPath"
    }
}

# iOS icons
$iosIconSet = "ios\Runner\Assets.xcassets\AppIcon.appiconset"
$srcIosDir = "..\. tmp_icons\ios\AppIcon.appiconset"
if (Test-Path $srcIosDir) {
    Write-Host "Setting up iOS icons..."
    $dstIosDir = Join-Path $flutterRoot $iosIconSet
    New-Item -ItemType Directory -Force $dstIosDir | Out-Null
    Copy-Item "$srcIosDir\*" $dstIosDir -Recurse -Force
    Write-Host "  iOS icons copied to $dstIosDir"
} else {
    Write-Host "iOS icon source not found: $srcIosDir"
}

Write-Host ""
Write-Host "Done! Rebuild the app to apply icons."
