<powershell>
# ---------------------------------------------------------------------------
# Windows privilege-escalation lab endpoint - Wazuh agent bootstrap
#
# Provisions ONLY what the blog post lists under "Infrastructure":
#   - a Windows endpoint with the Wazuh agent installed and enrolled
#
# Deliberately NOT done here, because they are documented test steps the
# tester performs by hand:
#   - Sysmon download / config extension / install
#   - the <localfile> block for Microsoft-Windows-Sysmon/Operational
#   - the windows_privesc.xml custom rules
#   - creating the "stduser" standard account
#
# NOTE ON TEMPLATING: this file is rendered by Terraform templatefile(), so
# a literal "$${" or "%%{" would be consumed as a template directive. Keep
# PowerShell to bare $var / $obj.Prop forms and no here-strings - an indented
# here-string terminator inside a Terraform heredoc silently truncates the
# whole script with no error anywhere.
# ---------------------------------------------------------------------------

# --- TTL self-termination: FIRST action, so a later failure still expires ---
${windows_ttl_command}

Start-Transcript -Path "C:\wazuh-bootstrap.log" -Append
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$manager = "${wazuh_server_ip}"
$agentVersion = "${wazuh_version}"
$msiUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$agentVersion-1.msi"
$msiPath = "C:\Windows\Temp\wazuh-agent.msi"

# --- Remote access -------------------------------------------------------
# RDP is the path the blog post needs: several simulation steps require an
# interactive sign-in as the standard user. WinRM over HTTPS is added as a
# scriptable alternative (plain 5985 stays closed).
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation "Cert:\LocalMachine\My"
    New-Item -Path "WSMan:\localhost\Listener" -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force
    Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $true
    New-NetFirewallRule -DisplayName "WinRM HTTPS 5986" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow
} catch {
    Write-Output "WinRM HTTPS setup failed (non-fatal): $($_.Exception.Message)"
}

# --- Wait for the manager's enrollment service ---------------------------
# The Wazuh server installs for ~10-15 min after boot. Installing the agent
# before authd is listening on 1515 leaves it stuck "Requesting a key from
# server" forever, so gate on the port rather than on a fixed sleep.
$enrollmentReady = $false
foreach ($attempt in 1..60) {
    $probe = Test-NetConnection -ComputerName $manager -Port 1515 -WarningAction SilentlyContinue
    if ($probe.TcpTestSucceeded) {
        Write-Output "Manager authd reachable on $manager`:1515 after $attempt attempt(s)"
        $enrollmentReady = $true
        break
    }
    Start-Sleep -Seconds 30
}
if (-not $enrollmentReady) {
    Write-Output "WARNING: manager 1515 never became reachable; installing anyway"
}

# --- Install the Wazuh agent ---------------------------------------------
Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
$msiArgs = @(
    "/i", $msiPath, "/qn", "/l*v", "C:\Windows\Temp\wazuh-agent-install.log",
    "WAZUH_MANAGER=$manager",
    "WAZUH_REGISTRATION_SERVER=$manager",
    "WAZUH_AGENT_NAME=${agent_name}"
)
Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -NoNewWindow

Start-Sleep -Seconds 10
Start-Service -Name WazuhSvc -ErrorAction SilentlyContinue

# --- Verify enrollment, and self-heal once if the key never arrived -------
# client.keys stays empty when the MSI ran before authd was ready. agent-auth
# re-runs enrollment on demand; a service restart alone would not.
$keyFile = "C:\Program Files (x86)\ossec-agent\client.keys"
Start-Sleep -Seconds 20
$enrolled = (Test-Path $keyFile) -and ((Get-Item $keyFile).Length -gt 0)
if (-not $enrolled) {
    Write-Output "client.keys empty - retrying enrollment with agent-auth.exe"
    Stop-Service -Name WazuhSvc -ErrorAction SilentlyContinue
    & "C:\Program Files (x86)\ossec-agent\agent-auth.exe" -m $manager -A "${agent_name}"
    Start-Sleep -Seconds 5
    Start-Service -Name WazuhSvc -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 20
    $enrolled = (Test-Path $keyFile) -and ((Get-Item $keyFile).Length -gt 0)
}

# --- Readiness marker ----------------------------------------------------
$svc = Get-Service -Name WazuhSvc -ErrorAction SilentlyContinue
$report = @(
    "WAZUH_AGENT_BOOTSTRAP_COMPLETE=$(Get-Date -Format o)",
    "WAZUH_VERSION=$agentVersion",
    "WAZUH_MANAGER=$manager",
    "SERVICE_STATUS=$($svc.Status)",
    "ENROLLED=$enrolled"
)
Set-Content -Path "C:\WAZUH_READY.txt" -Value $report -Encoding UTF8
Get-Content "C:\WAZUH_READY.txt"

Stop-Transcript
</powershell>
<persist>true</persist>
