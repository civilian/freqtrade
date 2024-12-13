# Filename: Install-Freqtrade.ps1
# This script automates the installation of Freqtrade on Windows, including Python installation

# Verifica si tiene permisos de administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ejecutando con permisos de administrador..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Starting Freqtrade installation..."

# Step 1: Check if Python is installed
Write-Host "Checking Python installation..."
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Python is not installed. Installing Python..."

    # Define Python version and download URL
    $pythonVersion = "3.10.11"
    $pythonInstallerUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
    $installerPath = "$env:TEMP\python-installer.exe"

    # Download the Python installer
    Invoke-WebRequest -Uri $pythonInstallerUrl -OutFile $installerPath

    # Install Python silently
    Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

    # Verify installation
    if (!(Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "Python installation failed. Please install it manually and rerun the script." -ForegroundColor Red
        exit
    }

    Write-Host "Python installed successfully."
} else {
    Write-Host "Python is already installed."
}

# Step 2: Install pip (if not already installed)
Write-Host "Ensuring pip is installed..."
python -m ensurepip --upgrade

# Step 3: Install virtualenv
Write-Host "Installing virtualenv..."
pip install --upgrade pip
pip install virtualenv

# Step 4: Get the directory of the current script
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

Set-Location -Path "$scriptDir"

Clear-Host

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFilePath = Join-Path $env:TEMP "script_log_$Timestamp.txt"

$RequirementFiles = @("requirements-dev.txt")
$VenvName = ".venv"
$VenvDir = Join-Path $PSScriptRoot $VenvName

function Write-Log {
  param (
    [string]$Message,
    [string]$Level = 'INFO'
  )

  if (-not (Test-Path -Path $LogFilePath)) {
    New-Item -ItemType File -Path $LogFilePath -Force | Out-Null
  }

  switch ($Level) {
    'INFO' { Write-Host $Message -ForegroundColor Green }
    'WARNING' { Write-Host $Message -ForegroundColor Yellow }
    'ERROR' { Write-Host $Message -ForegroundColor Red }
    'PROMPT' { Write-Host $Message -ForegroundColor Cyan }
  }

  "${Level}: $Message" | Out-File $LogFilePath -Append
}

function Get-UserSelection {
  param (
    [string]$Prompt,
    [string[]]$Options,
    [string]$DefaultChoice = 'A',
    [bool]$AllowMultipleSelections = $true
  )

  Write-Log "$Prompt`n" -Level 'PROMPT'
  for ($I = 0; $I -lt $Options.Length; $I++) {
    Write-Log "$([char](65 + $I)). $($Options[$I])" -Level 'PROMPT'
  }

  if ($AllowMultipleSelections) {
    Write-Log "`nSelect one or more options by typing the corresponding letters, separated by commas." -Level 'PROMPT'
  }
  else {
    Write-Log "`nSelect an option by typing the corresponding letter." -Level 'PROMPT'
  }

  [string]$UserInput = Read-Host
  if ([string]::IsNullOrEmpty($UserInput)) {
    $UserInput = $DefaultChoice
  }
  $UserInput = $UserInput.ToUpper()

  if ($AllowMultipleSelections) {
    $Selections = $UserInput.Split(',') | ForEach-Object { $_.Trim() }
    $SelectedIndices = @()
    foreach ($Selection in $Selections) {
      if ($Selection -match '^[A-Z]$') {
        $Index = [int][char]$Selection - [int][char]'A'
        if ($Index -ge 0 -and $Index -lt $Options.Length) {
          $SelectedIndices += $Index
        }
        else {
          Write-Log "Invalid input: $Selection. Please enter letters within the valid range of options." -Level 'ERROR'
          return -1
        }
      }
      else {
        Write-Log "Invalid input: $Selection. Please enter a letter between A and Z." -Level 'ERROR'
        return -1
      }
    }
    return $SelectedIndices
  }
  else {
    if ($UserInput -match '^[A-Z]$') {
      $SelectedIndex = [int][char]$UserInput - [int][char]'A'
      if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $Options.Length) {
        return $SelectedIndex
      }
      else {
        Write-Log "Invalid input: $UserInput. Please enter a letter within the valid range of options." -Level 'ERROR'
        return -1
      }
    }
    else {
      Write-Log "Invalid input: $UserInput. Please enter a letter between A and Z." -Level 'ERROR'
      return -1
    }
  }
}

function Exit-Script {
  param (
    [int]$ExitCode,
    [bool]$WaitForKeypress = $true
  )

  if ($ExitCode -ne 0) {
    Write-Log "Script failed. Would you like to open the log file? (Y/N)" -Level 'PROMPT'
    $openLog = Read-Host
    if ($openLog -eq 'Y' -or $openLog -eq 'y') {
      Start-Process notepad.exe -ArgumentList $LogFilePath
    }
  }
  elseif ($WaitForKeypress) {
    Write-Log "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
  }

  return $ExitCode
}

function Test-PythonExecutable {
  param(
    [string]$PythonExecutable
  )

  $DeactivateVenv = Join-Path $VenvDir "Scripts\Deactivate.bat"
  if (Test-Path $DeactivateVenv) {
    Write-Host "Deactivating virtual environment..." 2>&1 | Out-File $LogFilePath -Append
    & $DeactivateVenv
    Write-Host "Virtual environment deactivated." 2>&1 | Out-File $LogFilePath -Append
  }
  else {
    Write-Host "Deactivation script not found: $DeactivateVenv" 2>&1 | Out-File $LogFilePath -Append
  }

  $PythonCmd = Get-Command $PythonExecutable -ErrorAction SilentlyContinue
  if ($PythonCmd) {
    $VersionOutput = & $PythonCmd.Source --version 2>&1
    if ($LASTEXITCODE -eq 0) {
      $Version = $VersionOutput | Select-String -Pattern "Python (\d+\.\d+\.\d+)" | ForEach-Object { $_.Matches.Groups[1].Value }
      Write-Log "Python version $Version found using executable '$PythonExecutable'."
      return $true
    }
    else {
      Write-Log "Python executable '$PythonExecutable' not working correctly." -Level 'ERROR'
      return $false
    }
  }
  else {
    Write-Log "Python executable '$PythonExecutable' not found." -Level 'ERROR'
    return $false
  }
}

function Find-PythonExecutable {
  $PythonExecutables = @(
    "python",
    "python3.12",
    "python3.11",
    "python3.10",
    "python3",
    "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\python.exe",
    "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python311\python.exe",
    "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python310\python.exe",
    "C:\Python312\python.exe",
    "C:\Python311\python.exe",
    "C:\Python310\python.exe"
  )


  foreach ($Executable in $PythonExecutables) {
    if (Test-PythonExecutable -PythonExecutable $Executable) {
      return $Executable
    }
  }

  return $null
}
function Main {
  "Starting the operations..." | Out-File $LogFilePath -Append
  "Current directory: $(Get-Location)" | Out-File $LogFilePath -Append

  # Exit on lower versions than Python 3.10 or when Python executable not found
  $PythonExecutable = Find-PythonExecutable
  if ($null -eq $PythonExecutable) {
    Write-Log "No suitable Python executable found. Please ensure that Python 3.10 or higher is installed and available in the system PATH." -Level 'ERROR'
    Exit 1
  }

  # Define the path to the Python executable in the virtual environment
  $ActivateVenv = "$VenvDir\Scripts\Activate.ps1"

  # Check if the virtual environment exists, if not, create it
  if (-Not (Test-Path $ActivateVenv)) {
    Write-Log "Virtual environment not found. Creating virtual environment..." -Level 'ERROR'
    & $PythonExecutable -m venv $VenvName 2>&1 | Out-File $LogFilePath -Append
    if ($LASTEXITCODE -ne 0) {
      Write-Log "Failed to create virtual environment." -Level 'ERROR'
      Exit-Script -exitCode 1
    }
    else {
      Write-Log "Virtual environment created."
    }
  }

  # Activate the virtual environment and check if it was successful
  Write-Log "Virtual environment found. Activating virtual environment..."
  & $ActivateVenv 2>&1 | Out-File $LogFilePath -Append
  # Check if virtual environment is activated
  if ($env:VIRTUAL_ENV) {
    Write-Log "Virtual environment is activated at: $($env:VIRTUAL_ENV)"
  }
  else {
    Write-Log "Failed to activate virtual environment." -Level 'ERROR'
    Exit-Script -exitCode 1
  }

  # Ensure pip
  python -m ensurepip --default-pip 2>&1 | Out-File $LogFilePath -Append

  if (-not (Test-Path "$VenvDir\Lib\site-packages\talib")) {
    # Install TA-Lib using the virtual environment's pip
    Write-Log "Installing TA-Lib using virtual environment's pip..."
    python -m pip install --find-links=build_helpers\ --prefer-binary TA-Lib 2>&1 | Out-File $LogFilePath -Append
    if ($LASTEXITCODE -ne 0) {
      Write-Log "Failed to install TA-Lib." -Level 'ERROR'
      Exit-Script -exitCode 1
    }
  }

  # Cache the selected requirement files
  $SelectedRequirementFiles = 'A'
  $PipInstallArguments = @()
  foreach ($Index in $SelectedIndices) {
    $RelativePath = $RequirementFiles[$Index]
    if (Test-Path $RelativePath) {
      $SelectedRequirementFiles += $RelativePath
      $PipInstallArguments += "-r", $RelativePath  # Add each flag and path as separate elements
    }
    else {
      Write-Log "Requirement file not found: $RelativePath" -Level 'ERROR'
      Exit-Script -exitCode 1
    }
  }
  if ($PipInstallArguments.Count -ne 0) {
    & pip install @PipInstallArguments # Use array splatting to pass arguments correctly
  }

  # Install freqtrade from setup using the virtual environment's Python
  Write-Log "Installing freqtrade from setup..."
  pip install -e . 2>&1 | Out-File $LogFilePath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to install freqtrade." -Level 'ERROR'
    Exit-Script -exitCode 1
  }

  Write-Log "Installing freqUI..."
  python freqtrade install-ui 2>&1 | Out-File $LogFilePath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to install freqUI." -Level 'ERROR'
    Exit-Script -exitCode 1
  }

  Write-Log "Installation/Update complete!"
  Exit-Script -exitCode 0
}

# Call the Main function
Main
