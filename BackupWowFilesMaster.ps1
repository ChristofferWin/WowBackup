#Master script acts as the manager of the entire "system" Script will be ran via a batch (.exe) file.

#Variables
[datetime]$Date = (Get-Date)
[string]$DateString = $Date.ToShortDateString()
[string]$WowPathRoot = ""
[string]$WowBackupPath = ""

function Get-InitialSetup(){
    param(
    )

}

function Get-WowPath(){
    param()
    $LocalDrives = (Get-PSDrive).Name # -> Needs to be moved into the master script that is not yet built
    foreach($LocalDrive in $LocalDrives){
        if($LocalDrive.Length -eq 1){
            Write-OutPut "Checking the $($LocalDrive):\ drive"
            $WowPathRoot = (Get-ChildItem -Path "$($LocalDrive):\" -Filter "_classic_" -Recurse -ErrorAction SilentlyContinue).FullName
            if($WowPathRoot.Length -gt 0){
                Write-OutPut "The Wow folder has been found on the $($LocalDrive):\ drive"
                Break
            }
        }
    }
    if($WowPathRoot.Length -eq 0){# -> Needs to be moved into the master script that is not yet built
        Write-Error "World Of Warcraft Classic was not found on the system. No further action taken..."
        Exit
    }
    return $WowPathRoot
}

function Set-WowBackupPath(){
    param(
        [string]$WowBackupPath
    )

    if($WowBackupPath.Length -eq 0){
        $WowBackupPath = "$([Environment]::GetFolderPath("Desktop"))\WowBackupFolder"
        Write-Warning "Default path used: $WowBackupPath"
        if((Read-Host "Do you accept this path? y/n").ToLower() -ne "n"){
            Break
        }
        else{
            Get-InitialSetup
        }
    }
}

#Execution
Write-Information "Checking for first time use, please wait..."
