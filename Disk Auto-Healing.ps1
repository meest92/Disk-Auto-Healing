####################################################################################################################################
# Desripción Script: Este script realiza una autolimpieza del disco C, limpiando la                                                #
# la papelera de reciclaje, vaciando la cache de Windows Update y listando los archivos                                            #
# grandes por si no puede acabar de limpiar, si no puede bajar el umbral del disco, emite alerta al Visor de Eventos.              #
#                                                                                                                                  #
# Autor: Marc Esteve                                                                                                               #
# Organización: Accon Software SL                                                                                                  #
# Versión: v2.3                                                                                                                    #
# Fecha: 05/02/2025                                                                                                                #
####################################################################################################################################

# Configuración del umbral de alerta
$Threshold = 98
$Drive = "C:"
$EventSource = "Auto-Healing Disk Cleanup"

# Crear evento en Windows si no existe
if (!(Get-EventLog -LogName Application -Source $EventSource -ErrorAction SilentlyContinue)) {
    New-EventLog -LogName Application -Source $EventSource
}

Write-Output "Iniciando limpieza de disco..."

#Borrar archivos temporales de Windows
Write-Output "Eliminando archivos temporales..."
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

#Vaciar la Papelera de Reciclaje
Write-Output "Vaciando la papelera..."
$Shell = New-Object -ComObject Shell.Application
$Shell.Namespace(10).Items() | ForEach-Object { $_.InvokeVerb("Eliminar") }

#Limpiar caché de Windows Update
Write-Output "Limpiando Windows Update..."
Stop-Service -Name wuauserv -Force
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv

#Buscar archivos grandes en carpetas comunes
$LargeFiles = Get-ChildItem -Path "C:\Users" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 500MB } | Sort-Object Length -Descending | Select-Object FullName, Length -First 5
$LargeFilesList = ($LargeFiles | ForEach-Object { "$($_.FullName) - $($_.Length/1MB) MB" }) -join "`n"

#Verificar espacio libre después de la limpieza
$Disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$Drive'" 

if ($Disk) {
    $FreeSpace = $Disk.FreeSpace / 1GB
    $TotalSpace = $Disk.Size / 1GB
    $UsedPercentage = [math]::Round((($TotalSpace - $FreeSpace) / $TotalSpace) * 100, 2)
    Write-Output "Espacio usado después de limpieza: $UsedPercentage%"
} else {
    Write-Output "No se pudo obtener información del disco."
    Write-EventLog -LogName Application -Source $EventSource -EventId 9999 -EntryType Warning -Message "No se pudo obtener información del disco $Drive."
}

# Registrar alerta en Windows
if ($UsedPercentage -ge $Threshold) {
    Write-EventLog -LogName Application -Source $EventSource -EventId 1002 -EntryType Warning -Message "El disco sigue lleno ($UsedPercentage%). Revise manualmente los archivos grandes: $LargeFilesList"
    Write-Output "El disco sigue lleno ($UsedPercentage%). Revise manualmente los archivos grandes: $LargeFilesList"
} else {
    Write-EventLog -LogName Application -Source $EventSource -EventId 1001 -EntryType Information -Message "Espacio en disco optimizado. Uso actual: $UsedPercentage%."
    Write-Output "Limpieza de disco completada con éxito."
}