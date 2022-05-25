
##############################################
# This script will be executed after ADDS domain setup and restarted
# to continue configure reverse DNS lookup to support SQLMI AD authentication
##############################################
# Setup reverse lookup zone
Add-DnsServerPrimaryZone -NetworkId "172.16.1.0/24" -ReplicationScope Domain -DomainNetbiosName "contoso"
