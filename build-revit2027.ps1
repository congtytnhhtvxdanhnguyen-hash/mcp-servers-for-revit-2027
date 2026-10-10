# Build lai mcp-servers-for-revit cho Revit 2027 (.NET 10) va cai vao Addins\2027
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Start-Transcript -Path (Join-Path $root 'build-log.txt') -Force | Out-Null
try {
    # 1. Kiem tra .NET 10 SDK
    $hasSdk = $false
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $hasSdk = [bool]((& dotnet --list-sdks) -match '^10\.')
    }
    if (-not $hasSdk) {
        Write-Host '>> Chưa có .NET 10 SDK, đang cài bằng winget...' -ForegroundColor Yellow
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw 'Máy không có winget. Tải và cài .NET 10 SDK (x64) tại https://dotnet.microsoft.com/download/dotnet/10.0 rồi chạy lại.'
        }
        winget install --id Microsoft.DotNet.SDK.10 -e --accept-source-agreements --accept-package-agreements
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH','User')
    }
    & dotnet --version

    # 2. Build plugin + bo lenh cho Revit 2027
    Write-Host '>> Build plugin...' -ForegroundColor Cyan
    & dotnet build "$root\plugin\RevitMCPPlugin.csproj" -c "Release R27"
    if ($LASTEXITCODE -ne 0) { throw 'Build plugin bị lỗi (xem build-log.txt).' }
    Write-Host '>> Build bộ lệnh...' -ForegroundColor Cyan
    & dotnet build "$root\commandset\RevitMCPCommandSet.csproj" -c "Release R27"
    if ($LASTEXITCODE -ne 0) { throw 'Build bộ lệnh bị lỗi (xem build-log.txt).' }

    $out = "$root\plugin\bin\AddIn 2027 Release R27\revit_mcp_plugin"
    if (-not (Test-Path "$out\Commands\RevitMCPCommandSet\2027\RevitMCPCommandSet.dll")) {
        throw "Không thấy file build ở $out"
    }

    # 3. Revit phai dang tat
    while (Get-Process Revit -ErrorAction SilentlyContinue) {
        Read-Host 'Revit đang mở. Hãy LƯU và ĐÓNG Revit, rồi nhấn Enter để tiếp tục'
    }

    # 4. Sao luu ban cu va cai ban moi
    $dest = "$env:APPDATA\Autodesk\Revit\Addins\2027\revit_mcp_plugin"
    if (Test-Path $dest) {
        $bak = Join-Path $root ("backup-revit_mcp_plugin-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item $dest $bak -Recurse
        Write-Host ">> Đã sao lưu bản cũ vào: $bak"
        Remove-Item "$dest\Commands\RevitMCPCommandSet\2026" -Recurse -Force -ErrorAction SilentlyContinue
    }
    robocopy $out $dest /E /NFL /NDL /NJH /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Chép file vào Addins lỗi (robocopy $LASTEXITCODE)" }
    $global:LASTEXITCODE = 0

    Write-Host ''
    Write-Host '=== XONG: đã cài bản build cho Revit 2027 ===' -ForegroundColor Green
    Write-Host 'Mở Revit 2027 > tab Add-Ins > bấm Revit MCP Switch.'
}
catch {
    Write-Host ''
    Write-Host "LỖI: $_" -ForegroundColor Red
}
finally {
    Stop-Transcript | Out-Null
    Read-Host 'Nhấn Enter để đóng cửa sổ'
}
