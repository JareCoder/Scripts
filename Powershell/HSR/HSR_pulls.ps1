# Make sure Selenium is installed
Install-Module -Name Selenium -Scope CurrentUser

Import-Module Selenium

# Run the warp-link command to copy your warp URL to the clipboard.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Invoke-Expression (New-Object Net.WebClient).DownloadString("https://gist.githubusercontent.com/Star-Rail-Station/2512df54c4f35d399cc9abbde665e8f0/raw/get_warp_link_os.ps1?cachebust=srs")

# Wait for clipboard.
Start-Sleep -Seconds 1
$warpURL = Get-Clipboard

# FireFox profile path. Example path: C:\Users\<username>\AppData\Roaming\Mozilla\Firefox\Profiles\<profile_folder>
$profilePath = ""

# Create a Firefox profile from folder.
Write-Host "Fetching profile..."
$firefoxProfile = New-Object OpenQA.Selenium.Firefox.FirefoxProfile($profilePath)

# Create Firefox options and assign profile.
$firefoxOptions = New-Object OpenQA.Selenium.Firefox.FirefoxOptions
$firefoxOptions.Profile = $firefoxProfile

# Start the browser with user profile and navigate to Warp Tracker.
Write-Host "Opening browser..."
$driver = New-Object OpenQA.Selenium.Firefox.FirefoxDriver($firefoxOptions)
$driver.Navigate().GoToUrl("https://starrailstation.com/en/warp#import")

# Wait for the page to load.
Start-Sleep -Seconds 1

# Find the Warp URL textbox.
try {
    $warpInput = $driver.FindElementByXPath("//input[@placeholder='Paste your Warp Records URL here']")
} catch {
    Write-Host "Could not locate the warp textbox element. Please verify the element's selector."
    $driver.Quit()
    exit
}

# Enter the warp URL into the input field.
$warpInput.SendKeys($warpURL)

# Find and click the import button at the bottom of the page.
try {
    $importButtons = $driver.FindElementsByXPath("//button[contains(text(),'Import')]")
    $lastImportButton = $importButtons[$importButtons.Count - 1]
} catch {
    Write-Host "Could not locate the import button. Please verify the element's selector."
    $driver.Quit()
    exit
}

$lastImportButton.Click()

Write-Host "Warp URL imported successfully."