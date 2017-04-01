#!/usr/bin/env bats

source ./helpers/bats-support/load.bash
source ./helpers/bats-assert/load.bash
source ./helpers/bats-file/load.bash
source ./helpers/stub.bash

PRISM_RUNNER_SCRIPT="/vagrant/setup/bin/prism-runner/prism-runner.sh"

setup() {
  TEST_TEMP_DIR="$(temp_make)"
}

teardown() {
  temp_del "$TEST_TEMP_DIR"
}

get_job_uuid() {
    line=$(echo "$1" | sed -n "2p")
    echo $(echo $line | cut -c23-)
}

get_args_line() {
    echo $(echo "$1" | sed -n "3p")
}

@test "should have prism-runner.sh" {

    assert_file_exist ${PRISM_RUNNER_SCRIPT}
}

@test "should abort if all the necessary env vars are not configured" {

    unset PRISM_BIN_PATH
    unset PRISM_DATA_PATH
    unset PRISM_INPUT_PATH
    unset PRISM_SINGULARITY_PATH

    run ${PRISM_RUNNER_SCRIPT}

    assert_failure
    assert_line 'Some necessary paths are not correctly configured.'
}

@test "should abort if PRISM_BIN_PATH is not configured" {

    unset PRISM_BIN_PATH
    export PRISM_DATA_PATH="b"
    export PRISM_INPUT_PATH="c"
    export PRISM_SINGULARITY_PATH="d"

    run ${PRISM_RUNNER_SCRIPT}

    assert_failure
    assert_line 'Some necessary paths are not correctly configured.'
}

@test "should abort if PRISM_DATA_PATH is not configured" {

    export PRISM_BIN_PATH="a"
    unset PRISM_DATA_PATH
    export PRISM_INPUT_PATH="c"
    export PRISM_SINGULARITY_PATH="d"

    run ${PRISM_RUNNER_SCRIPT}

    assert_failure
    assert_line 'Some necessary paths are not correctly configured.'
}

@test "should abort if PRISM_INPUT_PATH is not configured" {

    export PRISM_BIN_PATH="a"
    export PRISM_DATA_PATH="b"
    unset PRISM_INPUT_PATH
    export PRISM_SINGULARITY_PATH="d"

    run ${PRISM_RUNNER_SCRIPT}

    assert_failure
    assert_line 'Some necessary paths are not correctly configured.'
}

@test "should abort if PRISM_SINGULARITY_PATH is not configured" {

    export PRISM_BIN_PATH="a"
    export PRISM_DATA_PATH="b"
    export PRISM_INPUT_PATH="c"
    unset PRISM_SINGULARITY_PATH

    run ${PRISM_RUNNER_SCRIPT}

    assert_failure
    assert_line 'Some necessary paths are not correctly configured.'
}

@test "should abort if workflow or input filename is not supplied" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    run ${PRISM_RUNNER_SCRIPT}

    assert_failure
    assert_line --index 0 --partial 'USAGE:'
}

@test "should abort if input file doesn't exit" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i test.yaml

    assert_failure
    assert_line --index 0 --partial 'not found'
}

@test "should abort if batch system is not specified with -b" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    echo "test input" > ${TEST_TEMP_DIR}/test.yaml

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${TEST_TEMP_DIR}/test.yaml

    assert_failure
    assert_line --index 0 --partial 'USAGE:'
}

@test "should abort if unknown batch system is supplied via -b" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    echo "test input" > ${TEST_TEMP_DIR}/test.yaml

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${TEST_TEMP_DIR}/test.yaml -b xyz

    assert_failure
    assert_line --index 0 --partial 'USAGE:'
}

@test "should abort if mesos is selected for batch system" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    echo "test input" > ${TEST_TEMP_DIR}/test.yaml

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${TEST_TEMP_DIR}/test.yaml -b mesos

    assert_failure
    assert_line --index 0 --partial 'Unsupported'
}

@test "should output job UUID at the beginning and the end" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    echo "test input" > ${TEST_TEMP_DIR}/test.yaml

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${TEST_TEMP_DIR}/test.yaml -b lsf

    assert_success

    # PRISM JOB UUID = 11af6ef4-1682-11e7-8e2c-02e45b1a6ece
    assert_line --index 0 --regexp 'JOB UUID = [a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}'
    assert_line --index 2 --regexp 'JOB UUID = [a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}'

    # get job UUID
    job_uuid=$(get_job_uuid "$output")

    # check the content of job_uuid file
    assert_equal "${job_uuid}" `cat ./outputs/job-uuid`

    unstubs
}

@test "should correctly construct the parameters when calling cwltoil" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    input_filename="${TEST_TEMP_DIR}/test.yaml"
    echo "test input" > ${input_filename}

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    workflow_filename='abc.cwl'
    
    run ${PRISM_RUNNER_SCRIPT} -w ${workflow_filename} -i ${input_filename} -b lsf

    assert_success

    # get job UUID
    job_uuid=$(get_job_uuid "$output")

    # parse argument lines
    args_line=$(get_args_line "$output")
    read -r -a args <<< "$args_line"

    # check workflow filename (pos arg 0)
    assert_equal "${args[0]}" "${PRISM_BIN_PATH}/pipeline/${PRISM_VERSION}/${workflow_filename}"

    # check input filename (pos arg 1)    
    assert_equal "${args[1]}" "${input_filename}"

    # check --jobStore
    assert_line --index 1 --partial "--jobStore file://${PRISM_BIN_PATH}/tmp/jobstore-${job_uuid}"

    # check --preserve-environment
    assert_line --index 1 --partial "--preserve-environment PATH PRISM_DATA_PATH PRISM_BIN_PATH PRISM_INPUT_PATH PRISM_SINGULARITY_PATH"

    # check --no-container
    assert_line --index 1 --partial "--no-container"

    # check --disableCaching
    assert_line --index 1 --partial "--disableCaching"

    # check --realTimeLogging
    assert_line --index 1 --partial "--realTimeLogging"

    # check --realTimeLogging
    assert_line --index 1 --partial "--realTimeLogging"

    # check --workDir
    assert_line --index 1 --partial "--workDir ${PRISM_BIN_PATH}/tmp"

    # check debug-related
    assert_line --index 1 --partial "--logDebug --cleanWorkDir never"

    # /vagrant/test/mock/bin/pipeline/1.0.0/abc.cwl
    # /tmp/prism-runner.bats-12-7uktFHNZ4w/test.yaml
    # --jobStore file:///vagrant/test/mock/bin/tmp/jobstore-78377068-1682-11e7-8e2c-02e45b1a6ece
    # --defaultDisk 10G
    # --preserve-environment PATH PRISM_DATA_PATH PRISM_BIN_PATH PRISM_INPUT_PATH PRISM_SINGULARITY_PATH CMSOURCE_CONFIG
    # --no-container
    # --disableCaching
    # --realTimeLogging
    # --writeLogs /vagrant/test/outputs/log
    # --logFile /vagrant/test/outputs/log/cwltoil.log
    # --workDir /vagrant/test/mock/bin/tmp
    # --outdir: /vagrant/test/outputs
    # --batchSystem lsf
    # --stats
    # --logDebug
    # --cleanWorkDir never

    unstubs
}

@test "should correctly construct the parameters when calling cwltoil for lsf" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    input_filename="${TEST_TEMP_DIR}/test.yaml"
    echo "test input" > ${input_filename}

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${input_filename} -b lsf

    assert_success

    # check lsf-related
    assert_line --index 1 --partial "--batchSystem lsf --stats"

    unstubs
}

@test "should correctly construct the parameters when calling cwltoil for singleMachine" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    input_filename="${TEST_TEMP_DIR}/test.yaml"
    echo "test input" > ${input_filename}

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${input_filename} -b singleMachine

    assert_success

    # check lsf-related
    assert_line --index 1 --partial "--batchSystem singleMachine"

    unstubs
}

@test "should correctly handle -o (output directory) parameter when calling cwltoil" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    input_filename="${TEST_TEMP_DIR}/test.yaml"
    echo "test input" > ${input_filename}

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    # clean up previously created
    rm -rf ./outputs
    rm -rf ./outputs/log
    
    # call prism runner without -o
    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${input_filename} -b singleMachine

    assert_success

    # check whether outputs and outputs/log directories are created
    assert_file_exist ./outputs
    assert_file_exist ./outputs/log

    # check the job-uuid file is created in the correct location
    assert_file_exist ./outputs/job-uuid

    # check --writeLogs
    assert_line --index 1 --partial "--writeLogs /vagrant/test/outputs/log"

    # check --logFile
    assert_line --index 1 --partial "--logFile /vagrant/test/outputs/log/cwltoil.log"

    # check --outdir
    assert_line --index 1 --partial "--outdir /vagrant/test/outputs"

    # call prism runner with -o
    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${input_filename} -b singleMachine -o ${TEST_TEMP_DIR}

    assert_success

    # check whether outputs and outputs/log directories are created
    assert_file_exist ${TEST_TEMP_DIR}
    assert_file_exist ${TEST_TEMP_DIR}/log

    # check the job-uuid file is created in the correct location
    assert_file_exist ${TEST_TEMP_DIR}/job-uuid

    # check --outdir
    assert_line --index 1 --partial "--outdir ${TEST_TEMP_DIR}"

    # check --writeLogs
    assert_line --index 1 --partial "--writeLogs ${TEST_TEMP_DIR}/log"

    # check --logFile
    assert_line --index 1 --partial "--logFile ${TEST_TEMP_DIR}/log/cwltoil.log"

    unstubs
}

@test "should correctly handle -v (pipeline version) parameter when calling cwltoil" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    input_filename="${TEST_TEMP_DIR}/test.yaml"
    echo "test input" > ${input_filename}

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    pipeline_version='2.0.1'
    workflow_filename='abc.cwl'
    
    run ${PRISM_RUNNER_SCRIPT} -v ${pipeline_version} -w ${workflow_filename} -i ${input_filename} -b lsf

    assert_success

    # get job UUID
    job_uuid=$(get_job_uuid "$output")

    # parse argument lines
    args_line=$(get_args_line "$output")
    read -r -a args <<< "$args_line"

    # check workflow filename (pos arg 0)
    assert_equal "${args[0]}" "${PRISM_BIN_PATH}/pipeline/${pipeline_version}/${workflow_filename}"

    unstubs
}

@test "should set CMO_RESOURCE_CONFIG correctly before run, unset after run" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    input_filename="${TEST_TEMP_DIR}/test.yaml"
    echo "test input" > ${input_filename}

    # stub cwltoil to print the value of CMO_RESOURCE_CONFIG
    stub cwltoil 'printenv CMO_RESOURCE_CONFIG'
   
    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${input_filename} -b singleMachine

    assert_success
    
    assert_line --index 1 "${PRISM_BIN_PATH}/pipeline/${PRISM_VERSION}/prism_resources.json"

    assert_equal `printenv CMO_RESOURCE_CONFIG` ''
}

@test "should correctly handle -r (restart) parameter when calling cwltoil" {

    # this will load PRISM_BIN_PATH, PRISM_DATA_PATH, and PRISM_INPUT_PATH
    source ./settings.sh

    export PRISM_SINGULARITY_PATH=`which singularity`

    # create fake input file
    echo "test input" > ${TEST_TEMP_DIR}/test.yaml

    # stub cwltoil to echo out whatever the parameters supplied
    stub cwltoil 'echo "$@"'

    run ${PRISM_RUNNER_SCRIPT} -w abc.cwl -i ${TEST_TEMP_DIR}/test.yaml -b singleMachine -r some-uuid

    assert_success

    # check uuid at the beginning and the end of the output
    assert_line --index 0 --partial 'JOB UUID = some-uuid'
    assert_line --index 2 --partial 'JOB UUID = some-uuid'

    # check --jobStore
    assert_line --index 1 --partial "--jobStore file://${PRISM_BIN_PATH}/tmp/jobstore-some-uuid"

    # check --restart
    assert_line --index 1 --partial "--restart"

    # check the content of job_uuid file
    assert_equal "some-uuid" `cat ./outputs/job-uuid`

    unstubs
}