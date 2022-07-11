#Master script acts as the manager of the entire "system" Script will be ran via a batch (.exe) file.

#Variables
[datetime]$Date = (Get-Date)
[string]$DateString = $Date.ToString("yyyy-MM-ddT")
[string]$WowPathRoot = ""
[string]$WowBackupPath = ""
[Object]$WowBackupConfigFile
[boolean]$WowBackupFirstRun = $true
[boolean]$WowBackupPathCorrect = $false
[string]$WowAutomaticBackup = ""
[string]$WowAutomaticBackupTimeOfDay = ""
[boolean]$WowAutomaticBackupTimeOfDay = $false
[string]$WowAutomaticBackupConfigXMLPath = ".\XML\Scheduled Task\BackupWowFoldersBatchJob.xml"
[xml]$WowAutomaticBackupConfigXML

#Modules path variables
[string]$WowAutomaticBackupScriptPath = ".\Modules\WowBackupAutomaticDeployment.ps1"
[string]$WowAutomaticBackupScriptLitteralPath = ""

function Start-MainMenu(){
    param()    
}

function Get-FirstTimeRun(){
    param(
        [boolean]$DoNotDisplayWriteOutput = $false
    )
    if(!$DoNotDisplayWriteOutput){
        try{
            $WowBackupConfigFile = Get-Content .\WowBackupConfig.json -ErrorAction Stop
        }   
        catch{
            Write-Warning "First time run detected, starting the initial setup..."
        }
        if(!$WowBackupFirstRun){
            Return
        }   
        #$WowPathRoot = (Get-WowPath -Verbose)[2] #Returns all write-output aswell, only interested in the actual wow path
        #Get-UserInput -AskForFirstTimeSetup $true
        Write-Output "As part of the initialisation of the solution, please provide answers to the following..."
        Write-Output "Please type in the wanted folder location for all future wow classic backups..."
        Write-Warning "It is highly recommended to NOT use the C:\ drive for backup. Think cloud storage like onedrive or a NAS fx whenever possible..."
    }
    $WowBackupPath = Read-Host "Wanted path - eg. F:\WowBackup\ or press enter to use the default placement"
    if($WowBackupPath.Length -eq 0){
        $WowBackupPath = "$([Environment]::GetFolderPath("Desktop"))\WowBackupFolder\"
        Write-Warning "Default path choosen, which will be: $WowBackupPath"
        try{
            New-Item -ItemType Directory -Path $WowBackupPath -ErrorAction Stop | Out-Null
        }
        catch{
            if(Test-Path "$([Environment]::GetFolderPath("Desktop"))\WowBackupFolder\"){
                Break
            }
            Write-Warning "Failed to create the folder due to the following error:`n$($_.Exception.Message)`nPlease fix the error and run the script again"
            Exit
       }
    }
    else{
        do{
            while($WowBackupPath -notmatch '^[a-zA-Z]:\\(((?![<>:"/\\|?*]).)+((?<![ .])\\)?)*$' -and $WowBackupPath -notmatch '^(\\)(\\[\w\.-_]+){1,}(\\?)$'){
                Write-Warning "The inserted path: $WowBackupPath is not supported. Please provide a path in one of two formats:"
                Write-Output "1: <driveletter>:\<whateverfolderyouwish>\ eg. D:\BackupOfWowConfigFiles\ which makes a local backup..."
                Write-Output "2: \\<networksharename\<whateverfolderyouwish>\ eg. \\myhomeNASserver\WowBackup\ which makes a remote backup..."
                $WowBackupPath = Read-Host "Wanted path - eg. F:\WowBackup\"
            }
            try{
                New-Item -ItemType Directory -Path $WowBackupPath -ErrorAction Stop | Out-Null
            }
            catch{
                Write-Warning "Failed to create the folder due to the following error:`n$($_.Exception.Message)`nPlease type a new path..."
                
                Get-FirstTimeRun -DoNotDisplayWriteOutput $true
            }
            if(Test-Path $WowBackupPath){
                $WowBackupPathCorrect = $true
            }
        }
        while(!$WowBackupPathCorrect)
    }
    #Might have to be moved further down in terms of the order of questions and actions needed as part of the initial setup. Must take a repeak at the flowchart...
    $WowAutomaticBackup = Read-Host "Do you want to setup automatic backup now? Press enter for yes and n for no..."
    if($WowAutomaticBackup.Length -eq 0){
        Add-WowAutomaticBackup -WowBackupPath $WowBackupPath
    }

}

function Get-UserInput(){
    param(
        [boolean]$AskForAutomaticBackup = $false,
        [boolean]$AskForInitialiseManualBackup = $false,
        [boolean]$AskForRecoverFromBackup = $false,
        [boolean]$AskForUninstallAutomaticBackup = $false,
        [boolean]$AskForWowBackupExit = $false,
        [boolean]$AskForFirstTimeSetup = $false
    )
    if($AskForAutomaticBackup){

    }
    if($AskForInitialiseManualBackup){

    }
    if($AskForRecoverFromBackup){

    }
    if($AskForUninstallAutomaticBackup){

    }
    if($AskForWowBackupExit){

    }
    if($AskForFirstTimeSetup){

    }
}

function Get-WowPath(){
    param()
    Write-Verbose "Looking for Wow Classic, please wait..."
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

function Add-WowAutomaticBackup(){
    param(
        [string]$WowBackupPath
    )
    [string]$WowAutomaticBackupConfigXMLSubstring = ""
    Write-Warning "Please remember to choose a timeslot where the PC will most likely be on. Wow does not have to be open..."
    do{
        $WowAutomaticBackupTimeOfDay = Read-Host "Please provide the wanted time for the backup to run. Use format: HH:mm, eg. 21:00"
        if($WowAutomaticBackupTimeOfDay -match "^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$"){
            $WowAutomaticBackupTimeOfDayCorrect = $true
            $WowAutomaticBackupTimeOfDay = $WowAutomaticBackupTimeOfDay.Insert(5,":00")
        }
    }
    while(!$WowAutomaticBackupTimeOfDayCorrect)
    $WowAutomaticBackupConfigXML = Get-Content -Path $WowAutomaticBackupConfigXMLPath
    for($i = 0; $i -le $WowAutomaticBackupConfigXML.Count -1;$i++){
        if($WowAutomaticBackupConfigXML[$i] -like "*<StartBoundary>*"){
            $WowAutomaticBackupConfigXMLSubstring = $WowAutomaticBackupConfigXML[$i].Split("<StartBoundary>").Split("</StartBoundary>")[1] #There is a return in 0
            $WowAutomaticBackupConfigXML[$i] = $WowAutomaticBackupConfigXML[$i].Replace("$WowAutomaticBackupConfigXMLSubstring","")
            $WowAutomaticBackupConfigXML[$i] = ($WowAutomaticBackupConfigXML[$i].Insert(21,"$($WowAutomaticBackupTimeOfDay)")).Insert(21, "$($DateString)")
        }
        if($WowAutomaticBackupConfigXML[$i] -like "*<Arguments>*"){
            $WowAutomaticBackupConfigXMLSubstring = $WowAutomaticBackupConfigXML[$i].Split("-File ").Split("</").Replace('"',"") | Select-Object -First 2 | Select-Object -Last 1
            $WowAutomaticBackupConfigXML[$i] = $WowAutomaticBackupConfigXML[$i].Replace("$WowAutomaticBackupConfigXMLSubstring","")
            $WowAutomaticBackupScriptLitteralPath = (Get-ChildItem -Path $WowAutomaticBackupScriptPath).FullName
            $WowAutomaticBackupConfigXML[$i] = $WowAutomaticBackupConfigXML[$i].Insert(44, "$($WowAutomaticBackupScriptLitteralPath)")
        }
    }
    $WowAutomaticBackupConfigXML | Out-File $WowAutomaticBackupConfigXMLPath -Force 3>null #Updated scheduled config file saved in the local folder. Will be updated every time function is run.
    Write-Verbose "Setting up the automatic backup, please wait..."
    if(Get-ScheduledTask | % {if($_.TaskName -eq "WowBackupScheduledTask"){$true;$TaskName = $_.TaskName}}){
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    schtasks /Create /XML $WowAutomaticBackupConfigXMLPath /tn "WowBackupScheduledTask" | Out-Null
    Write-Host -ForegroundColor "Green" -BackgroundColor "Black" "Creating scheduled task completed with status OK`nAll configuration files will now be updated at $WowAutomaticBackupTimeOfDay every day"
    Write-Verbose "Returning to initial setup..."
    Return
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
#Get-FirstTimeRun
Add-WowAutomaticBackup