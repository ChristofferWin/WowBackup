#Master script acts as the manager of the entire "system" Script will be ran via a batch (.exe) file.

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(!($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))){
    if(!(Test-Path ".\WowBackupConfig.json")){
        if((Get-location).Path -notlike "$env:USERPROFILE*"){
        Write-Warning "The choosen location for the WowBackup.exe is not suited for when the software is run without admin mode."
        Write-Warning "Either move the WowBackup folder to inside your own user folder or restart the program as administrator."
        Exit
        }
    }
    Write-Warning "The software has NOT being started as an administrator."
    Write-Warning "Do not try to set the WowBackup path to somewhere not in your user folder."
    Write-Warning "The automatic backup feature can only be setup in admin mode."
    if(Read-Host "Do you want to continue? Press enter for yes and n for no..." | ? { $_.Length -gt 0}){
        Exit
    }
    [boolean]$NotInAdmin = $true
    cls
}

#Have to code my way out of the condition of the script not being run in admin mode - Goal is to make it work even without admin and instead controlling the features that must be disabled when not as admin

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
[string]$WowBackupConfigFilePath = ".\WowBackupConfig.json"
[System.Collections.ArrayList]$WowMainMenuOptions = @("Setup Automatic backup","Start manual backup","Recover from backup","Uninstall Automatic backup","Delete backup","Change backup path","Exit WowBackup.exe")
[int]$WowBackupCurrentSize = 0

#Modules path variables
[string]$WowAutomaticBackupScriptPath = ".\Modules\WowBackupAutomaticDeployment.ps1"
[string]$WowAutomaticBackupScriptLitteralPath = ""

function Start-MainMenu(){
    param()
    [string]$LocalMainMenuChoice = ""
    [array]$LocalMainMenuConfigFile = @()
    cls
    $LocalMainMenuConfigFile = Get-Content .\WowBackupConfig.json | ConvertFrom-Json
    try{
        $WowBackupCurrentSize = Get-ChildItem -Path $LocalMainMenuConfigFile.WowBackupPath -Recurse
    }
    Write-Host "####################### MAIN MENU #######################`n"
    Write-Host "Please choose an operation:`n"
    if($NotInAdmin){
        $WowMainMenuOptions.Remove("Setup Automatic backup")
    }
    for($i = 1; $i -le $WowMainMenuOptions.Count ;$i++){
        Write-Host "($($i)) $($WowMainMenuOptions[$i -1])"
    }
    Write-Host "`nCurrent Backup path: $($LocalMainMenuConfigFile.WowBackupPath)`nCurrent Backup size in MB: $()$(if($LocalMainMenuConfigFile.WowAutomaticBackup -eq "true"){"Wowbackup enabled and running every day at: $($LocalMainMenuConfigFile.WowBackupAutomaticTime)"})"
    do{
        [boolean]$LocalMainMenuChoiceCorrect = $true
        $LocalMainMenuChoice = Read-Host "Please press the main menu number"
        if($LocalMainMenuChoice | ? {$_ -match "^(0?[1-9]|[1-9][0-9])$"}){
            [int]$LocalMainMenuChoice = $LocalMainMenuChoice
        }
        if($NotInAdmin){
            $LocalMainMenuChoice++
        }
        switch($LocalMainMenuChoice){
            1 {Add-WowAutomaticBackup;Reset-MainMenu;Start-MainMenu}
            2 {New-WowManualBackup;Reset-MainMenu;Start-MainMenu}
            3 {Restore-FromWowBackup;Reset-MainMenu;Start-MainMenu}
            4 {Uninstall-AutomaticBackup;Reset-MainMenu;Start-MainMenu}
            5 {Remove-WowBackup;Reset-MainMenu;Start-MainMenu}
            6 {Set-WowBackupPath;Reset-MainMenu;Start-MainMenu}
            7 {Exit}
            default {$LocalMainMenuChoiceCorrect = $false}
        }
    }
    while(!$LocalMainMenuChoiceCorrect)
}

function Reset-MainMenu(){
    param()
    Write-Host "Press any key to return to the main menu..."
    Read-Host
    cls
}
function Get-FirstTimeRun(){
    param(
        [boolean]$DoNotDisplayWriteOutput = $false
    )
    [hashtable]$LocalFirstTimeRunConfigFile = @{}
    if(!$DoNotDisplayWriteOutput){
        try{
            $WowBackupConfigFile = Get-Content $WowBackupConfigFilePath -ErrorAction Stop
            $WowBackupFirstRun = $false
        }   
        catch{
            Write-Warning "First time run detected, starting the initial setup..."
        }
        if(!$WowBackupFirstRun){
            Return
        }   
        
        Write-Output "As part of the initialisation of the solution, please provide answers to the following..."
        Write-Output "Please type in the wanted folder location for all future wow classic backups:"
        Write-Warning "It is highly recommended to NOT use the C:\ drive for backup. Think cloud storage like onedrive or a NAS fx whenever possible."
    }
    $WowBackupPath = Read-Host "Wanted path - eg. F:\WowBackup\ or press enter to use the default placement"
    if($WowBackupPath.Length -eq 0){
        $WowBackupPath = "$([Environment]::GetFolderPath("Desktop"))\WowBackupFolder\"
        Write-Warning "Default path choosen, which will be: $WowBackupPath"
        try{
            New-Item -ItemType Directory -Path $WowBackupPath -ErrorAction Stop | Out-Null
        }
        catch{
            if(!(Test-Path "$([Environment]::GetFolderPath("Desktop"))\WowBackupFolder\")){
                Write-Warning "Failed to create the folder due to the following error:`n$($_.Exception.Message)`nPlease fix the error and run the script again"
                Exit
            }
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
    if(!$NotInAdmin){
        $WowAutomaticBackup = Read-Host "Do you want to setup automatic backup now? Press enter for yes and n for no..."
        if($WowAutomaticBackup.Length -eq 0){
            [boolean]$WowAutomaticBackup = $true
        }
    }
    $LocalFirstTimeRunConfigFile.Add("Userprofile","$(whoami)")
    $LocalFirstTimeRunConfigFile.Add("WowBackupPath","$WowBackupPath")
    $LocalFirstTimeRunConfigFile.Add("WowAutomaticBackup","$(if($WowAutomaticBackup.Length -gt 0){"true"}else{"false"})")
    Set-WowBackupConfigFile -LocalFilePath $WowBackupConfigFilePath -LocalFirstTimeRunConfigFile ($LocalFirstTimeRunConfigFile | ConvertTo-Json)
    if($WowAutomaticBackup){
        Add-WowAutomaticBackup -WowBackupPath $WowBackupPath
    }
    Write-Host -ForegroundColor "Green" -BackgroundColor "Black" "Initial setup complete"
    Write-Verbose "Press any key to return to the main menu or CTRL + C to stop the script"
    Read-Host
    Start-MainMenu
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
    $LocalFirstTimeRunConfigFile = Get-Content -Path $WowBackupConfigFilePath | ConvertFrom-Json
    $LocalFirstTimeRunConfigFile | Add-Member -MemberType NoteProperty -Name "WowBackupAutomaticTime" -Value $WowAutomaticBackupTimeOfDay -Force
    Set-WowBackupConfigFile -LocalFilePath $WowBackupConfigFilePath -LocalFirstTimeRunConfigFile ($LocalFirstTimeRunConfigFile | ConvertTo-Json)
    Set-WowBackupConfigFile -LocalFilePath $WowAutomaticBackupConfigXMLPath -LocalFirstTimeRunConfigFile $WowAutomaticBackupConfigXML #Updated scheduled config file saved in the local folder. Will be updated every time function is run.
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

function Set-WowBackupConfigFile(){
    param(
    [Object]$LocalFirstTimeRunConfigFile,
    [string]$LocalFilePath
    )
    try{
        $LocalFirstTimeRunConfigFile | Out-File $LocalFilePath -Force 3>$null
    }
    catch{
        Write-Warning "It was not possible to update the configuration file $LocalFilePath due to the following error:`n$_"
    }
}

#Execution
Write-Information "Checking for first time use, please wait..."
#Function structure wise - Right now the function Get-FirsttimeRun will only return void IF the json file exist. I think its smarter to always return void and then call the start-mainmenu as of right now, the start-mainmenu is also called within the Get-FirstTimeRun function.
Get-FirstTimeRun
Start-MainMenu
