netsh wlan set hostednetwork mode=allow ssid=MyWifi_2 key=password keyUsage=persistent
netsh wlan start hostednetwork
@echo off
echo Press any key to abort
pause 2>&1 > nul