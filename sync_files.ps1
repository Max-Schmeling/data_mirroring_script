##############################################################################
#
# Name: Main File Sync
# Creator: Max Schmeling
# Creation Date: 3.12.2018
# Last Modified: 13.01.2020
# Tested on PS Version 5.1
#
# Inspired by Michael Seidl's script (http://www.techguy.at/tag/backupscript)
#
# Description: Iterates through a list of directories that are to be
# synchronized and synchronizes them using robocopy. Running the
# script with admin priveleges will execute ROBOCOPY with the /COPYALL
# parameter which will include file attributes in the sync. Keep in mind,
# this script will mirror the source directory/-ies with the destination
# directory. This means, files deleted in the source directory will be
# deleted in the destination as well. All source directories are mirrored
# individually. If a source directory cannot be found (because it does not
# exist) the script will display a warning but the script will continue.
# In this case, if there is an older version of the missing source directory
# in the destination directory, the directory will remain untouched. It will
# not be synced, which means data that could potentially be deleted
# will not be deleted.
# A log file will be created in the working directory.
#
##############################################################################

# Commandline arguments
Param (
    [switch]$auto = $false, # Run script without intial user interaction
    [switch]$shutdown = $false, # Shutdown immediately after the script has ended, even if error
    [int]$logginglevel = 2 # 1: Only write to logfile; 2: Write to logfile and display in console
)


# The directory all directories should be synchronized with
$destDir = "D:\my_backups"

 # The directory/-ies that are to be synced with the destination
$sourceDirs = @("C:\Documents\directory\to\be\synced", "C:\Documents\another\directory\to\be\synced")

# Sub directory/-ies of $sourceDirs that are to be excluded. Requires FULL path
#$excludeDirs = ""

# When True prevents screen from turning off or system from going into sleep mode/logging off...
#$keepalive = $true


################################# MAIN SCRIPT #################################

$host.ui.RawUI.WindowTitle = "Main Data Synchronisation"

# Prepare log
$datetime = (Get-Date -Format "yyyy-MM-dd_HH-mm")
$logname = "sync_$datetime.log" #"Sync_$datetime"
$logpath = Join-Path -Path $PSScriptRoot -ChildPath $logname


Function Logger ($status, $message) {
    $date = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

    if (!(Test-Path -Path $logpath -PathType Leaf)) {
        New-Item -Path $logpath -ItemType File | Out-Null
    }

    if ($status.Length -gt 3) {
        $text = "[$date][$status]" + " $message"
    } else {
        $text = $message
    }

    if ($logginglevel -eq 2) {
        Write-Host $text
    }

    Add-Content -Path $logpath -Value $text
    Start-Sleep -Milliseconds 20
}

Function Synchronize {
    $dircount = 0
    foreach ($sourceDir in $newSourceDirs) {
        $dircount++
        Logger "INFO" "Synchronizing directory $($dircount)/$($newSourceDirs.Length): $sourceDir"
        # Create folder with same name as folder in sourceDir because ROBOCOPY only copies the contents of a dir, not the dir itself.
        # If folder is drive (eg. E:\) then the folder name is the drive letter.
        if (((Get-Item $sourceDir).FullName) -eq (Get-Item $sourceDir).Root) {
            $driveletter = Join-Path -Path $destDir -ChildPath (Get-Item $sourceDir).PSDrive
            $drivelabel = ([System.IO.DriveInfo]::GetDrives()) | % {if ($_.Name[0] -eq (((Get-Item $sourceDir).Name)[0])) {$_.VolumeLabel}}
            $targetParentDir = $driveletter + "-" + $drivelabel
        } else {
            $targetParentDir = Join-Path -Path $destDir -ChildPath (Get-Item $sourceDir).Name
        }
        if (!(Test-Path -Path $destDir -PathType Container)) {
            Logger "INFO" "Created folder '" + (Get-Item $sourceDir).Name +"' in destination directory"
            New-Item -Path $targetParentDir -ItemType Directory | Out-Null
        }
        if ($hasAdminPriveleges) {
            robocopy $sourceDir $targetParentDir /MIR /E /MT /R:1 /W:20 /NS /NC /NP /NJS /NJH /NDL /NDL /LOG+:$logpath | Out-Null #/COPYALL rquires admin and for some reason causes error # 1314
        } else {
            robocopy $sourceDir $targetParentDir /MIR /E /MT /R:1 /W:20 /NS /NC /NP /NJS /NJH /NDL /NDL /LOG+:$logpath | Out-Null #/LOG+:$logpath 
        }
        $existstatus = $LASTEXITCODE
        If ($existstatus -gt 7) {
            Logger "INFO" "Robocopy failed with exist status: $existstatus"
        } else {
            Logger "INFO" "Robocopy successfully synchronized directory (exit status: $existstatus)"
        }
    }
}

New-Item -Path $logpath -ItemType File -Force | Out-Null # Overwrite file if it exists
Logger "" "################################################################################"
Logger "" "#"
Logger "" "# Action: Running Main Data Synchronisation (mirroring)"
Logger "" "# Start Time: $($(Get-Date -Format "yyyy-MM-dd HH:mm:ss"))"
$start_time = Get-Date
Logger "" "#"
Logger "" "################################################################################"
Logger "" "#"
Logger "" "# Destination Directory:"
Logger "" "#  $destDir"
Logger "" "# Source Directories:"
foreach ($dir in $sourceDirs) {
    Logger "" "#  $dir"
}
Logger "" "#"
Logger "" "################################################################################"
Logger "INFO" "Event log: '$logpath'"


# Testing availability of destination Dir (e.g. if its a NAS or external drive)
Logger "INFO" "Testing availability of destination directory"
if ([string]::IsNullOrEmpty($destdir) -or [string]::IsNullOrWhiteSpace($destdir)) {
    Logger "ERROR" "No destination directory specified"
    Logger "INFO" "Exiting because destination directory not specified"
    exit
} elseif (-not (Test-Path $destDir)) {
    Logger "ERROR" "Destination directory not available"
    Logger "INFO" "Exiting because destination directory not available"
    exit
}
Logger "INFO" "Destination directory exists" $true


# Check if all directories exist. If not update list and continue
# with existing ones. If no source directory exists exit in error
$newSourceDirs = @()
Logger "INFO" "Testing availability of source directory/-ies"
foreach ($sourceDir in $sourceDirs) {
    if (-not ([string]::IsNullOrEmpty($sourceDir) -or [string]::IsNullOrWhiteSpace($sourceDir))) {
        if (!(Test-Path -Path $sourceDir -PathType Container)) {
            Logger "WARNING" "'$sourceDir' cannot be located. The directory cannot be synced"
        } else {
            $newSourceDirs += ,$sourceDir
            Logger "INFO" "'$sourceDir' exists"
        }
    } else {
            Logger "ERROR" "Source directory empty. The directory cannot be synced"
    }
}


# Cancel process if all source dir paths are invalid
if ($newSourceDirs.Length -eq 0) {
    Logger "ERROR" "No source directory exists."
    Logger "INFO" "Exiting because no source directory for synchronization found."
    exit
}


if (-not $auto) {
    $confirmcode = Get-Random -Minimum 100 -Maximum 999
    Write-Host ""
    Write-Host "Confirmation Code: $($confirmcode)"
    $userinput = Read-Host "Enter the code to start the process"
    if ($userinput.Trim() -ne $confirmcode.ToString()) {
        Write-Host "Wrong confirmation code. Syncronization has not started and will be canceled."
        Start-Sleep -Seconds 2.5
        exit
    }
}


# Create destination directory if it does not already exist
if (!(Test-Path -Path $destDir -PathType Container)) {
    Logger "INFO" "Created destination directory."
    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
}


# Check if script is running with admin priveleges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$hasAdminPriveleges = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($hasAdminPriveleges) {
    Logger "INFO" "The script is running with administrator privileges." # /COPYALL parameter (robocopy) enabled."
} else {
    Logger "WARNING" "The script is not running with administrator privileges." # /COPYALL parameter (robocopy) disabled."
}

# Start actual sync function
Synchronize


$end_time = Get-Date
$duration = New-TimeSpan $start_time $end_time
$duration_hours = $duration.Hours
$duration_minutes = $duration.Minutes
$duration_seconds = $duration.Seconds
$duration_mseconds = $duration.Milliseconds
$duration_frmt = "{0:00}:{1:00}:{2:00}:{3:00}" -f $duration_hours, $duration_minutes, $duration_seconds, $duration_mseconds

Logger "INFO" "Synchronization finished."
Logger "" "################################################################################"
Logger "" "#"
Logger "" "# End Time: $($(Get-Date -Format "yyyy-MM-dd HH:mm:ss"))"
Logger "" "# Time taken: $($duration_frmt)"
Logger "" "#"
Logger "" "################################################################################"

# Remove old logs
$alllogs = Get-ChildItem -Path ((Get-Item -Path $logpath).DirectoryName) -Filter *.log | Sort-Object CreationTime |
    ForEach-Object {
        if ($_.Name.ToString() -ne $logname) {
            try {
                Remove-Item -Path $_.FullName
                Logger "INFO" "Removed old log: $($_.Name)"
            } catch {
                Logger "ERROR" "An error ocurred when attempting to delete old log: $($_.Name)"
            }
        }
    }


if ($shutdown) {
    Logger "INFO" "Initiating computer shutdown in 10 seconds..."
    Start-Sleep -s 10
    Logger "INFO" "Script End. Computer Shutdown."
    Stop-Computer -Force
} else {
    Logger "INFO" "Script End."
    if (-not $auto) {
        Write-Host "Press any key to close the script..."
        [void][System.Console]::ReadKey($true)
    }
}
