#!/bin/bash
set -e

bootstrap() {
	while ! nc -z localhost ${PORT:-8538}; do sleep 0.5; done
	for topic in $TOPICS;do
		echo "Creating topic $topic"
		curl -fsSLX PUT http://localhost:${PORT:-8538}/v1/projects/${PROJECT_ID:-project-id}/topics/$topic
		for sub in $SUB_NAMES; do
			PUSH_ENDPOINT=${sub##*=}
			sub=${sub%%=*}
			[[ "$PUSH_ENDPOINT" == "$sub" ]] && PUSH_ENDPOINT=
			
			curl -fsSLX PUT \
			http://localhost:${PORT:-8538}/v1/projects/${PROJECT_ID:-project-id}/subscriptions/${sub/TOPIC/$topic} \
			-H 'Content-Type: application/json' \
			--data-binary @- <<-JSON
				{
					"topic": "projects/${PROJECT_ID:-project-id}/topics/$topic",
					"ackDeadlineSeconds": ${ACK_DEADLINE:-10},
					"pushConfig": {
						"pushEndpoint": "${PUSH_ENDPOINT}"
					}
				}
			JSON
		done
	done
}

# create topics with two subscriptions each as soon as the emulator is up
bootstrap &

if [[ -z "$@" ]]; then
	[[ ! -d "${DATADIR:-/data}" ]] && mkdir -p "${DATADIR:-/data}"
	exec gcloud beta emulators pubsub start --host-port=0.0.0.0:${PORT:-8538} --data-dir=${DATADIR:-/data} --project=${PROJECT_ID:-project-id}
else
	exec "$@"
fi