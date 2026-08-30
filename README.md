Optimization-Windows11
Adapté du projet Optimization-Windows-V3 (Windows 10)
pour Windows 11 (24H2/25H2), lui-même inspiré de la base bien connue
Disassembler0/Win10-Initial-Setup-Script.
⚠️ Comme pour tout script de ce type : usage à tes risques, teste d'abord sur une machine
non critique ou avec un point de restauration récent. Certains tweaks (SMB1, Bureau à distance,
partages administratifs) peuvent casser des usages spécifiques (partage réseau, accès distant) —
lis bien chaque ligne du menu avant de valider.
Fichiers
`Win11.psm1` — module contenant toutes les fonctions de tweaks (bloatware, confidentialité,
sécurité, services), organisées en paires `Disable-XXX` / `Enable-XXX` réversibles.
`Win11.ps1` — script principal : ouvre un menu interactif pour cocher les tweaks à appliquer,
demande confirmation, propose un point de restauration, exécute et journalise le résultat.
Les deux fichiers doivent rester dans le même dossier.
Utilisation
Télécharge les deux fichiers dans un même dossier.
Clic droit sur `Win11.ps1` → Exécuter avec PowerShell, en tant qu'administrateur
(ou ouvre PowerShell en admin, `cd` dans le dossier, puis `.\Win11.ps1`).
Si Windows bloque l'exécution de scripts, lance d'abord (dans PowerShell admin) :
```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
Une fenêtre de sélection (Out-GridView) liste tous les tweaks disponibles, groupés par
catégorie (Bloatware / Confidentialité / Sécurité / Services). Sélectionne les lignes
voulues (Ctrl+clic ou Maj+clic pour une sélection multiple), puis clique sur OK.
Le script affiche un récapitulatif, propose de créer un point de restauration, demande
confirmation, puis applique les tweaks un par un.
Un redémarrage est recommandé à la fin.
Personnaliser
Liste du bloatware : modifie le tableau `$BloatwareCatalog` en haut de `Win11.ps1`
(ajoute/retire des lignes `Package` / `Display`).
Ajouter un tweak : écris la fonction `Disable-XXX` / `Enable-XXX` dans `Win11.psm1`,
puis ajoute une ligne correspondante dans `$TweakCatalog` (`Win11.ps1`) avec la catégorie,
le libellé affiché, et l'action (`Action={ Disable-XXX }`).
Différences principales avec la version Windows 10 d'origine
Ajout de tweaks propres à Windows 11 : Widgets, Copilot, icône Chat/Teams, recommandations
du menu Démarrer, services Xbox.
Bloatware mis à jour (Clipchamp, Dev Home, nouvel Outlook, appli Copilot, "Xbox App" nouvelle
génération `Microsoft.GamingApp`...).
Suppression des tweaks obsolètes sur Windows 11 (Wi-Fi Sense n'existe plus, drapeau de
compatibilité Meltdown/CVE-2017-5754 obsolète, menu de démarrage F8 peu pertinent).
Remplacement des dizaines de fonctions `Remove-XXX` quasi identiques de l'original par une
fonction générique `Remove-BloatwareApp` paramétrée : moins de duplication, plus simple à
étendre.
Menu interactif à sélection multiple au lieu de commenter/décommenter des lignes à la main.
Journalisation automatique (transcript `.log`) et point de restauration optionnel avant
exécution.
Note sur la fiabilité dans le temps
Les noms de paquets AppX et certaines clés de registre propres à l'interface (Widgets, Copilot,
icône Chat) peuvent changer d'une mise à jour de fonctionnalités à l'autre (24H2 → 25H2 → 26H1...).
Si un tweak semble sans effet, vérifie via `Get-AppxPackage -AllUsers` (pour le nom d'un paquet)
ou l'Éditeur de stratégie de groupe / de registre pour confirmer que la clé existe toujours sous
ce nom sur ta version de build.
