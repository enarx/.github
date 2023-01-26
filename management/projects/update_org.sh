#!/bin/bash

# Top level command to process issues and prs in an org
# process_org.sh <org> [repos to skip]

echo "$0 $@"


# Assign arguments 
ORG="${1}"
SKIPLIST="${2}"

function check_rate_limit() {
    val=`gh api   -H "Accept: application/vnd.github+json" \
         /rate_limit --jq='.resources.graphql | 
         .remaining, .reset' | tr '\n' ' '`
    rem=$(( `echo "${val}" | awk '{ print $1 }'` ))
    reset=$(( `echo "${val}" | awk '{ print $2 }'` ))
    echo "Remaining: ${rem}"
    echo "Time of reset: ${reset}"
    if [[ "${rem}" -lt "2000" ]]; then
        pause=$(( ${reset} - $(date +%s) + 60 ))
        echo "We have ${rem} operations left, pausing for ${pause} seconds."
        sleep ${pause}
    else
        echo "We have ${rem} operations left, continuing."
    fi
}

# Create a list opf the repos to skip if any
declare -a skip_list=(`echo "${SKIPLIST}" | tr ',' ' '`)

# Get the repositories in the org
repos=`gh repo list "${ORG}" --no-archived --limit 50 | awk '{ print $1 }' | awk -F "/" '{ print $2 }'`
for repo in $repos 
do
    skip="false"
    for skip_repo in "${skip_list[@]}" 
    do
        if [[ "${repo}" == "${skip_repo}" ]]; then
            continue 2
        fi
    done    
    echo "${ORG}/${repo}"
    check_rate_limit
    ./update_repo.sh "${ORG}" "${repo}"
done
