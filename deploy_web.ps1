# deploy_web.ps1 (VERSIÓN CORREGIDA)
Write-Host " Generando build web SEGURO..." -ForegroundColor Cyan

# 1. Ir a la raíz del proyecto
cd C:\Users\cesar\AndroidStudioProjects\la_polla_millonaria

# 2. Limpiar y generar build
flutter clean
flutter pub get
flutter build web --release --base-href /la-polla-millonaria-web/

Write-Host " Build completado" -ForegroundColor Green

# 3. Ir a la carpeta del build (MUY IMPORTANTE)
cd build/web

Write-Host " Agregando archivos de seguridad..." -ForegroundColor Yellow

# robots.txt
@"
User-agent: *
Disallow: /
"@ | Out-File -FilePath robots.txt -Encoding utf8

# .nojekyll
"" | Out-File -FilePath .nojekyll -Encoding ascii

# 4. SUBIR SOLO ESTA CARPETA (no la raíz)
Write-Host " Subiendo a GitHub..." -ForegroundColor Cyan

# Eliminar .git anterior si existe
Remove-Item -Recurse -Force .git -ErrorAction SilentlyContinue

# Inicializar nuevo repositorio AQUÍ
git init
git add .
git commit -m "Deploy web $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git remote add origin https://github.com/cccsoftware000/la-polla-millonaria-web.git
git branch -M main
git push -u origin main --force

Write-Host " Despliegue completado!" -ForegroundColor Green
Write-Host " URL: https://cccsoftware000.github.io/la-polla-millonaria-web/" -ForegroundColor Yellow
