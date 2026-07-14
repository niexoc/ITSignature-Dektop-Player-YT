<# : chooser
@echo off
setlocal
set "URI=%~1"
if "%URI%"=="" set /p "URI=Enter URI: "
set "CONSTANT=0771234567"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content '%~f0' | Select-Object -Skip 9 | Out-String | Invoke-Expression"
exit /b
#>
$uri = $env:URI
$constant = $env:CONSTANT

if (-not $uri.Contains('token=')) { Write-Host "Invalid URI"; Read-Host; exit }
try {
    # 1. Parse JSON token from URI
    $token = [uri]::UnescapeDataString(($uri -split 'token=')[1].Split('&')[0])
    $jsonStr = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($token))
    $json = ConvertFrom-Json -InputObject $jsonStr
    
    # 2. Extract user_id and ciphertext payload automatically
    $userId = $json.user_id
    $vid = $json.selected_video_id
    
    # 3. Automatically calculate SHA256 key from "user_id.constant"
    $keyString = "$userId.$constant"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $key = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($keyString))
    
    # 4. Decrypt video ID
    $bytes = [Convert]::FromBase64String($vid)
    $iv = $bytes[0..15]
    $cipher = $bytes[16..31]
    
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Key = $key
    $aes.IV = $iv
    $dec = $aes.CreateDecryptor()
    $pt = $dec.TransformFinalBlock($cipher, 0, $cipher.Length)
    $videoID = [System.Text.Encoding]::UTF8.GetString($pt)
    
    # 5. UI Rendering & Centering
    Clear-Host
    $art = @'
 ___ _____ ____    _____ _   _  ____ _  _______ ____  
|_ _|_   _/ ___|  |  ___| | | |/ ___| |/ / ____|  _ \ 
 | |  | | \___ \  | |_  | | | | |   | ' /|  _| | |_) |
 | |  | |  ___) | |  _| | |_| | |___| . \| |___|  _ < 
|___| |_| |____/  |_|    \___/ \____|_|\_\_____|_| \_\

b y   n i e x o c
'@ -split "`n"

    $w = $Host.UI.RawUI.WindowSize.Width
    $h = $Host.UI.RawUI.WindowSize.Height
    
    $totalHeight = $art.Length + 3
    $vPadding = [math]::Max(0, [int](($h - $totalHeight) / 2) - 1)
    
    for ($i=0; $i -lt $vPadding; $i++) { Write-Host "" }
    foreach ($line in $art) {
        $trimmed = $line.TrimEnd("`r")
        $hPadding = [math]::Max(0, [int](($w - $trimmed.Length) / 2))
        Write-Host (" " * $hPadding + $trimmed) -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host ""

    # Centered Progress Bar
    $barWidth = 30
    $steps = 20
    $sleepTime = 40
    $barLeft = [math]::Max(0, [int](($w - ($barWidth + 2)) / 2))

    for ($i = 0; $i -le $steps; $i++) {
        $filled = [int](($i / $steps) * $barWidth)
        $unfilled = $barWidth - $filled
        $barStr = "[" + ("#" * $filled) + ("." * $unfilled) + "]"
        Write-Host ("`r" + (" " * $barLeft) + $barStr) -ForegroundColor Cyan -NoNewline
        Start-Sleep -Milliseconds $sleepTime
    }
    Write-Host ""

    Start-Process "https://www.youtube.com/watch?v=$videoID"
} catch {
    Write-Host "Error during decryption: $_"
    Read-Host
}
