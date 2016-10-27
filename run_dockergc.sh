#!/bin/bash

function sendMail() {
  if [ ! -f "$MAIL_RECIPIENTS" ]; then
      echo "$2" | mutt -s "$1" "portal-orga@hellmann.net"
      exit 1;
  fi
  while IFS='' read -r line || [[ -n "$line" ]]; do
    RECIPIENTS+="$line",
  done < $MAIL_RECIPIENTS
  echo "$2" | mutt -s "$1" "$RECIPIENTS"
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

DGCEXCLUDE="$1"
MAIL_RECIPIENTS="$2"
GRACE_PERIOD_SECONDS="$3"
EXCLUDE_DEAD="$4"

if [ -z "$DGCEXCLUDE" ]; then
    DGCEXCLUDE="$DIR/docker-gc-exclude-containers"
fi

if [ -z "$MAIL_RECIPIENTS" ]; then
    MAIL_RECIPIENTS="$DIR/mail_recipients.txt"
fi

if [ -z "$GRACE_PERIOD_SECONDS" ]; then
    # 1 week
    GRACE_PERIOD_SECONDS=604800
fi

if [ -z "$EXCLUDE_DEAD" ]; then
    EXCLUDE_DEAD="1";
fi

if [[ ! -f "$DGCEXCLUDE" ]] || [[ ! -f "$MAIL_RECIPIENTS" ]]; then
    sendMail "Error $HOSTNAME DockerGC" "File DGCEXCLUDE or MAIL_RECIPIENTS is missing"  
    exit 1;
fi

DF_BEFORE=`df -h`

RES=`docker run --rm -v $DGCEXCLUDE:/etc/docker-gc-exclude-containers \
-v /var/run/docker.sock:/var/run/docker.sock matzeihn/docker-gc \
bash -c "GRACE_PERIOD_SECONDS=$GRACE_PERIOD_SECONDS EXCLUDE_DEAD=$EXCLUDE_DEAD DRY_RUN=1 ./docker-gc"`

if [ "$?" -eq 0 ]; then
   DF_AFTER=`df -h`
   sendMail "$HOSTNAME DockerGC" "Disk usage before:"$'\n\n'"$DF_BEFORE"$'\n\n'"Disk usage after:"$'\n\n'"$DF_AFTER"$'\n\n'"Result of script:"$'\n\n'"$RES"
   exit 0;
else
   sendMail "Error $HOSTNAME DockerGC" $"$RES"  
   exit 1;
fi
