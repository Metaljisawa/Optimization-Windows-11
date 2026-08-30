#Requires -Version 5.1
<#
    Optimization-Windows11.ps1
    Adapté par Armand depuis Optimization-Windows-V3 (Metaljisawa) pour Windows 11.

    UTILISATION :
      1. Clic droit sur le fichier > "Exécuter avec PowerShell" (ou lancer PowerShell/ISE en administrateur
         puis exécuter .\Win11.ps1)
      2. Une fenêtre de sélection s'ouvre : coche (Ctrl+clic ou Maj+clic pour sélection multiple)
         les tweaks que tu veux appliquer, puis clique sur "OK".
      3. Le script demande confirmation avant d'exécuter quoi que ce soit.

    Le fichier Win11.psm1 doit être dans le même dossier que ce script.
#>

# ------------------------------------------------------------------
# 0. Vérifications préalables
# ------------------------------------------------------------------

$ModulePath = Join-Path $PSScriptRoot "Win11.psm1"
if (-not (Test-Path $ModulePath)) {
    Write-Error "Win11.psm1 introuvable dans $PSScriptRoot. Les deux fichiers doivent être dans le même dossier."
    exit 1
}
Import-Module $ModulePath -Force

if (-not (Test-IsAdmin)) {
    Write-Error "Ce script doit être exécuté en tant qu'administrateur. Relance PowerShell avec 'Exécuter en tant qu'administrateur'."
    exit 1
}

$LogFile = Join-Path $PSScriptRoot ("Win11-Optimization_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $LogFile -Append | Out-Null

# ------------------------------------------------------------------
# 1. Catalogue des applications préinstallées (bloatware) - Windows 11 (24H2/25H2)
#    Ajoute/retire des lignes ici pour personnaliser la liste.
# ------------------------------------------------------------------

$BloatwareCatalog = @(
    [PSCustomObject]@{ Package = "Microsoft.549981C3F5F10";              Display = "Cortana (résidu)" }
    [PSCustomObject]@{ Package = "Microsoft.BingNews";                   Display = "Actualités (MSN)" }
    [PSCustomObject]@{ Package = "Microsoft.BingWeather";                Display = "Météo" }
    [PSCustomObject]@{ Package = "Microsoft.GetHelp";                    Display = "Obtenir de l'aide" }
    [PSCustomObject]@{ Package = "Microsoft.Getstarted";                 Display = "Astuces / Prise en main" }
    [PSCustomObject]@{ Package = "Microsoft.MicrosoftOfficeHub";         Display = "Centre Office (pub Office 365)" }
    [PSCustomObject]@{ Package = "Microsoft.MicrosoftSolitaireCollection"; Display = "Collection Solitaire" }
    [PSCustomObject]@{ Package = "Microsoft.MixedReality.Portal";        Display = "Portail réalité mixte" }
    [PSCustomObject]@{ Package = "Microsoft.People";                     Display = "Contacts" }
    [PSCustomObject]@{ Package = "Microsoft.PowerAutomateDesktop";       Display = "Power Automate Desktop" }
    [PSCustomObject]@{ Package = "Microsoft.Todos";                      Display = "Microsoft To Do" }
    [PSCustomObject]@{ Package = "Microsoft.WindowsAlarms";              Display = "Alarmes et horloge" }
    [PSCustomObject]@{ Package = "Microsoft.WindowsFeedbackHub";         Display = "Centre de commentaires" }
    [PSCustomObject]@{ Package = "Microsoft.WindowsMaps";                Display = "Cartes" }
    [PSCustomObject]@{ Package = "Microsoft.WindowsSoundRecorder";       Display = "Enregistreur vocal" }
    [PSCustomObject]@{ Package = "Microsoft.Wallet";                     Display = "Portefeuille" }
    [PSCustomObject]@{ Package = "Microsoft.YourPhone";                  Display = "Liaison au téléphone (Phone Link)" }
    [PSCustomObject]@{ Package = "Microsoft.ZuneMusic";                  Display = "Lecteur multimédia (ex-Groove)" }
    [PSCustomObject]@{ Package = "Microsoft.ZuneVideo";                  Display = "Films et TV" }
    [PSCustomObject]@{ Package = "Microsoft.Xbox.TCUI";                  Display = "Xbox - Interface commune" }
    [PSCustomObject]@{ Package = "Microsoft.XboxApp";                    Display = "Xbox App (ancienne)" }
    [PSCustomObject]@{ Package = "Microsoft.GamingApp";                  Display = "Xbox App (nouvelle)" }
    [PSCustomObject]@{ Package = "Microsoft.XboxGameOverlay";            Display = "Overlay de jeu Xbox" }
    [PSCustomObject]@{ Package = "Microsoft.XboxGamingOverlay";          Display = "Overlay Xbox Game Bar" }
    [PSCustomObject]@{ Package = "Microsoft.XboxIdentityProvider";       Display = "Fournisseur d'identité Xbox" }
    [PSCustomObject]@{ Package = "Microsoft.XboxSpeechToTextOverlay";    Display = "Xbox - Synthèse vocale" }
    [PSCustomObject]@{ Package = "Clipchamp.Clipchamp";                  Display = "Clipchamp (éditeur vidéo)" }
    [PSCustomObject]@{ Package = "Microsoft.Windows.DevHome";            Display = "Dev Home" }
    [PSCustomObject]@{ Package = "Microsoft.OutlookForWindows";          Display = "Nouveau Outlook (préinstallé)" }
    [PSCustomObject]@{ Package = "Microsoft.549981C3F5F10_Copilot";      Display = "Application Copilot" }
    [PSCustomObject]@{ Package = "MicrosoftTeams";                       Display = "Teams (préinstallé)" }
    [PSCustomObject]@{ Package = "Microsoft.SkypeApp";                   Display = "Skype" }
)

# ------------------------------------------------------------------
# 2. Catalogue des tweaks (Confidentialité / Sécurité / Services)
#    Action = un ScriptBlock qui appelle la fonction correspondante du module.
# ------------------------------------------------------------------

$TweakCatalog = @(
    # --- Confidentialité ---
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver la télémétrie";                         Action={ Disable-Telemetry } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver SmartScreen";                           Action={ Disable-SmartScreen } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver la recherche Bing dans le menu Démarrer"; Action={ Disable-WebSearch } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver les recommandations du menu Démarrer";  Action={ Disable-StartRecommendations } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver l'historique d'activités";              Action={ Disable-ActivityHistory } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver les applications en arrière-plan";      Action={ Disable-BackgroundApps } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver la localisation";                       Action={ Disable-Location } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver les demandes de feedback";              Action={ Disable-Feedback } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver la pub personnalisée (Tailored Experiences)"; Action={ Disable-TailoredExperiences } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver l'identifiant publicitaire";            Action={ Disable-AdvertisingID } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver Cortana (résiduel)";                    Action={ Disable-Cortana } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver l'historique des fichiers récents";     Action={ Disable-RecentFiles } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver les Widgets";                           Action={ Disable-Widgets } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver Copilot";                                Action={ Disable-Copilot } }
    [PSCustomObject]@{ Category="Confidentialité"; Display="Désactiver l'icône Chat/Teams (si présente)";      Action={ Disable-ChatIcon } }

    # --- Sécurité ---
    [PSCustomObject]@{ Category="Sécurité"; Display="Renforcer l'UAC (niveau maximum)";                        Action={ Set-UACHigh } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Désactiver SMB 1.0 (obsolète, faille EternalBlue)";       Action={ Disable-SMB1 } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Désactiver NetBIOS sur TCP/IP";                           Action={ Disable-NetBIOS } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Désactiver LLMNR";                                        Action={ Disable-LLMNR } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Désactiver l'assistance à distance";                      Action={ Disable-RemoteAssistance } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Désactiver le Bureau à distance (ignorer si utilisé)";    Action={ Disable-RemoteDesktop } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Désactiver les partages administratifs par défaut";       Action={ Disable-AdminShares } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Activer l'accès contrôlé aux dossiers (anti-ransomware)"; Action={ Enable-ControlledFolderAccess } }
    [PSCustomObject]@{ Category="Sécurité"; Display="Activer l'intégrité de la mémoire (isolation du noyau)";  Action={ Enable-CoreIsolationMemoryIntegrity } }

    # --- Services / Performance ---
    [PSCustomObject]@{ Category="Services"; Display="Désactiver l'hibernation (libère de l'espace disque)";    Action={ Disable-Hibernation } }
    [PSCustomObject]@{ Category="Services"; Display="Désactiver SysMain / Superfetch (recommandé sur SSD)";    Action={ Disable-Superfetch } }
    [PSCustomObject]@{ Category="Services"; Display="Désactiver le service DiagTrack (télémétrie)";            Action={ Disable-DiagTrack } }
    [PSCustomObject]@{ Category="Services"; Display="Restreindre les MàJ P2P au réseau local";                 Action={ Set-P2PUpdateLocalOnly } }
    [PSCustomObject]@{ Category="Services"; Display="Activer le nettoyage auto de disque (Storage Sense)";     Action={ Enable-StorageSense } }
    [PSCustomObject]@{ Category="Services"; Display="Désactiver la défragmentation programmée (SSD)";          Action={ Disable-ScheduledDefrag } }
    [PSCustomObject]@{ Category="Services"; Display="Désactiver la lecture automatique (Autoplay)";            Action={ Disable-Autoplay } }
    [PSCustomObject]@{ Category="Services"; Display="Désactiver les services Xbox en arrière-plan";            Action={ Disable-XboxServices } }
    [PSCustomObject]@{ Category="Services"; Display="Désactiver le service WAP Push";                          Action={ Disable-WAPPush } }
)

# Ajout des entrées de bloatware au catalogue général, avec closure correcte sur $app
foreach ($app in $BloatwareCatalog) {
    $localApp = $app
    $TweakCatalog += [PSCustomObject]@{
        Category = "Bloatware"
        Display  = "Supprimer : $($localApp.Display)"
        Action   = { Remove-BloatwareApp -PackageName $localApp.Package -DisplayName $localApp.Display }.GetNewClosure()
    }
}

# ------------------------------------------------------------------
# 3. Menu interactif
# ------------------------------------------------------------------

function Select-Tweaks {
    param($Catalog)

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        Write-Host "Ouverture de la fenêtre de sélection (Ctrl+clic ou Maj+clic pour choisir plusieurs lignes)..." -ForegroundColor Cyan
        return $Catalog | Select-Object Category, Display, Action |
            Out-GridView -Title "Sélectionne les optimisations à appliquer, puis clique sur OK" -OutputMode Multiple
    }

    # Repli console si Out-GridView n'est pas disponible (ex: PowerShell 7 sans module GraphicalTools)
    Write-Host "`nOut-GridView indisponible, menu console :`n" -ForegroundColor Yellow
    for ($i = 0; $i -lt $Catalog.Count; $i++) {
        Write-Host ("[{0,3}] {1,-15} {2}" -f $i, $Catalog[$i].Category, $Catalog[$i].Display)
    }
    $input = Read-Host "`nEntre les numéros séparés par des virgules (ex: 0,3,7) ou 'a' pour tout sélectionner"
    if ($input -eq 'a') { return $Catalog }
    $indices = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    return $Catalog[$indices]
}

$Selected = Select-Tweaks -Catalog $TweakCatalog

if (-not $Selected -or $Selected.Count -eq 0) {
    Write-Host "Aucune sélection. Fin du script." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 0
}

Write-Host "`n=== Récapitulatif ($($Selected.Count) tweak(s) sélectionné(s)) ===" -ForegroundColor Cyan
$Selected | Group-Object Category | ForEach-Object {
    Write-Host "`n$($_.Name) :" -ForegroundColor Green
    $_.Group | ForEach-Object { Write-Host "  - $($_.Display)" }
}

$confirm = Read-Host "`nCréer un point de restauration système avant d'appliquer les changements ? (o/n)"
if ($confirm -eq 'o') {
    New-RestorePointSafe
}

$confirm2 = Read-Host "`nAppliquer ces $($Selected.Count) tweak(s) maintenant ? (o/n)"
if ($confirm2 -ne 'o') {
    Write-Host "Annulé par l'utilisateur." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 0
}

# ------------------------------------------------------------------
# 4. Exécution
# ------------------------------------------------------------------

$Results = @()
foreach ($tweak in $Selected) {
    try {
        & $tweak.Action
        $Results += [PSCustomObject]@{ Tweak = $tweak.Display; Statut = "OK" }
    } catch {
        Write-Warning "Échec sur '$($tweak.Display)' : $($_.Exception.Message)"
        $Results += [PSCustomObject]@{ Tweak = $tweak.Display; Statut = "ÉCHEC : $($_.Exception.Message)" }
    }
}

Write-Host "`n=== Résumé de l'exécution ===" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

Write-Host "`nTerminé. Un redémarrage est recommandé pour que tous les changements prennent effet." -ForegroundColor Green
Write-Host "Journal complet : $LogFile" -ForegroundColor DarkGray

Stop-Transcript | Out-Null
