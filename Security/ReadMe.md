> [!WARNING]
> Documenting for my LAB enviroment setup not a live case.


**Step 1:
Installation of Bloodhound and setting up neo4j console.**

> Using latest Kali Linux version for the setup.

## Install Bloodhound
```bash
sudo apt update && sudo apt install -y bloodhound
```

Installation completion, Note the versions may differ on newer release.

![image](https://github.com/VGSandz/Pub/assets/64747937/5c6ae0c0-6c5c-42be-b8fd-473c8f4da6d3)

Start Neo4j console
```bash
sudo neo4j console
```
Neo4j Successfully started.

![image](https://github.com/VGSandz/Pub/assets/64747937/4371e37d-8502-46ef-858d-2a48ca76ba91)

Neo4j console login

![image](https://github.com/VGSandz/Pub/assets/64747937/2b0d3576-a913-475f-9c7a-991728a89317)

Default credentials.<br/>
username: neo4j<br/>
password: neo4j

Change password.

![neo4j-change-password](https://github.com/VGSandz/Pub/assets/64747937/60398344-c021-4a4a-9a07-e7d352a6b011)

Start bloodhound
```bash
sudo bloodhound
```

![image](https://github.com/VGSandz/Pub/assets/64747937/6c5b5b6c-29ed-4339-be2b-66d9219a0782)

Provide the neo4j credentials.

![image](https://github.com/VGSandz/Pub/assets/64747937/18a398fb-86a8-49b7-90b6-3d280831249a)


**Step 2:
Gathering the Active Directory inventory data with Bloodhound collectors.**

## Bloodhound collectors Source 

https://github.com/BloodHoundAD/BloodHound/tree/master/Collectors

Download Sharphound.exe

![image](https://github.com/VGSandz/Pub/assets/64747937/d746ab39-ebec-4bbe-9c21-283766383e27)

Note: It may be flagged as a virus or malware.

Collect the data using references at [https://bloodhound.readthedocs.io/en/latest/data-collection/sharphound.html](url)

> SharpHound can run with no paramters set and stores the data in the same path from where it is called.

```cmd
C:\> SharpHound.exe
```

Running the SharpHound in default mode on Windows Domain Joined server.

![image](https://github.com/VGSandz/Pub/assets/64747937/e6bba858-e15d-40e8-8885-f33d525600c1)

Export the logs from Windows Server to Kali Linux where we have the bloodhound installed.


**Step 3:
Import the AD Data into BloodHound.**

Proceed with the next steps **only** if the Windows server and the Kali Server are on the same network with necessary ports opened for share. 

### On Windows server where we have SharpHound results.
1. Create a windows share and provide necessary permissions on the folder. 
1. Copy the SharpHound results into the share folder.

### On Kali Linux to access the share.

Create a folder to mount.
```bash
mkdir /mnt/winshare
```

Install the cifs utils on Kali.

```bash
sudo apt install cifs-utils
```
Mount the share.

```bash
sudo mount -t cifs //<WindowsServer IP or Hostname>/Share /mnt/winshare -o username=Administrator@<domain-name>
```

Once the share is mounted, import the Zip file into BloodHound console.
