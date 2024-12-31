# Obtener el directorio donde está ubicado el script
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Cambiar al directorio donde está instalado Freqtrade (suponiendo que está en el mismo directorio del script)
Set-Location -Path "$scriptDir"

# Activar el entorno virtual
& ".\.venv\Scripts\Activate.ps1"

# Iniciar Freqtrade con el modo deseado (reemplazar con el comando correspondiente)
# Por ejemplo, para ejecutar en modo dry-run:
freqtrade trade

# Mantener la ventana abierta después de Control+C
Write-Host "Presiona cualquier tecla para cerrar la ventana."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
