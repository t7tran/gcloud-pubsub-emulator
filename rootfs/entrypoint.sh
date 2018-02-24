#!/bin/bash
set -e

# create topics with two subscriptions each as soon as the emulator is up
while ! nc -z localhost 8538; do sleep 0.5; done && \
for topic in $TOPICS;do \
  echo "Creating topic $topic"; \
  curl -fsSLX PUT http://localhost:8538/v1/projects/$PROJECT_ID/topics/$topic; \
  for sub in $SUB_NAME $SUB_NAME2;do \
    curl -fsSLX PUT \
      http://localhost:8538/v1/projects/$PROJECT_ID/subscriptions/${sub/TOPIC/$topic} \
      -H 'Content-Type: application/json' \
      -d "{\"topic\":\"projects/$PROJECT_ID/topics/$topic\",\"ackDeadlineSeconds\":$ACK_DEADLINE}"; \
  done \
done &

exec "$@"