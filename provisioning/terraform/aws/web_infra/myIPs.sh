#!/bin/bash
echo "My IP Address: `dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"'`" 
echo "IPv4: `curl -s -4 ifconfig.co`"
echo "IPv6: `curl -s -6 ifconfig.co`"
