##########
# Optimization-Windows11 - adapté par Armand depuis Optimization-Windows-V3 (Metaljisawa)
# Base d'origine : https://github.com/Disassembler0/Win10-Initial-Setup-Script
# Toutes les fonctions sont sans effet si la clé/valeur n'existe pas (ErrorAction SilentlyContinue),
# et fournies par paires Disable-/Enable- pour rester réversibles.
##########

# ------------------------------------------------------------------
#region Utilitaires
# ------------------------------------------------------------------

function Test-IsAdmin {
    <#
        Vérifie que le script tourne en administrateur. Beaucoup de tweaks
        échouent silencieusement sinon.
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-RestorePointSafe {
    <#
        Crée un point de restauration système avant d'appliquer des tweaks.
        Best-effort : la fréquence de création est limitée par Windows (24h par défaut),
        donc l'échec est normal si un point récent existe déjà.
    #>
    try {
        Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Avant Optimization-Windows11" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Output "Point de restauration créé."
        return $true
    } catch {
        Write-Warning "Impossible de créer un point de restauration (peut-être déjà un point récent) : $($_.Exception.Message)"
        return $false
    }
}

#endregion

# ------------------------------------------------------------------
#region Bloatware
# ------------------------------------------------------------------

function Remove-BloatwareApp {
    <#
        Supprime une application préinstallée pour tous les utilisateurs actuels
        ET retire le paquet provisionné pour qu'elle ne revienne pas pour les
        futurs comptes utilisateurs (Get-AppxProvisionedPackage).
    #>
    param(
        [Parameter(Mandatory)][string]$PackageName,
        [string]$DisplayName = $PackageName
    )

    Write-Output "Suppression de $DisplayName..."

    Get-AppxPackage -Name $PackageName -AllUsers -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $PackageName } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}

function Clear-BloatwareRegistryLeftovers {
    <#
        Nettoyage best-effort des résidus de tuiles du menu Démarrer après
        suppression d'applications. Redémarre l'explorateur de tuiles.
    #>
    Write-Output "Nettoyage des résidus de tuiles du menu Démarrer..."
    try {
        $key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.placeholdertilecollection\Current" -ErrorAction SilentlyContinue
        if ($key) {
            Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $key.Data[0..15]
        }
        Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Nettoyage des résidus : $($_.Exception.Message)"
    }
}

#endregion

# ------------------------------------------------------------------
#region Confidentialité (Privacy Tweaks)
# ------------------------------------------------------------------

function Disable-Telemetry {
    Write-Output "Désactivation de la télémétrie..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" -ErrorAction SilentlyContinue | Out-Null
}
function Enable-Telemetry {
    Write-Output "Réactivation de la télémétrie..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 3 -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    Enable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue | Out-Null
    Enable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue | Out-Null
    Enable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue | Out-Null
    Enable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" -ErrorAction SilentlyContinue | Out-Null
}

function Disable-SmartScreen {
    Write-Output "Désactivation du filtre SmartScreen..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-SmartScreen {
    Write-Output "Réactivation du filtre SmartScreen..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -ErrorAction SilentlyContinue
}

function Disable-WebSearch {
    Write-Output "Désactivation de la recherche Bing dans le menu Démarrer..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Type DWord -Value 1
}
function Enable-WebSearch {
    Write-Output "Réactivation de la recherche Bing dans le menu Démarrer..."
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -ErrorAction SilentlyContinue
}

function Disable-StartRecommendations {
    Write-Output "Désactivation des recommandations dans le menu Démarrer..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-StartRecommendations {
    Write-Output "Réactivation des recommandations dans le menu Démarrer..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}

function Disable-ActivityHistory {
    Write-Output "Désactivation de l'historique d'activités..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-ActivityHistory {
    Write-Output "Réactivation de l'historique d'activités..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -ErrorAction SilentlyContinue
}

function Disable-BackgroundApps {
    Write-Output "Désactivation des applications en arrière-plan..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Type DWord -Value 2
}
function Enable-BackgroundApps {
    Write-Output "Réactivation des applications en arrière-plan..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -ErrorAction SilentlyContinue
}

function Disable-Location {
    Write-Output "Désactivation du service de localisation..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Type DWord -Value 1
}
function Enable-Location {
    Write-Output "Réactivation du service de localisation..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -ErrorAction SilentlyContinue
}

function Disable-Feedback {
    Write-Output "Désactivation des demandes de feedback Windows..."
    if (!(Test-Path "HKCU:\Software\Microsoft\Siuf\Rules")) { New-Item -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Force | Out-Null }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}
function Enable-Feedback {
    Write-Output "Réactivation des demandes de feedback Windows..."
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -ErrorAction SilentlyContinue
}

function Disable-TailoredExperiences {
    Write-Output "Désactivation des publicités personnalisées..."
    if (!(Test-Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent")) { New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null }
    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Type DWord -Value 1
}
function Enable-TailoredExperiences {
    Write-Output "Réactivation des publicités personnalisées..."
    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -ErrorAction SilentlyContinue
}

function Disable-AdvertisingID {
    Write-Output "Désactivation de l'identifiant publicitaire..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Type DWord -Value 1
}
function Enable-AdvertisingID {
    Write-Output "Réactivation de l'identifiant publicitaire..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -ErrorAction SilentlyContinue
}

function Disable-Cortana {
    Write-Output "Désactivation de Cortana (résiduel)..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Type DWord -Value 0
}
function Enable-Cortana {
    Write-Output "Réactivation de Cortana..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -ErrorAction SilentlyContinue
}

function Disable-RecentFiles {
    Write-Output "Désactivation de la liste des fichiers récents..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoRecentDocsHistory" -Type DWord -Value 1
}
function Enable-RecentFiles {
    Write-Output "Réactivation de la liste des fichiers récents..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoRecentDocsHistory" -ErrorAction SilentlyContinue
}

# --- Spécifique Windows 11 ---

function Disable-Widgets {
    Write-Output "Désactivation des Widgets (panneau actualités et centres d'intérêt)..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-Widgets {
    Write-Output "Réactivation des Widgets..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}

function Disable-Copilot {
    Write-Output "Désactivation de Copilot..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-Copilot {
    Write-Output "Réactivation de Copilot..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}

function Disable-ChatIcon {
    # NOTE : l'icône Chat/Teams a été retirée par défaut sur les builds récentes de Windows 11 (23H2+).
    # Cette fonction reste sans effet (no-op propre) sur ces versions, mais utile si présente.
    Write-Output "Désactivation de l'icône Chat/Teams dans la barre des tâches (si présente)..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-ChatIcon {
    Write-Output "Réactivation de l'icône Chat/Teams..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}

#endregion

# ------------------------------------------------------------------
#region Sécurité (Security Tweaks)
# ------------------------------------------------------------------

function Set-UACHigh {
    Write-Output "Réglage de l'UAC au niveau maximum..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value 5 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}
function Set-UACLow {
    Write-Output "Réglage de l'UAC au niveau minimum (déconseillé)..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}

function Disable-SMB1 {
    Write-Output "Désactivation du protocole SMB 1.0 (obsolète, faille EternalBlue)..."
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction SilentlyContinue | Out-Null
}
function Enable-SMB1 {
    Write-Output "Réactivation du protocole SMB 1.0..."
    Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction SilentlyContinue | Out-Null
}

function Disable-NetBIOS {
    Write-Output "Désactivation de NetBIOS sur TCP/IP..."
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PsPath -Name "NetbiosOptions" -Type DWord -Value 2
    }
}
function Enable-NetBIOS {
    Write-Output "Réactivation de NetBIOS sur TCP/IP..."
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PsPath -Name "NetbiosOptions" -Type DWord -Value 0
    }
}

function Disable-LLMNR {
    Write-Output "Désactivation de LLMNR (résolution de noms multicast, vecteur d'attaque connu)..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Type DWord -Value 0
}
function Enable-LLMNR {
    Write-Output "Réactivation de LLMNR..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue
}

function Disable-RemoteAssistance {
    Write-Output "Désactivation de l'assistance à distance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-RemoteAssistance {
    Write-Output "Réactivation de l'assistance à distance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}

function Disable-RemoteDesktop {
    Write-Output "Désactivation du Bureau à distance (ignorer si tu l'utilises)..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Disable-NetFirewallRule -DisplayGroup "Bureau à distance" -ErrorAction SilentlyContinue
    Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
}
function Enable-RemoteDesktop {
    Write-Output "Réactivation du Bureau à distance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Bureau à distance" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
}

function Disable-AdminShares {
    Write-Output "Désactivation des partages administratifs par défaut..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Enable-AdminShares {
    Write-Output "Réactivation des partages administratifs par défaut..."
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks" -ErrorAction SilentlyContinue
}

function Enable-ControlledFolderAccess {
    Write-Output "Activation de l'accès contrôlé aux dossiers (protection anti-ransomware Defender)..."
    Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
}
function Disable-ControlledFolderAccess {
    Write-Output "Désactivation de l'accès contrôlé aux dossiers..."
    Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction SilentlyContinue
}

function Enable-CoreIsolationMemoryIntegrity {
    Write-Output "Activation de l'intégrité de la mémoire (isolation du noyau)... (redémarrage requis, vérifier compatibilité pilotes avant)"
    if (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity")) {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Type DWord -Value 1
}
function Disable-CoreIsolationMemoryIntegrity {
    Write-Output "Désactivation de l'intégrité de la mémoire..."
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -ErrorAction SilentlyContinue
}

#endregion

# ------------------------------------------------------------------
#region Services & Performance
# ------------------------------------------------------------------

function Disable-Hibernation {
    Write-Output "Désactivation de l'hibernation (libère de l'espace disque)..."
    powercfg /HIBERNATE OFF 2>&1 | Out-Null
}
function Enable-Hibernation {
    Write-Output "Activation de l'hibernation..."
    powercfg /HIBERNATE ON 2>&1 | Out-Null
}

function Disable-Superfetch {
    Write-Output "Arrêt et désactivation de SysMain (ex-Superfetch)... recommandé si disque SSD"
    Stop-Service "SysMain" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
}
function Enable-Superfetch {
    Write-Output "Réactivation de SysMain (ex-Superfetch)..."
    Set-Service "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service "SysMain" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
}

function Disable-DiagTrack {
    Write-Output "Arrêt et désactivation du service de télémétrie DiagTrack..."
    Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
}
function Enable-DiagTrack {
    Write-Output "Réactivation du service DiagTrack..."
    Set-Service "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
}

function Set-P2PUpdateLocalOnly {
    Write-Output "Restriction des mises à jour en P2P au réseau local uniquement..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Type DWord -Value 1
}
function Set-P2PUpdateDisabled {
    Write-Output "Désactivation complète des mises à jour en P2P..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Type DWord -Value 0
}
function Set-P2PUpdateInternet {
    Write-Output "Autorisation des mises à jour en P2P via Internet (comportement par défaut)..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -ErrorAction SilentlyContinue
}

function Enable-StorageSense {
    Write-Output "Activation du nettoyage automatique de disque (Storage Sense)..."
    if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Type DWord -Value 1
}
function Disable-StorageSense {
    Write-Output "Désactivation du nettoyage automatique de disque (Storage Sense)..."
    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Recurse -ErrorAction SilentlyContinue
}

function Disable-ScheduledDefrag {
    Write-Output "Désactivation de la défragmentation programmée (inutile sur SSD)..."
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue | Out-Null
}
function Enable-ScheduledDefrag {
    Write-Output "Réactivation de la défragmentation programmée..."
    Enable-ScheduledTask -TaskName "Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue | Out-Null
}

function Enable-ClipboardHistory {
    Write-Output "Activation de l'historique du presse-papiers..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}
function Disable-ClipboardHistory {
    Write-Output "Désactivation de l'historique du presse-papiers..."
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -ErrorAction SilentlyContinue
}

function Disable-Autoplay {
    Write-Output "Désactivation de la lecture automatique..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Type DWord -Value 1 -ErrorAction SilentlyContinue
}
function Enable-Autoplay {
    Write-Output "Réactivation de la lecture automatique..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}

function Disable-XboxServices {
    Write-Output "Désactivation des services Xbox en arrière-plan (utile si tu ne joues pas)..."
    foreach ($svc in @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc")) {
        Stop-Service $svc -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }
}
function Enable-XboxServices {
    Write-Output "Réactivation des services Xbox en arrière-plan..."
    foreach ($svc in @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc")) {
        Set-Service $svc -StartupType Manual -ErrorAction SilentlyContinue
    }
}

function Disable-WAPPush {
    Write-Output "Arrêt et désactivation du service d'alertes WAP push..."
    Stop-Service "dmwappushservice" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Set-Service "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
}
function Enable-WAPPush {
    Write-Output "Réactivation du service d'alertes WAP push..."
    Set-Service "dmwappushservice" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service "dmwappushservice" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
}

#endregion

Export-ModuleMember -Function *
