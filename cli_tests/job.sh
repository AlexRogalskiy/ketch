#!/usr/bin/env bats

# To run locally:
# export KETCH_EXECUTABLE_PATH=<location of ketch binary>
# assure you have a kubernetes cluster running w/ traefik, cert manager, etc. (see ketch getting started docs)
# assure the ketch cli is compiled (make ketch)
# assure you have bats installed locally (via apt, brew, etc.)
# ./cli_tests/app.sh

setup() {
    if [[ -z "${KETCH_EXECUTABLE_PATH}" ]]; then
    KETCH=$(pwd)/bin/ketch
  else
    KETCH="${KETCH_EXECUTABLE_PATH}"
  fi

  JOB_FRAMEWORK="jobframework"
  JOB_NAME="sample-job"
}

teardown() {
  rm -f job.yaml
}

@test "job help" {
  result="$($KETCH job --help)"
  echo "RECEIVED:" $result
  [[ $result =~ "deploy" ]]
  [[ $result =~ "list" ]]
  [[ $result =~ "export" ]]
  [[ $result =~ "remove" ]]
}

@test "job deploy with yaml file" {
  fwresult=$($KETCH framework add "$JOB_FRAMEWORK")
  echo "RECEIVED:" $fwresult
  [[ $fwresult =~ "Successfully added!" ]]
  sleep 2 # sometimes framework can take a moment to associate to a namespace

  cat << EOF > job.yaml
name: "$JOB_NAME"
version: v1
type: Job
framework: "$JOB_FRAMEWORK"
description: "cli test job"
containers:
  - name: pi
    image: perl
    command:
      - "perl"
      - "-Mbignum=bpi"
      - "-wle"
      - "print bpi(2000)"
parallelism: 2
EOF
  result=$($KETCH job deploy job.yaml)
  [[ $result =~ "Successfully added!" ]]

  dataRegex="$JOB_NAME[ \t]+v1[ \t]+$JOB_FRAMEWORK[ \t]+cli test job"
  result=$($KETCH job list $JOB_NAME)
  echo "RECEIVED:" $result
  [[ $result =~ $dataRegex ]]
}

@test "job list" {
  result=$($KETCH job list)
  headerRegex="NAME[ \t]+VERSION[ \t]+FRAMEWORK[ \t]+DESCRIPTION"
  dataRegex="$JOB_NAME[ \t]+v1[ \t]+$JOB_FRAMEWORK[ \t]+cli test job"
  echo "RECEIVED:" $result
  [[ $result =~ $headerRegex ]]
  [[ $result =~ $dataRegex ]]
}

@test "job export" {
  run $KETCH job export "$JOB_NAME" -f job.yaml
  result=$(cat job.yaml)
  echo "RECEIVED:" $result
  [[ $result =~ "name: $JOB_NAME" ]]
  [[ $result =~ "type: Job" ]]
  [[ $result =~ "framework: $JOB_FRAMEWORK" ]]
}

@test "job completions" {
  # completions should default to parallelism, if unset

  # retry for job
  count=0
  until [[ $count -ge 5 ]]
  do
    # result=$(kubectl get job -n "ketch-$JOB_FRAMEWORK")
    result=$(kubectl describe job "$JOB_NAME" -n "ketch-$JOB_FRAMEWORK" || echo false)
    completionsRegex="Completions: *2" # variable spaces
    if [[ $result =~ $completionsRegex ]]
    # if [[ $result =~ "/2" ]]
      then break
    fi
    count+=1
    sleep 7
  done

  # res=$(kubectl get job "$JOB_NAME" -n "ketch-$JOB_FRAMEWORK")
  # [[ $res =~ "/2" ]]

  # result=$(kubectl get job "$JOB_NAME" -n "ketch-$JOB_FRAMEWORK")
  # completionsRegex="[0-2]/2" # completions probably won't be finished - may be 0/2 or 1/2
  # echo "RECEIVED:" $result
  # [[ $result =~ $completionsRegex ]]
  #
  result=$(kubectl describe job "$JOB_NAME" -n "ketch-$JOB_FRAMEWORK")
  completionsRegex="Completions: *2" # variable spaces
  parallelismRegex="Parallelism: *2" # variable spaces
  echo "RECEIVED:" $result
  [[ $result =~ $completionsRegex ]]
  [[ $result =~ $parallelismRegex ]]
}

@test "job remove" {
  result=$($KETCH job remove "$JOB_NAME")
  echo "RECEIVED:" $result
  [[ $result =~ "Successfully removed!" ]]

  # clean up framework
  fwresult=$(echo "ketch-$JOB_FRAMEWORK" | $KETCH framework remove "$JOB_FRAMEWORK")
  echo "RECEIVED:" $fwresult
  [[ $fwresult =~ "Framework successfully removed!" ]]
}
