get-process ServerManager | stop-process –force

if(-not (Test-Path "$env:APPDATA\Microsoft\Windows\ServerManager")) {
    New-Item -Path "$env:APPDATA\Microsoft\Windows\ServerManager" -ItemType Directory
}
Copy-Item "C:\ServerManagerConfig\ServerList.xml" -Destination "$env:APPDATA\Microsoft\Windows\ServerManager\ServerList.xml" -Force -Confirm:$false

start-process –filepath $env:SystemRoot\System32\ServerManager.exe –WindowStyle Maximized