#!/bin/bash
set -e

log() {
	if [[ -z $QUIET ]]; then
		echo "$@"
	fi
}

createTopic() {
	local topic=$1
	log "Creating topic ${topic:?}"
	curl ${QUIET:+-o /dev/null} -fsSLX PUT http://localhost:${PORT:-8538}/v1/projects/${PROJECT_ID:-project-id}/topics/${topic:?}
}

createSubscription() {
	local topic=$1
	local subscription=${2/TOPIC/${topic:?}}
	local pushEndpoint=$3
	local ackDeadline=$4
	log "Creating subscription ${topic:?}/${subscription:?}"
	curl ${QUIET:+-o /dev/null} -fsSLX PUT \
	http://localhost:${PORT:-8538}/v1/projects/${PROJECT_ID:-project-id}/subscriptions/${subscription:?} \
	-H 'Content-Type: application/json' \
	--data-binary @- <<-JSON
		{
			"topic": "projects/${PROJECT_ID:-project-id}/topics/${topic:?}",
			"ackDeadlineSeconds": ${ackDeadline:-${ACK_DEADLINE:-10}},
			"pushConfig": {
				"pushEndpoint": "${pushEndpoint}"
			}
		}
	JSON
}

bootstrap() {
	while ! nc -z localhost ${PORT:-8538}; do sleep 0.5; done
	for topic in $TOPICS;do
		createTopic "$topic"
		for sub in $SUB_NAMES; do
			pushEndpoint=${sub##*=}
			sub=${sub%%=*}
			[[ "$pushEndpoint" == "$sub" ]] && pushEndpoint=
			createSubscription "$topic" "$sub" "$pushEndpoint"
		done
	done

	if [[ -f "$CONFIG_FILE" ]]; then
		for topic in `yq '.topics | keys | join(" ")' $CONFIG_FILE`; do
			createTopic "$topic"
			count=`yq ".topics.${topic} | length" $CONFIG_FILE`
			if [[ $count -eq 0 ]]; then
				subNames=$topic
			else
				subNames=`yq ".topics.${topic} | keys | join(\" \")" $CONFIG_FILE`
			fi
			for sub in $subNames; do
				count=`yq ".topics.${topic}.${sub} | length" $CONFIG_FILE`
				type=`yq ".topics.${topic}.${sub} | type" $CONFIG_FILE`
				if [[ $count -gt 0 && $type == "!!map" ]]; then
					pushEndpoint=`yq ".topics.${topic}.${sub}.pushEndpoint // \"\"" $CONFIG_FILE`
					ackDeadline=` yq ".topics.${topic}.${sub}.ackDeadline  // \"\"" $CONFIG_FILE`
				fi
				createSubscription "$topic" "$sub" "$pushEndpoint" "$ackDeadline"
			done
		done
	fi
}

# create topics with two subscriptions each as soon as the emulator is up
bootstrap &

if [[ -z "$@" ]]; then
	[[ ! -d "${DATADIR:-/data}" ]] && mkdir -p "${DATADIR:-/data}"
	exec gcloud beta emulators pubsub start --host-port=0.0.0.0:${PORT:-8538} --data-dir=${DATADIR:-/data} --project=${PROJECT_ID:-project-id} --verbosity=${VERBOSITY:-warning} ${QUIET:+--quiet}
else
	exec "$@"
fi