Rem This would proxy the current system to a remote system.
Rem What we can achieve here is to put this server in the middle between an IDP and client and have wireshark capture the traffic.

netsh interface portproxy add v4tov4 listenport= listenaddress= connectport= connectaddress=
netsh interface portproxy delete v4tov4 listenport= listenaddress=
netsh interface portproxy add v4tov4 listenport= listenaddress= connectport= connectaddress=
netsh interface portproxy add v4tov4 listenport= listenaddress= connectport= connectaddress=
netsh interface portproxy delete v4tov4 listenport= listenaddress=
netsh interface portproxy delete v4tov4 listenport= listenaddress=
netsh interface portproxy show all
