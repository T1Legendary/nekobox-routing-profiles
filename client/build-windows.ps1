# Run from a workspace containing kit/, upstream/ and vcpkg/ as in the workflow.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Run([string] $File, [string[]] $Arguments) {
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE" }
}
$root = (Get-Location).Path
$src = Join-Path $root 'upstream'
$kit = Join-Path $root 'kit/client'
$vcpkg = Join-Path $root 'vcpkg'
$build = Join-Path $root 'build'
$dist = Join-Path $root 'dist'
$stage = Join-Path $root 'package'
$version = '5.11.24-weppi-routing-1'
$upstreamCommit = '2dbdb5f6f61efe9830808c44876bfd82b6b5cc9a'
$actualCommit = (& git -C $src rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $upstreamCommit) { throw 'Unexpected upstream source commit' }
Run git @('-C', $src, 'apply', '--check', (Join-Path $kit 'simple-routing.patch'))
Run git @('-C', $src, 'apply', (Join-Path $kit 'simple-routing.patch'))
New-Item -ItemType Directory -Force $build, $dist | Out-Null
Run cl @('/nologo', '/EHsc', '/std:c++20', "/I$src/src", (Join-Path $kit 'tests/simple_rules_test.cpp'), "/Fe:$build/simple-rules-test.exe", "/Fo:$build/simple-rules-test.obj")
Run "$build/simple-rules-test.exe" @()
Run "$vcpkg/bootstrap-vcpkg.bat" @('-disableMetrics')
Run "$vcpkg/vcpkg.exe" @('install', 'thrift', 'boost-filesystem', 'boost-dll', 'boost-headers', 'boost-bimap', 'cpr', 'leveldb', 'yaml-cpp', 'quickjs-ng', '--triplet=x64-windows', '--disable-metrics')
Run cmake @('-S', $src, '-B', $build, '-G', 'Ninja', "-DCMAKE_TOOLCHAIN_FILE=$vcpkg/scripts/buildsystems/vcpkg.cmake", '-DVCPKG_TARGET_TRIPLET=x64-windows', '-DVCPKG_MANIFEST_MODE=OFF', '-DCMAKE_BUILD_TYPE=Release', '-DSKIP_UPDATER=ON', '-DSKIP_JS_UPDATER=OFF', '-DBUILD_GO_PARTS=OFF', "-DNKR_DEFAULT_VERSION=$version", "-DTHRIFT_COMPILER=$vcpkg/installed/x64-windows/tools/thrift/thrift.exe")
Run cmake @('--build', $build, '--config', 'Release', '--parallel', '2')
# Keep the exact released Go core and assets. Only the GUI and its DLLs change.
$original = Join-Path $root 'original.zip'
Invoke-WebRequest 'https://github.com/qr243vbi/nekobox/releases/download/5.11.24/nekobox-5.11.24-windows64.zip' -OutFile $original
if ((Get-FileHash $original -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd677bd26fe62080cba02a6c6b6203b6f803a197b5fc856c409e39dc192dfb7f4') { throw 'Upstream ZIP checksum mismatch' }
$unpack = Join-Path $root 'original'
Expand-Archive $original $unpack
$originalGui = @(Get-ChildItem $unpack -Recurse -File -Filter nekobox.exe)
if ($originalGui.Count -ne 1) { throw 'Unexpected upstream ZIP layout' }
Copy-Item $originalGui[0].Directory.FullName $stage -Recurse
# Replace the complete Qt runtime, including plugins, to avoid mixing Qt builds.
Get-ChildItem $stage -Filter 'Qt6*.dll' -File | Remove-Item -Force
foreach ($plugin in @('platforms', 'styles', 'imageformats', 'iconengines', 'networkinformation', 'tls', 'generic', 'translations')) {
    $path = Join-Path $stage $plugin
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }
}
Copy-Item "$build/nekobox.exe" "$stage/nekobox.exe" -Force
Get-ChildItem $build -Filter '*.dll' -File | Copy-Item -Destination $stage -Force
Run windeployqt @('--release', '--force', '--no-translations', '--no-system-d3d-compiler', '--no-opengl-sw', "$stage/nekobox.exe")
# These packages never contain user settings or personal connection links.
if (Test-Path "$stage/settings") { Remove-Item "$stage/settings" -Recurse -Force }
$originalCore = Join-Path $originalGui[0].Directory.FullName 'nekobox_core.exe'
if ((Get-FileHash $originalCore).Hash -ne (Get-FileHash "$stage/nekobox_core.exe").Hash) { throw 'Core unexpectedly changed' }
Copy-Item "$kit/README-RU.md" "$stage/WEPPi-Simple-Routing.md"
Copy-Item "$kit/simple-routing.patch" "$stage/simple-routing.patch"
Copy-Item "$kit/overlay/*" $stage -Recurse -Force
"[General]`nprogram_version=$version" | Set-Content "$stage/global.ini" -Encoding utf8NoBOM
Copy-Item "$src/LICENSE" "$stage/LICENSE-source.txt"
# Keep all build sources beside the binary artifact for reproducibility.
$sourceStage = Join-Path $root 'source-package'
New-Item -ItemType Directory -Force $sourceStage | Out-Null
& robocopy $src "$sourceStage/nekobox" /E /XD .git /XF .git /NFL /NDL /NJH /NJS
if ($LASTEXITCODE -gt 7) { throw 'Source copy failed' }
Copy-Item $kit "$sourceStage/build-kit" -Recurse
Run tar @('-czf', "$dist/nekobox-$version-source.tar.gz", '-C', $sourceStage, '.')
# A clean-profile startup checks DLL resolution without connecting to a VPN.
$smoke = Join-Path $root 'smoke-test'
Copy-Item $stage $smoke -Recurse
New-Item -ItemType Directory "$smoke/settings" | Out-Null
$qtPlugins = (& qmake -query QT_INSTALL_PLUGINS).Trim()
if ($LASTEXITCODE -ne 0 -or !(Test-Path "$qtPlugins/platforms/qoffscreen.dll")) { throw 'Qt offscreen test plugin not found' }
Copy-Item "$qtPlugins/platforms/qoffscreen.dll" "$smoke/platforms/qoffscreen.dll"
$env:QT_QPA_PLATFORM = 'offscreen' 
$proc = Start-Process "$smoke/nekobox.exe" -WorkingDirectory $smoke -PassThru -RedirectStandardOutput "$root/smoke-stdout.log" -RedirectStandardError "$root/smoke-stderr.log"
try {
    if ($proc.WaitForExit(10000)) { throw "GUI exited during startup with code $($proc.ExitCode)" }
    if (!(Test-Path "$smoke/settings/nekobox.cfg")) { throw 'GUI did not initialize its settings' }
    $smokeError = Get-Content "$root/smoke-stderr.log" -Raw -ErrorAction SilentlyContinue
    if ($smokeError -match 'could not (find|load).*platform plugin|no Qt platform plugin|could not be initialized') { throw 'Qt platform initialization failed' }
    Write-Host 'GUI startup and settings initialization passed.' 
} finally {
    if (!$proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    Get-Process nekobox_core -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item Env:QT_QPA_PLATFORM
    Get-Content "$root/smoke-stderr.log" -Tail 40 -ErrorAction SilentlyContinue
}
$nsis = Get-Command makensis.exe -ErrorAction SilentlyContinue
if (!$nsis) {
    $nsisPath = "${env:ProgramFiles(x86)}/NSIS/makensis.exe"
    if (!(Test-Path $nsisPath)) { throw 'NSIS is required to package the installer' }
} else { $nsisPath = $nsis.Source }
Push-Location $src
try {
Run $nsisPath @('/NOCD', '/V2', "/DSOFTWARE_VERSION=$version", '/DSOFTWARE_NAME=NekoBox', "/DDIRECTORY=$stage", "/DOUTFILE=$dist/nekobox-$version-windows64-installer", "$src/script/windows_installer.nsi")
} finally { Pop-Location }
Compress-Archive -Path "$stage/*" -DestinationPath "$dist/nekobox-$version-windows64.zip" -CompressionLevel Optimal
$manifest = [ordered]@{
    version = $version
    upstream_commit = $upstreamCommit
    build_commit = $env:GITHUB_SHA
    core_sha256 = (Get-FileHash "$stage/nekobox_core.exe").Hash.ToLowerInvariant()
    files = @(Get-ChildItem $dist -File | ForEach-Object { @{ name = $_.Name; sha256 = (Get-FileHash $_.FullName).Hash.ToLowerInvariant(); bytes = $_.Length } })
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content "$dist/build-manifest.json" -Encoding utf8NoBOM
