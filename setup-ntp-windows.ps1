# Config du serveur NTP de secours (Windows Server)
# À lancer dans PowerShell en administrateur :
#   Set-ExecutionPolicy -Scope Process Bypass; .\setup-ntp-windows.ps1

$IpDebian = "10.0.3.10"
$Reseau   = "10.0.0.0/16"

# Fuseau horaire : Suisse (Berne, "W. Europe Standard Time" = UTC+1, heure d'été automatique)
Set-TimeZone -Id "W. Europe Standard Time"

# Sources : Debian en priorité, pool irlandais en secours (0x8 = mode client normal)
w32tm /config /manualpeerlist:"$IpDebian,0x8 ie.pool.ntp.org,0xa" /syncfromflags:manual /reliable:yes /update

# Activation du serveur NTP Windows
Set-ItemProperty `
    "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" `
    -Name Enabled -Value 1

# Configuration de l'annonce NTP
Set-ItemProperty `
    "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" `
    -Name AnnounceFlags -Value 5


# Pare-feu : UDP 123 entrant, uniquement pour les machines du réseau $Reseau
# (sans règle, Windows ne répond pas ; toute IP hors du réseau est bloquée par défaut)

# On recrée la règle pour appliquer le réseau à jour
Get-NetFirewallRule -DisplayName "NTP Server UDP 123" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

New-NetFirewallRule `
    -DisplayName "NTP Server UDP 123" `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 123 `
    -Action Allow `
    -Profile Any `
    -RemoteAddress $Reseau | Out-Null

# Pare-feu : autoriser le ping
Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -ErrorAction SilentlyContinue

# Démarrage automatique du service et redémarrage
Set-Service w32time -StartupType Automatic
Restart-Service w32time
Start-Sleep -Seconds 3
w32tm /resync

# Vérification
w32tm /query /source
w32tm /query /status
w32tm /query /peers
