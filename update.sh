#!/bin/bash
COMMENT="Auto updating @ `date`"

# Change to AAAA if using an IPv6 address
TYPE="A"

# Get the external IP address from OpenDNS (more reliable than other providers)
REAL_IP=`dig +short myip.opendns.com @resolver1.opendns.com`
RECORD_IP=`dig +short $RECORDSET`

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

if ! valid_ip $REAL_IP; then
    echo "Invalid IP address: $REAL_IP"
    exit 1
fi

if [ "$REAL_IP" == "$RECORD_IP" ]
then
  echo "IP is still $REAL_IP. Exiting"
  exit 0
fi

echo "IP has changed to $REAL_IP"
# Fill a temp file with valid JSON
TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
cat > ${TMPFILE} << EOF
{
  "Comment":"$COMMENT",
  "Changes":[
    {
      "Action":"UPSERT",
      "ResourceRecordSet":{
        "ResourceRecords":[
          {
            "Value":"$REAL_IP"
          }
        ],
        "Name":"$RECORDSET",
        "Type":"$TYPE",
        "TTL":$TTL
      }
    }
  ]
}
EOF

set -x

cat $TMPFILE

# Update the Hosted Zone record
aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONEID \
    --change-batch file://"$TMPFILE"

# Clean up
rm $TMPFILE
