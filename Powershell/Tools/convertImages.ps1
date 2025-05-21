<#
.SYNOPSIS
    Converts images in a folder to a specified format.

.DESCRIPTION
    This script asks for a source folder and a target file format (jpg, png, webp, gif, bmp, tiff), converts all images in the source folder to the specified format, and saves them to a new folder named <sourcefolder>_<format>.
    The script uses FFmpeg for conversion, so ensure FFmpeg is installed and available in your PATH.
#>

function Get-FFMPEGOptions {
    param(
        [string]$outputFormat
    )

    switch ($outputFormat) {
        "jpg" { return "-c:v mjpeg -q:v 2" }
        "png" { return "-c:v png -compression_level 9" }
        "webp" { return "-c:v libwebp -lossless 1" }
        "gif" { return "-c:v gif" }
        "bmp" { return "-c:v bmp" }
        "tiff" { return "-c:v tiff" }
        default { return "" }
    }
}

# Check ffmpeg installation
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host "FFmpeg found. Proceeding with image conversion..."
} else {
    Write-Host "FFmpeg is NOT installed or not on your PATH."
    Write-Host "Please install FFmpeg from https://ffmpeg.org/download.html"
    Write-Host "Press Enter to exit" -NoNewline
    Read-Host
    exit
}

# Ask to choose file format
$supportedFormats = @("jpg", "png", "webp", "gif", "bmp", "tiff")
do{
    $outFormat = Read-Host "Choose the output file format (jpg, png, webp, gif, bmp, tiff) [default: jpg]"
    if (-not $outFormat) {
        $outFormat = "jpg"
    } elseif ($outFormat -notin $supportedFormats) {
        Write-Host "Invalid format. Please choose from the given options."
    }
} until ($outFormat -in $supportedFormats)
Write-Host "Output format set to $outFormat"

# Ask for source folder
do {
    $SourceFolder = Read-Host "Enter the path to the folder containing images to convert"
    if (-not (Test-Path $SourceFolder)) {
        Write-Host "The specified folder does not exist. Please try again."
    }
} until (Test-Path $SourceFolder)

# Prepare destination folder path
$parentPath    = Split-Path -Parent $SourceFolder
$folderName    = Split-Path -Leaf   $SourceFolder
$destFolder    = Join-Path $parentPath ("${folderName}_${outFormat}")

if (-not (Test-Path $destFolder)) {
    New-Item -ItemType Directory -Path $destFolder | Out-Null
}

# Image file extensions to process
$extensions = @('*.jpg','*.jpeg','*.webp','*.png','*.bmp','*.gif','*.tiff')
$allFiles = foreach ($ext in $extensions) {
    Get-ChildItem -Path $SourceFolder -Recurse -File -Filter $ext
}
$totalFiles = $allFiles.Count
if ($totalFiles -eq 0) {
    Write-Host "No image files found in the specified folder. Exiting..."
    return
}

$successfulFiles = 0
$skippedFiles = 0
$failedFilePaths = @()
$outFormat = "."+$outFormat.ToLower()

# Process each image in the folder and subfolders (recurse)
for ($i = 0; $i -lt $totalFiles; $i++) {

    $file = $allFiles[$i]

    # Progress bar
    Write-Progress `
        -Activity "Converting images " `
        -Status "$($i+1) of $totalFiles : $($file.Name)" `
        -PercentComplete (($i + 1) / $totalFiles * 100)

    # Prepare output file path
    $outputFileName = [System.IO.Path]::ChangeExtension($file.FullName, $outFormat)
    $outputFilePath = Join-Path -Path $destFolder -ChildPath (Split-Path -Leaf $outputFileName)

    # Check if the file already exists
    if (Test-Path $outputFilePath) {
        Write-Host "File already exists: $outputFilePath. Skipping..."
        $skippedFiles++
        continue
    }

    # Convert image using ffmpeg
    try {
        $ffmpegOptions = Get-FFMPEGOptions -outputFormat $outFormat.TrimStart('.')
        $ffmpegOptions = $ffmpegOptions -split '\s+' # Split options into an array
        & ffmpeg -hide_banner -loglevel quiet -nostats -i "$($file.FullName)" @ffmpegOptions "$($outputFilePath)"
        if ($LASTEXITCODE -eq 0) {
            $successfulFiles++
        } else {
            $failedFilePaths += $file.FullName
        }
    } catch {
        Write-Host "Error processing file: $_"
        $failedFilePaths += $file.FullName
    }
}

Write-Host "Conversion completed."
if($skippedFiles -gt 0) {
    Write-Host "$skippedFiles files were skipped because they already exist in the destination folder."
}
Write-Host
Write-Host "$successfulFiles / $totalFiles files were successfully converted and saved to $destFolder."
if($failedFilePaths.Count -gt 0) {
    Write-Host "The following files failed to convert:"
    foreach ($filePath in $failedFilePaths) {
        Write-Host "- $filePath"
    }
}
Write-Host "Press Enter to exit."
Read-Host