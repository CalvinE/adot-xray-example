#! /bin/bash

DOMAIN_NAME="${DOMAIN:-mathservice.apps.cechols.com}"
NUM_CALLS=${CALL_ITERATIONS:-500}
PAUSE_SECONDS=${WAIT_SECONDS:-5}

echo "Calling add enpoint on $DOMAIN_NAME $NUM_CALLS times with a pause of $PAUSE_SECONDS seconds."

for i in $(seq -s " " $NUM_CALLS); do
  RANDOM_1=$((RANDOM % 100 - 50))
  RANDOM_2=$((RANDOM % 100 - 50))

  RESULT=$(curl -s "https://$DOMAIN_NAME/add?op1=$RANDOM_1&op2=$RANDOM_2")

  if [ "$?" != 0 ]; then
    echo "CALL #$i failed!"
    exit 1
  fi

  echo "CALL #$i: $RESULT"

  sleep $PAUSE_SECONDS
done
