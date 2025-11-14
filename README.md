# Copilot CLI Unlocker - Enhanced Fork

A tool to add custom models to GitHub Copilot CLI's allowed models list.

> **Note:** This is a fork of the original [copilot-cli-free-models](https://github.com/agileandy/copilot-cli-free-models). Special thanks to the original creator [@agileandy](https://github.com/agileandy) for his work. This version has been enhanced to provide native support for both Bash (Linux/macOS/WSL) and Windows PowerShell, and it patches both required model arrays for full compatibility with /model command.

This fork introduces two dedicated scripts:
- `patch-models.sh`: For Bash-based systems (Linux, macOS, WSL).
- `patch-models.ps1`: For native Windows environments using PowerShell.

## What's New in This Fork?

- **Dual Script Support**: Native scripts for both PowerShell on Windows and Bash on other systems.
- **Dual Array Patching**: The script now patches both the simple model name array and the model object array (which includes labels), ensuring models appear correctly in any UI that uses them.
- **Expanded Default Models**: Now includes `gpt-4.1`, `gpt-4o`, `gpt-5-mini`, `grok-code-fast-1`, `gemini-2.5-pro` by default.

> [!WARNING]
> **A Note on Copilot CLI Versions `0.0.356` & `0.0.357`**
>
> Version `0.0.356` of the Copilot CLI briefly introduced experimental models (`gpt-5-codex`, `gpt-5.1`, `gpt-5.1-codex-mini`, `gpt-5.1-codex`). However, in the very next version (`0.0.357`), GitHub **removed the API connection code** for these models, making them non-functional.
>
> Our goal is to patch in only *working* models. Therefore, this script will not add these specific models on `v0.0.357` or newer.
>
> **If you wish to use these experimental models, you must use Copilot CLI version `0.0.356`. otherwise they will not work!** you can switch to that version by:
>```bash
>npm install -g @github/copilot@0.0.356
>```
<img width="786" height="508" alt="image" src="https://github.com/user-attachments/assets/6d2ec243-a34f-442f-b0c4-1d97748dd553" />


- **In-App Model Switching**: After patching, you can switch between the added models using commands like `/model` directly within the Copilot CLI interface.

## Requirements

### Suported Versions
- GitHub Copilot CLI version `0.0.354`.
- GitHub Copilot CLI version `0.0.355`.
- GitHub Copilot CLI version `0.0.356`. (They added new models: gpt-5.1,gpt-5.1-codex-mini,gpt-5.1-codex)
- GitHub Copilot CLI version `0.0.357`. (They remove code for added models: gpt-5.1,gpt-5.1-codex-mini,gpt-5.1-codex? wierd...)

### For Bash Script (`patch-models.sh`)
- **Bash shell** (macOS, Linux, WSL)
- **Perl** (pre-installed on macOS/Linux)
- **GitHub Copilot CLI** installed

### For PowerShell Script (`patch-models.ps1`)
- **Windows PowerShell 7.0+** (pre-installed on Windows 10/11)
- **GitHub Copilot CLI** installed

## Quick Start

### Bash (Linux, macOS, WSL)

1.  **Make the script executable:**
    ```bash
    chmod +x patch-models.sh
    ```
2.  **Run a dry run to preview changes:**
    ```bash
    ./patch-models.sh --dry-run
    ```
3.  **Apply the patch:**
    ```bash
    ./patch-models.sh
    ```

#### Bash Version in Action
![unlock-bash](https://github.com/user-attachments/assets/da8dd556-299a-4c3d-9911-868b7dd6367c)


### PowerShell (Windows)

1.  **Set Execution Policy (if needed):**
    Open PowerShell **as an Administrator** and run this command once to allow local scripts to run:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
2.  **Run a dry run to preview changes:**
    Open a regular PowerShell window, navigate to the directory, and run:
    ```powershell
    .\patch-models.ps1 -DryRun
    ```
3.  **Apply the patch:**
    ```powershell
    .\patch-models.ps1
    ```

#### PowerShell Version in Action
![unlock](https://github.com/user-attachments/assets/eac05fc3-c71b-4934-9c6d-7d3706357488)



### After Patching (Both Systems)

Thanks to the dual-array patch, you can now switch between the newly added models directly from the Copilot CLI using the `/model` command.

Editing your configuration file is **optional**. You only need to edit `~/.copilot/config.json` if you want to set a **default model** that the CLI will use at startup.

**To set a default model (Optional):**
Edit the file at `~/.copilot/config.json` and set the `model` property:

```json
{
  "model": "gpt-5-mini"
}
```

If you don't set a default, you can still access the new models anytime by typing `/model` in the Copilot CLI prompt.

## Version Compatibility & Branching
Since the Copilot CLI's internal structure can change with updates, this repository will use branches to track unlocker versions that are compatible with specific releases of `@github/copilot`.

If the script on the `main` branch fails after a CLI update, please check the repository's branches for a version named after your CLI version (e.g., `copilot-v1.20.0`).


## Usage

### Bash (`patch-models.sh`)

**Default Usage (Recommended)**
This will patch the CLI with the default set of models: `gpt-4.1`, `gpt-4o`, `gpt-5-mini`, and `grok-code-fast-1`.
```bash
./patch-models.sh
```

**Add Specific Models**
Use the `--models` flag to add a custom list of models instead of the default ones.
```bash
./patch-models.sh --models o1
```

**Patch a Custom Location**
```bash
./patch-models.sh --file /path/to/custom/index.js
```

### PowerShell (`patch-models.ps1`)

**Default Usage (Recommended)**
This will patch the CLI with the default set of models: `gpt-4.1`, `gpt-4o`, `gpt-5-mini`, and `grok-code-fast-1`.
```powershell
.\patch-models.ps1
```

**Add Specific Models**
Use the `-Models` parameter to add a custom list of models instead of the default ones.
```powershell
.\patch-models.ps1 -Models "o1"
```

**Patch a Custom Location**
```powershell
.\patch-models.ps1 -File "C:\path\to\custom\index.js"
```

## How It Works

The Copilot CLI's `index.js` is a large minified file containing hardcoded arrays of allowed models. This fork's patcher locates and modifies **two** of these arrays:

1.  **A simple name array:**
    ```javascript
    // Variable name changes between versions (e.g., Yv, Ef)
    Yv=["claude-sonnet-4.5","claude-sonnet-4",...]
    ```
2.  **An object array with labels:**
    ```javascript
    // Variable name also changes (e.g., Dwe)
    Dwe=[{model:"claude-sonnet-4.5",label:"Claude Sonnet 4.5"},...]
    ```

The unlocker auto-detects the variable names and safely appends your desired models to both lists, ensuring full functionality. A timestamped backup is always created before any changes are made.

## Adapting for Future Updates

If a future Copilot CLI update breaks the unlocker, you'll need to find the new patterns for both arrays or wait for update of Copilot-CLI-Unlocker.

1.  **Locate the arrays** by searching the `index.js` file for known model names like `"claude-sonnet"` or `"gpt-5"`.
2.  **Find the variable names** they are assigned to (the characters before the `=`).
3.  **Update the search patterns** in the script. Both `.sh` and `.ps1` scripts have clearly marked regex patterns that can be adjusted. Always test your changes with `--dry-run` or `-DryRun`.

## Files in This Directory

```
Copilot-CLI-Unlocker/
├── patch-models.sh          # Unlocker for Linux, macOS, and WSL
├── patch-models.ps1         # Unlocker for Windows PowerShell
└── README.md                # This file
```

## Troubleshooting

### Error: "Could not find models array"
The file structure has likely changed in a new Copilot CLI update. Check the branches of this repository for a version compatible with your CLI version. If one doesn't exist, you may need to follow the "Adapting for Future Updates" section.

### Error: "Replacement failed"
This can happen if the file is write-protected or if the script's patterns no longer match. The script should automatically restore from backup.

### Model Still Not Working
1.  Verify the patch was applied by searching for one of your added models inside the `index.js` file.
2.  Double-check your `~/.copilot/config.json` for correct spelling and syntax. The model name is case-sensitive and must be an exact match.
3.  Check any updates of Copilot CLI or Copilot-CLI-Unlocker
4.  Check your configuration at https://github.com/settings/copilot/features
5.  Create Issue in this repo

## License

This is a utility script for personal use. The GitHub Copilot CLI itself is proprietary software from GitHub.

## Support

For issues with:
- **This patcher:** Check the troubleshooting section above
- **Copilot CLI itself:** Contact GitHub Support
- **Model availability:** Check with your GitHub organization's settings
