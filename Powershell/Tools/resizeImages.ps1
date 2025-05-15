<#
.SYNOPSIS
    Resizes images in a folder to fit within specified dimensions, preserving aspect ratio.

.DESCRIPTION
    This script asks for a source folder and a maximum size (format WIDTHxHEIGHT), resizes all images in the source folder so they fit within those bounds without stretching, and saves them to a new folder named <sourcefolder>_<WIDTHxHEIGHT>.
#>

# Ask for source folder
do {
    $SourceFolder = Read-Host "Enter the path to the folder containing images to resize"
    if (-not (Test-Path $SourceFolder)) {
        Write-Host "The specified folder does not exist. Please try again."
    }
} until (Test-Path $SourceFolder)

# Ask for maximum size
$sizePattern = '^[0-9]+x[0-9]+$'
do {
    $MaxSize = Read-Host "Enter the maximum size for the images (WIDTHxHEIGHT, e.g., 800x600)"
    if ($MaxSize -notmatch $sizePattern) {
        Write-Host "Invalid format. Please enter in WIDTHxHEIGHT format."
    }
}until ($MaxSize -match $sizePattern)

# Parse maximum width and height
$size = $MaxSize -split 'x'
[int]$maxWidth = $size[0]
[int]$maxHeight = $size[1]

# Prepare destination folder path
$parentPath    = Split-Path -Parent $SourceFolder
$folderName    = Split-Path -Leaf   $SourceFolder
$destFolder    = Join-Path $parentPath ("${folderName}_${MaxSize}")

# Create destination folder if needed
if (-not (Test-Path $destFolder)) {
    New-Item -ItemType Directory -Path $destFolder | Out-Null
}

# Image file extensions to process
$extensions = @('*.jpg','*.jpeg','*.png','*.bmp','*.gif','*.tiff')
$allFiles = foreach ($ext in $extensions) {
    Get-ChildItem -Path $SourceFolder -Recurse -File -Filter $ext
}
$totalFiles = $allFiles.Count
if ($totalFiles -eq 0) {
    Write-Host "No image files found in the specified folder. Exiting..."
    return
}

$succesfulFiles = 0

# Load System.Drawing for resizing
Add-Type -AssemblyName System.Drawing

# Process each image in the folder and subfolders (recurse)
for ($i = 0; $i -lt $totalFiles; $i++) {

    $file = $allFiles[$i]

    # Progress bar
    $percent = [math]::Round(($i + 1) / $totalFiles * 100, 2)
    Write-Progress `
      -Activity "Resizing images " `
      -Status "$($i+1) of $totalFiles : $($srcFile.Name)" `
      -PercentComplete $percent

    # Build destination path
    $relPath = $file.DirectoryName.Substring($SourceFolder.Length).TrimStart('\')
    $subFolder = Join-Path $destFolder $relPath
    if (-not (Test-Path $subFolder)) { New-Item -ItemType Directory -Path $subFolder | Out-Null }
    $destPath  = Join-Path $subFolder $file.Name

    # Check if file already exists in destination
    if (Test-Path $destPath) {
        Write-Host "File $($destPath) already exists. Skipping."
        continue
    }

    try {
        # Load original image
        $img = [System.Drawing.Image]::FromFile($file.FullName)

        # Calculate scale factor to preserve aspect ratio
        $ratioWidth  = $maxWidth  / $img.Width
        $ratioHeight = $maxHeight / $img.Height
        $scale       = [System.Math]::Min($ratioWidth, $ratioHeight)

        # Determine new dimensions
        $newWidth  = [int]($img.Width  * $scale)
        $newHeight = [int]($img.Height * $scale)

        # Create resized bitmap
        $resized   = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics  = [System.Drawing.Graphics]::FromImage($resized)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)

        $resized.Save($destPath, $img.RawFormat)
        $succesfulFiles++
    }
    catch {
        Write-Warning "Failed to process $($file.FullName): $_"
    }
    finally {
        # Clean up
        if ($graphics) { $graphics.Dispose() }
        if ($resized) { $resized.Dispose() }
        if ($img)     { $img.Dispose() }
    }
}

Write-Host "Resizing completed. $succesfulFiles of $totalFiles images resized and saved to $destFolder."
