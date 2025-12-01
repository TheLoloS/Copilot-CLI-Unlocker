<#
.SYNOPSIS
    Copilot CLI Unlocker (PowerShell Version)
    Adds additional models to the GitHub Copilot CLI's allowed models arrays.

.DESCRIPTION
    This script finds the index.js file of an installed GitHub Copilot CLI,
    and patches it to include additional model names. It modifies both the
    simple name array and the more complex model object array.

.PARAMETER File
    Optional. The full path to the 'index.js' file to be patched. If not provided,
    the script will attempt to auto-detect it.

.PARAMETER DryRun
    If specified, the script will show the changes that would be made without
    actually modifying any files.

.PARAMETER Models
    A comma-separated string of model names to add (e.g., "gpt-5-mini,o1").
    Defaults to "gpt-5-mini,grok-code-fast-1".
#>
param(
    [string]$File,
    [switch]$DryRun,
    [string]$Models = "gpt-4o,grok-code-fast-1,raptor-mini,gemini-2.5-pro"
)

# --- Main logic ---
function Patch-CopilotModels {
    # --- Configuration ---
    $ModelsToAdd = $Models.Split(',') | ForEach-Object { $_.Trim() }

    # --- Colors ---
    Write-Host "----------------------------------------------------" -ForegroundColor Blue
    Write-Host "  Copilot CLI Unlocker (PowerShell Version)" -ForegroundColor Blue
    Write-Host "----------------------------------------------------" -ForegroundColor Blue
    Write-Host ""

    # --- Searching for target file ---
    $TargetFile = $File
    if (-not $TargetFile) {
        # ==============================================================================
        # IMPROVED AND MORE RELIABLE PATH SEARCH SECTION
        # ==============================================================================
        $SearchPaths = [System.Collections.Generic.List[string]]::new()
        $SearchPaths.Add((Join-Path $env:USERPROFILE "node_modules\@github\copilot\index.js"))
        
        # Safely obtain the global npm path
        try {
            $npmGlobalRoot = npm root -g 2>$null # Hide errors if npm exists but folder is missing
            if ($npmGlobalRoot) {
                $SearchPaths.Add((Join-Path $npmGlobalRoot "@github\copilot\index.js"))
            }
        } catch {
            # Ignore error if 'npm' command does not exist
        }

        $SearchPaths.Add((Join-Path $env:APPDATA "npm\node_modules\@github\copilot\index.js"))
        $SearchPaths.Add((Join-Path $env:ProgramFiles "nodejs\node_modules\@github\copilot\index.js"))

        foreach ($path in $SearchPaths) {
            if (Test-Path $path -PathType Leaf) {
                $TargetFile = $path
                break
            }
        }
    }

    if (-not (Test-Path $TargetFile -PathType Leaf)) {
        Write-Host "❌ Error: File not found: '$TargetFile'" -ForegroundColor Red
        Write-Host "Could not auto-detect Copilot installation. Use the -File parameter to specify the path." -ForegroundColor Red
        return
    }
    Write-Host "✓ Target file: $TargetFile" -ForegroundColor Green
    
    # --- Helper function to generate labels ---
    function Generate-Label([string]$modelName) {
        $textInfo = (Get-Culture).TextInfo
        $titleCase = $textInfo.ToTitleCase($modelName.Replace('-', ' '))
        return $titleCase.Replace('Gpt', 'GPT')
    }

    # --- Read file ---
    $content = Get-Content -Path $TargetFile -Raw

    # --- Step 1: Process first array (simple names) ---
    Write-Host ""
    Write-Host 'Step 1: Processing names array (e.g., Yv=[...])...' -ForegroundColor Yellow

    $namesArrayPattern = '[A-Za-z_\$][A-Za-z0-9_\$]*=\["claude-sonnet-[^\]]*\]'
    $match1 = $content | Select-String -Pattern $namesArrayPattern
    
    if (-not $match1) {
        Write-Host "❌ Error: Could not find the simple names array." -ForegroundColor Red
        return
    }
    
    $searchPattern1 = $match1.Matches[0].Value
    $namesVarName = $searchPattern1.Split('=')[0]
    $currentNamesArrayStr = $searchPattern1.Substring($searchPattern1.IndexOf('=') + 1)
    $currentModels = $currentNamesArrayStr -replace '[\["\]]' -split ',' | ForEach-Object { $_.Trim() }

    Write-Host "✓ Found variable: $($namesVarName)" -ForegroundColor Green
    
    $newNamesModels = [System.Collections.Generic.List[string]]::new()
    $currentModels | ForEach-Object { $newNamesModels.Add($_) }
    
    $modelsAdded = [System.Collections.Generic.List[string]]::new()
    foreach ($model in $ModelsToAdd) {
        if ($model -notin $currentModels) {
            $newNamesModels.Add($model)
            $modelsAdded.Add($model)
            Write-Host "+ Adding model: $model" -ForegroundColor Green
        } else {
            Write-Host "⚠ Model '$model' already exists in names array, skipping." -ForegroundColor Yellow
        }
    }

    if ($modelsAdded.Count -eq 0) {
        Write-Host "✔ No new models to add. File seems up to date." -ForegroundColor Yellow
        return;
    }

    $newNamesArrayContent = ($newNamesModels | ForEach-Object { '"' + $_ + '"' }) -join ','
    $replacement1 = "$($namesVarName)=[$($newNamesArrayContent)]"

    # --- Step 2: Process second array (objects) ---
    Write-Host ""
    Write-Host 'Step 2: Processing objects array (e.g., Dwe=[{...}])...' -ForegroundColor Yellow

    $objectsArrayPattern = '[A-Za-z_\$][A-Za-z0-9_\$]*=\[{model:"claude-sonnet-[^\]]*\]'
    $match2 = $content | Select-String -Pattern $objectsArrayPattern

    if (-not $match2) {
        Write-Host "❌ Error: Could not find the model objects array." -ForegroundColor Red
        return
    }

    $searchPattern2 = $match2.Matches[0].Value
    $objectsVarName = $searchPattern2.Split('=')[0]
    Write-Host "✓ Found variable: $($objectsVarName)" -ForegroundColor Green
    
    $currentObjectsArrayStr = $searchPattern2.Substring($searchPattern2.IndexOf('=') + 1)
    $newObjectsArrayStr = $currentObjectsArrayStr.Substring(0, $currentObjectsArrayStr.Length - 1) # Remove last ']'

    foreach ($model in $modelsAdded) {
        $label = Generate-Label $model
        $newObject = ",{model:`"$model`",label:`"$label`"}"
        $newObjectsArrayStr += $newObject
        Write-Host "+ Adding object: $newObject" -ForegroundColor Green
    }
    $newObjectsArrayStr += "]" # Add ']' back
    $replacement2 = "$($objectsVarName)=$($newObjectsArrayStr)"

    # --- Step 3: Preview or apply changes ---
    Write-Host ""
    if ($DryRun) {
    Write-Host "----------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Would perform 2 replacements:"
        Write-Host "  1. FROM: " -NoNewline; Write-Host $searchPattern1 -ForegroundColor Red
        Write-Host "     TO:   " -NoNewline; Write-Host $replacement1 -ForegroundColor Green
        Write-Host ""
        Write-Host "  2. FROM: " -NoNewline; Write-Host $searchPattern2 -ForegroundColor Red
        Write-Host "     TO:   " -NoNewline; Write-Host $replacement2 -ForegroundColor Green
        return
    }

    Write-Host "Step 3: Applying patch..." -ForegroundColor Yellow
    
    $backupFile = "$($TargetFile).bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
    Write-Host "Creating backup: $backupFile" -ForegroundColor Blue
        Copy-Item -Path $TargetFile -Destination $backupFile
        
        $newContent = $content.Replace($searchPattern1, $replacement1).Replace($searchPattern2, $replacement2)
        
        Set-Content -Path $TargetFile -Value $newContent -NoNewline -Encoding UTF8
        
        $finalContent = Get-Content -Path $TargetFile -Raw
        # Use literal contains checks instead of -like which treats [] and other
        # characters as wildcard patterns (caused verification to fail).
        if (-not ($finalContent.Contains($replacement1) -and $finalContent.Contains($replacement2))) {
            throw "Verification failed after patching!"
        }

        Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Green
    Write-Host " ✅ Successfully patched both arrays!" -ForegroundColor Green
    Write-Host "----------------------------------------------------" -ForegroundColor Green
        Write-Host ""
    Write-Host "Backup saved to: $backupFile" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Models now available:"
        foreach($model in $modelsAdded) {
            $label = Generate-Label $model
            Write-Host "  - $model (Label: '$label')" -ForegroundColor Green
        }
        Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  🎉  You can select models by /model command or:" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------" -ForegroundColor Yellow
        $configPath = Join-Path $env:USERPROFILE ".copilot\config.json"
    Write-Host "Edit your Copilot config ($configPath) and set:"
    Write-Host ('  "model": "{0}"' -f $modelsAdded[0]) -ForegroundColor Green

    } catch {
        Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Red
    Write-Host " ❌ Error: Patching failed! An error occurred." -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "----------------------------------------------------" -ForegroundColor Red
        Write-Host "Restoring from backup..."
        if (Test-Path $backupFile) {
            Move-Item -Path $backupFile -Destination $TargetFile -Force
            Write-Host "✓ Restore complete." -ForegroundColor Green
        } else {
            Write-Host "⚠ Backup file not found. Could not restore." -ForegroundColor Yellow
        }
    }
}

# Run main function
Patch-CopilotModels