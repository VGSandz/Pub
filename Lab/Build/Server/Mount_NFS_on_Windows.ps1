###########################################################################
# AUTHOR  : 
# DATE    : 
# EDIT    :  
# COMMENT : This script mounts NFS Volume for all users.
#           The script runs as NT Authority\SYSTEM.
#           Source : https://learn.microsoft.com/en-us/archive/blogs/technet/sfu/accessing-nfs-shares-through-an-application
# VERSION : 1.00 
# NOTE    : May be limitations from Microsoft and limited support options which have to be evaluated if this has to be on Production Systems.
#           The drive appears disconnected, but would be accessible.
#           To Delete use "net use X: /delete" or Remove-PSDrive
###########################################################################

# Mount the NFS drive to all users.

#Replace the Drive letter "X:" to the correct Drive letter and the Root to NFS path.
New-PSDrive -PSProvider FileSystem -Name X -Root "\\<IP_Address>\test_vol" -Persist -Scope Global


