# Config du serveur NTP de secours (Windows Server)
# À lancer dans PowerShell en administrateur :
#   Set-ExecutionPolicy -Scope Process Bypass; .\setup-ntp-windows.ps1

$IpDebian = "10.229.38.170"
$Reseau   = "10.229.0.0/16"

# Sources : Debian en priorité, pool suisse en secours (0x8 = mode client normal)
w32tm /config /manualpeerlist:"$IpDebian,0x8 ch.pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update

# Activer le serveur NTP et l'annonce
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" -Name Enabled -Value 1
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name AnnounceFlags -Value 5

# Interrogation toutes les 5 minutes
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name SpecialPollInterval -Value 300

# Pare-feu : UDP 123 entrant (sans ça, Windows ne répond pas aux clients)
if (-not (Get-NetFirewallRule -DisplayName "NTP Server UDP 123" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "NTP Server UDP 123" -Direction Inbound -Protocol UDP -LocalPort 123 -Action Allow -Profile Any -RemoteAddress $Reseau | Out-Null
}

# Démarrage automatique du service et redémarrage
Set-Service w32time -StartupType Automatic
Restart-Service w32time
Start-Sleep -Seconds 3
w32tm /resync

# Vérification
w32tm /query /source
w32tm /query /status
