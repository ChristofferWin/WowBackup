#Backup the necassary files needed to recover user settings for a Wow installation. Folders to have a backup taken can be changed via the variable $WowFolders
function New-WowBackup(){
    param(
       [string]$WowBackupPath,#Change this path to your desired backup Path (Can even be a network path (NAS FX) It is recommended to use somewhere ELSE than C:\)
       [boolean]$Logging = $true, #You can turn of logging if needed
       [array]$WowFolders = @("Interface","Screenshots","WTF")
    )
    [datetime]$Date = (Get-Date)
    [string]$DateString = $Date.ToShortDateString()
    [Array]$WowFilesSize = @()
    [Array]$WowFilesBackupSize = @()
    [Double]$WowFilesSizeSum = 0
    [Double]$WowFilesBackupSizeSum = 0
    [Array]$LocalDrives = @()
    [string]$WowPathRoot = ""
    
    if($Logging){
        try{
            Start-Transcript -Path "$([Environment]::GetFolderPath("Desktop"))\Scripts for WoW\Logs\$DateString.log" -Force -ErrorAction Stop
        }
        catch{
            Write-Error "Transcript could not be started. Most likely due to the file already existing or is in use by another process..."
        }
    }
    if($WowBackupPath.Length -eq 0){ # -> Needs to be moved into the master script that is not yet built
        $WowBackupPath = "$([Environment]::GetFolderPath("Desktop"))\WowBackupFolder"
        Write-Warning "Default path used: $WowBackupPath"
        if((Read-Host "Do you accept this path? y/n").ToLower() -ne "n"){
            Break
        }
        else{
            CallSomeFunction #This needs to be a function so it can call itself again
        }
    }
    
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
    $WowPathRoot = ((Get-ChildItem -Path C:\ -Filter "_classic_" -Recurse -ErrorAction SilentlyContinue).FullName | % {if($null -ne $_){$_}else{Write-Error "Wow was not found on the C:\ drive";Exit}})# -> Needs to be moved into the master script that is not yet built
    if(!(Test-Path $WowBackupPath)){
        New-Item -ItemType Directory -Path $WowBackupPath | Out-Null
    }
    #Getting size of each of the specific folder names, seen in variable $WowFolders. Used to determine whether changes can be found or not.
    foreach($WowFolder in $WowFolders){
        $WowFilesSize += ((Get-ChildItem -Path $WowPathRoot -Filter $WowFolder -Recurse | Get-ChildItem -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB)
        $WowFilesBackupSize += ((Get-ChildItem -Path $WowBackupPath -Filter $WowFolder -Recurse | Get-ChildItem -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB)
    }
    $WowFilesSizeSum = ($WowFilesSize | Measure-Object -Sum).Sum
    $WowFilesBackupSizeSum = ($WowFilesBackupSize | Measure-Object -Sum).Sum
    #If the two variables are equal means that no changes were found.
    if($WowFilesSizeSum -eq $WowFilesBackupSizeSum){
        Write-OutPut "No changes found, daily backup job stopping..."
        Exit
    }
    #Copying the actual folders and their childs to the backup location.
    foreach($WowFolder in $WowFolders){
        if(Test-Path "$WowBackupPath\$WowFolder"){
            Remove-Item -Path "$WowBackupPath\$WowFolder" -Recurse -Force
        }
        Copy-Item -Path "$WowPathRoot\$WowFolder" -Destination "$WowBackupPath\$WowFolder" -Recurse -Force
    }
    Write-Output "Backup completed successfully"
}
New-WowBackup
