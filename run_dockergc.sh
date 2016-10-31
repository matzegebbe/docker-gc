#!/bin/bash

function sendMail() {
  if [ ! -f "$MAIL_RECIPIENTS" ]; then
      echo "$2" | mutt -s "$1" "snemeth@hu.hellmann.net"
      exit 1;
  fi
  while IFS='' read -r line || [[ -n "$line" ]]; do
    RECIPIENTS+="$line",
  done < $MAIL_RECIPIENTS
  echo "$2" | mutt -s "$1" "$RECIPIENTS"
}

function sendMailFromFile() {
  if [ ! -f "$MAIL_RECIPIENTS" ]; then
      mutt -s "$1" "snemeth@hu.hellmann.net" < $2
      exit 1;
  fi

  while IFS='' read -r line || [[ -n "$line" ]]; do
    RECIPIENTS+="$line",
  done < $MAIL_RECIPIENTS
  mutt -s "$1" "$RECIPIENTS" < $2
}



DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

#PARAMETER VALIDATION
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --exclude-gc)
        DGCEXCLUDE="$2"
        shift
        ;;
        --mail-recipients)
        MAIL_RECIPIENTS="$2"
        shift
        ;;
        --grace-period)
        GRACE_PERIOD_SECONDS="$2"
        shift
        ;;
        --exclude-dead-containers)
        EXCLUDE_DEAD="1"
        ;;
        --dry-run)
        DRY_RUN="1"
        ;;
        *)
        # unknown option
        ;;
    esac
    shift # past argument or value
done

echo PARAMS LISTING...

echo -n "DOCKER GARBAGE COLLECTION EXCLUDE: "
if [ ! -z "$DGCEXCLUDE" ]; then
    echo "${DGCEXCLUDE}"
else
    DGCEXCLUDE="$DIR/docker-gc-exclude-containers"
    echo "$DGCEXCLUDE (default)"
fi

echo -n "MAIL RECIPIENTS FILE: "
if [ ! -z "$MAIL_RECIPIENTS" ]; then
    echo "${MAIL_RECIPIENTS}"
else
    MAIL_RECIPIENTS="$DIR/mail_recipients.txt"
    echo "$MAIL_RECIPIENTS (default)"
fi

echo -n "GRACE PERIOD IN SECONDS: "
if [ ! -z "$GRACE_PERIOD_SECONDS" ]; then
    echo "${GRACE_PERIOD_SECONDS}"
else
    # 1 week
    GRACE_PERIOD_SECONDS=604800
    echo "$GRACE_PERIOD_SECONDS (default)"
fi

echo -n "EXCLUDE DEAD CONTAINERS: "
if [ ! -z "$EXCLUDE_DEAD" ]; then
    echo "${EXCLUDE_DEAD}"
else
    EXCLUDE_DEAD="1";
    echo "$EXCLUDE_DEAD (default)"
fi

echo -n "DRY RUN: "
if [ ! -z "$DRY_RUN" ]; then
    echo "${DRY_RUN}"
else
    DRY_RUN="0";
    echo "$DRY_RUN (default)"
fi


##CHECK FILES EXISTS
if [[ ! -f "$DGCEXCLUDE" ]] || [[ ! -f "$MAIL_RECIPIENTS" ]]; then
    sendMail "Error $HOSTNAME DockerGC" "File DGCEXCLUDE or MAIL_RECIPIENTS is missing"
    exit 1;
fi
#END OF PARAMETER VALIDATION

#PREPARE DOCKER_GC COMMAND
DOCKER_GC_COMMAND="GRACE_PERIOD_SECONDS=$GRACE_PERIOD_SECONDS EXCLUDE_DEAD=$EXCLUDE_DEAD"
if [ $DRY_RUN -eq 1 ]; then
    DOCKER_GC_COMMAND+=" DRY_RUN=$DRY_RUN"
fi
DOCKER_GC_COMMAND+=" ./docker-gc"

DF_BEFORE=`df -h`

RES=`docker run --rm -v $DGCEXCLUDE:/etc/docker-gc-exclude-containers \
-v /var/run/docker.sock:/var/run/docker.sock matzeihn/docker-gc \
bash -c "$DOCKER_GC_COMMAND"`

if [ "$?" -eq 0 ]; then
   DF_AFTER=`df -h`
   MAIL_SUBJECT="$HOSTNAME DockerGC"
   TMP_FILE=/tmp/docker-gc-mail-body.tmp
   > $TMP_FILE
   printf "Command executed: %s\n\n" "$DOCKER_GC_COMMAND" >> $TMP_FILE;
   printf "Disk usage before: \n\n%s\n\n" "$DF_BEFORE" >> $TMP_FILE;
   printf "Disk usage after: \n\n%s\n\n" "$DF_AFTER" >> $TMP_FILE;
   printf "Result of script: \n\n%s" "$RES" >> $TMP_FILE;

   sendMailFromFile "$MAIL_SUBJECT" $TMP_FILE
   exit 0;
else
   sendMail "Error $HOSTNAME DockerGC" $"$RES"
   exit 1;
fi

