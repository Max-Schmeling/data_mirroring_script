# Directory Mirroring Script :floppy_disk:

This script synchronizes one or more source directory/-ies (variable  `$sourceDirs`) with one destination directory (variable `$destDir`) recursively. The script will not create a new version folder for each mirroring process. Instead the source directories will be synced with the same destination every time. The directory structure of the source directory/-ies will be mirrored 1:1 in the destination directory. Before the sync process starts the availability of the target and the source directory/-ies is tested. Any changes made to the source directory will be applied to the destination directory. Internally, powershell prepares the mirroring process and Windows' `robocopy` does the actual work. All activities are logged in a seperate log file (variable `$logpath`). View the ps1-file for more information.

## Syntax
`powershell.exe -noexit -Mta "sync_files.ps1" [auto] [shutdown] [logginglevel]`  

**-auto**: The script runs without user interaction. If not provided the user will be prompted to confirm.  
**-shutdown**: System shutdown immediately after the script has terminated. Even if an error was thrown.  
**-logginglevel**: **(1)** Only write to logfile **(2)** Write to logfile and display in console (default)

## How do I make this work?
1. Set the variables `$sourceDirs` and `$destDir` to your desired directories.
2. Launch the script using the command and the optional paramters above

I recommend hooking up the command to the windows task scheduler together with the `-auto` parameter or to call the script manually via a shortcut along with the `-shutdown` parameter.
