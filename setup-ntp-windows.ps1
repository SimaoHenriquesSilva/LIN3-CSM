# Config du serveur NTP de secours (Windows Server)
# À lancer dans PowerShell en administrateur :
#   Set-ExecutionPolicy -Scope Process Bypass; .\setup-ntp-windows.ps1

$IpDebian = "10.0.3.10"
$Reseau   = "10.0.0.0/16"

# Sources : Debian en priorité, pool suisse en secours (0x8 = mode client normal)
w32tm /config /manualpeerlist:"$IpDebian,0x8 ch.pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update

# Active le serveur NTP de Windows (Enabled = 1) : sans ça, Windows ne répond pas aux requêtes des clients
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" -Name Enabled -Value 1
# AnnounceFlags = 5 : Windows s'annonce comme source de temps fiable (1 = toujours annoncé, 4 = temps fiable)
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name AnnounceFlags -Value 5


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
