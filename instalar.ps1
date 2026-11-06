Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Compilando e instalando CONVX en tu iPhone..." -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# 1. Compilar binario con xtool en WSL
& wsl -u root -d Ubuntu-24.04 bash -c "cd /mnt/c/IOS/Convx && xtool dev build"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Fallo en la compilacion con xtool." -ForegroundColor Red
    exit $LASTEXITCODE
}

# 2. Copiar iconos de alta resolucion a la carpeta .app
Copy-Item "C:\IOS\Convx\Sources\Convx\Resources\*" "C:\IOS\Convx\xtool\Convx.app\" -Force

# 3. Inyectar configuracion de Info.plist (incluyendo reproduccion en segundo plano)
$pythonScript = @"
import plistlib, os

plist_path = r'C:\IOS\Convx\xtool\Convx.app\Info.plist'
if os.path.exists(plist_path):
    with open(plist_path, 'rb') as f:
        pl = plistlib.load(f)

    pl['CFBundleDisplayName'] = 'Convx'
    pl['CFBundleExecutable'] = 'Convx'
    pl['CFBundleName'] = 'Convx'
    pl['UIBackgroundModes'] = ['audio']
    pl['NSAppTransportSecurity'] = {
        'NSAllowsArbitraryLoads': True
    }
    pl['CFBundleIcons'] = {
        'CFBundlePrimaryIcon': {
            'CFBundleIconFiles': ['AppIcon60x60', 'AppIcon76x76', 'AppIcon'],
            'CFBundleIconName': 'AppIcon'
        }
    }
    pl['CFBundleURLTypes'] = [
        {
            'CFBundleTypeRole': 'Editor',
            'CFBundleURLName': 'com.cosmictaser.convx',
            'CFBundleURLSchemes': ['convx', 'music']
        }
    ]

    with open(plist_path, 'wb') as f:
        plistlib.dump(pl, f)
"@

python -c "$pythonScript"

# 4. Instalar en el dispositivo iPhone mediante xtool
& wsl -u root -d Ubuntu-24.04 bash -c "cd /mnt/c/IOS/Convx && xtool install xtool/Convx.app"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host " [OK] CONVX ha sido compilada e instalada con exito en tu iPhone." -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
}
