#! /bin/bash

DOMAIN_NAME="mathservice.apps.cechols.com"
NUM_CALLS=2500
PAUSE_SECONDS=3

echo "Calling add enpoint on $DOMAIN_NAME $NUM_CALLS times with a pause of $PAUSE_SECONDS seconds."

COUNTER=0
for i in {1..$NUM_CALLS}; do
  COUNTER=$(($COUNTER + 1))
  RANDOM_1=$((RANDOM % 100 - 50))
  RANDOM_2=$((RANDOM % 100 - 50))

  RESULT=$(curl -s "https://$DOMAIN_NAME/add?op1=$RANDOM_1&op2=$RANDOM_2")

  if [ "$?" != 0 ]; then
    echo "CALL $COUNTER failed!"
    exit 1
  fi

  echo "CALL #$COUNTER): $RESULT"

  sleep $PAUSE_SECONDS
done
