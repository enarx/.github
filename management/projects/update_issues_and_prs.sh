#!/bin/bash

# Command to update fetched issues and prs in a single repo in an org
# update_repo.sh <file with issues> <file with prs> <org>

echo "$0 $@"

# Arguments are files to process
ISSUE_FILE="${1}"
PR_FILE="${2}"


# Issues filter
ISSUE_FILTER='.[].data.repository.issues.nodes[] | 
""+.id+","+(.number|tostring)+","+.state+","+.createdAt+","+.updatedAt'
# PR filter
PR_FILTER='.[].data.repository.pullRequests.nodes[] | 
""+.id+","+(.number|tostring)+","+.state+","+
.createdAt+","+.updatedAt+","+
(.isDraft|tostring)+","+
(.merged|tostring)'


# Project ID for Enarx
ENARX_PROJECTID="PVT_kwDOAqzHpc4AIh12"
# Project ID for Profian inc
PROFIAN_PROJECTID="PVT_kwDOBd3qUM4AIwmb"

# ID of the "Number" field in the Enarx project
ENARX_NUMBERFLD="PVTF_lADOAqzHpc4AIh12zgGnZEo"
ENARX_DATEFLD="PVTF_lADOAqzHpc4AIh12zgG5T-U"
ENARX_STATUSFLD="PVTSSF_lADOAqzHpc4AIh12zgFT-cE"

# ID of the "Number" field in the Enarx project
PROFIAN_NUMBERFLD="PVTF_lADOBd3qUM4AIwmbzgHFigs"
PROFIAN_DATEFLD="PVTF_lADOBd3qUM4AIwmbzgHFihY"
PROFIAN_STATUSFLD="PVTSSF_lADOBd3qUM4AIwmbzgFbj8E"

# IDs of the values for the status field for Enarx
ENARX_DONE="\"98236657\""
ENARX_INREVIEW="\"e64e8baa\""
ENARX_NEW="\"f75ad846\""
ENARX_INPROGRESS="\"47fc9ee4\""

# IDs of the values for the status field for Profianinc
PROFIAN_DONE="\"98236657\""
PROFIAN_INREVIEW="\"ed52fe48\""
PROFIAN_NEW="\"f75ad846\""
PROFIAN_INPROGRESS="\"47fc9ee4\""

# Make sure we are using the right project
if [[ "${3}" == "profianinc" ]]; then
    PROJECTID="${PROFIAN_PROJECTID}"
    NUMBERFLD="${PROFIAN_NUMBERFLD}"
    DATEFLD="${PROFIAN_DATEFLD}"
    STATUSFLD="${PROFIAN_STATUSFLD}"
    O_DONE="${PROFIAN_DONE}"
    O_INREVIEW="${PROFIAN_INREVIEW}"
    O_NEW="${PROFIAN_NEW}"
    O_INPROGRESS="${PROFIAN_INPROGRESS}"
    
elif [[ "${3}" == "enarx" ]]; then
    PROJECTID="${ENARX_PROJECTID}"
    NUMBERFLD="${ENARX_NUMBERFLD}"
    DATEFLD="${ENARX_DATEFLD}"
    STATUSFLD="${ENARX_STATUSFLD}"
    O_DONE="${ENARX_DONE}"
    O_INREVIEW="${ENARX_INREVIEW}"
    O_NEW="${ENARX_NEW}"
    O_INPROGRESS="${ENARX_INPROGRESS}"
else
    echo "Unknown organization: ${3}"
    exit 1
fi


# Add an issue to the project
function add_to_project() {
    query="
        mutation {
            addProjectV2ItemById(input: {
                    projectId: \"${2}\" 
                    contentId: \"${1}\"
                    }) {
                item {
                    id
                }
            }
        }"
    echo "Adding to project."
#    returned_node="XXXXX"
    returned_node=`gh api graphql -f query="${query}" \
        --jq '.data.addProjectV2ItemById.item.id'`
}

function set_fields() {
# Check whether there is anything to do
    if [[ "${1}" == "false" && "${2}" == "false" && "${3}" == "false" ]]; then
        echo "All fields are present, nothing to do."
        return
    fi
    number_str=""
    if [[ "${1}" == "true" ]]; then
        number_str="
        mutation {
            updateProjectV2ItemFieldValue(
            input: {
                projectId: \"${PROJECTID}\"
                itemId: \"${4}\"
                fieldId: \"${NUMBERFLD}\"
                    value: { 
                        number: ${5}
                    }
            } ) {
                projectV2Item {
                    id
                }
            }
        }"
        echo "Updating Number field."
        gh api graphql -f query="${number_str}" 1> /dev/null
    fi
    date_str=""
    if [[ "${2}" == "true" ]]; then
        date_str="
        mutation {
            updateProjectV2ItemFieldValue(
            input: {
                projectId: \"${PROJECTID}\"
                itemId: \"${4}\"
                fieldId: \"${DATEFLD}\"
                    value: { 
                        date: \"${6}\"
                    }
            } ) {
                projectV2Item {
                    id
                }
            }
        }"
        echo "Updating Date field."
        gh api graphql -f query="${date_str}" 1> /dev/null
    fi
    state_str=""
    if [[ "${3}" == "true" ]]; then
        state_str="
        mutation {
            updateProjectV2ItemFieldValue(
            input: {
                projectId: \"${PROJECTID}\"
                itemId: \"${4}\"
                fieldId: \"${STATUSFLD}\"
                    value: { 
                        singleSelectOptionId: ${7}
                    }
                } ) {
                    projectV2Item {
                        id
                }
            }
        }"
        echo "Updating Status field."
        gh api graphql -f query="${state_str}" 1> /dev/null
    fi
}

# Delete item from the project
function delete_node() {
    query="
        mutation {
            deleteProjectV2Item(
            input: {
                projectId: \"${PROJECTID}\" 
                itemId: \"${1}\"
                }
            ) {
                deletedItemId
            }
        }"    
    echo "Deleting."
    gh api graphql -f query="${query}" 1> /dev/null
}


# =================== Main =================

# Handle issues first

declare -a issues=(`jq "${ISSUE_FILTER}" "${ISSUE_FILE}" | tr '\n' ' '`)

#echo "${issues}"
count=0
for issue in "${issues[@]}"
do
    issue_id=""
    issue_number=""
    issue_state=""
    issue_created=""
    issue_updated=""

# Check if the issue is in the project

    issue=`echo "${issue}" | sed 's/\"//g'`
#   echo "${issue}"
    issue_id=`echo "${issue}" | awk -F "," '{ print $1 }'`
    issue_number=`echo "${issue}" | awk -F "," '{ print $2 }'`
    issue_state=`echo "${issue}" | awk -F "," '{ print $3 }'`
    issue_created=`echo "${issue}" | awk -F "," '{ print $4 }' | \
                                     awk -F "T" '{ print $1 }'`
    issue_updated=`echo "${issue}" | awk -F "," '{ print $5 }' | \
                                     awk -F "T" '{ print $1 }'`
#    echo "${issue_id}"
     echo "Processing issue ${issue_number}"
#    echo "${issue_state}"
#    echo "${issue_created}"
#    echo "${issue_updated}"
    ago=$(( ($(date +%s) - $(date --date="${issue_updated}" +%s) )/(60*60*24) ))
#    echo "${ago}"

    batch=$(( ${count} / 100 ))
    offset=$(( ${count} - ${batch} * 100 ))
    projfilter=".["${batch}"].data.repository.issues.nodes["${offset}"].projectItems.nodes[]
                 | select(.project.id == \"${PROJECTID}\") | .id"

#    echo "${projfilter}"
    node=""
    node=`jq "${projfilter}" "${ISSUE_FILE}" 2> /dev/null | sed 's/\"//g'`
    if [[ -z "${node}" ]]; then
        if [[ "${issue_state}" == "OPEN" ]]; then
            returned_node=""
            add_to_project "${issue_id}" "${PROJECTID}"
            set_fields "true" "true" "true" \
                       "${returned_node}" \
                       "${issue_number}" \
                       "${issue_created}" \
                       "${O_NEW}"
        fi
    else 
        echo "Node: [${node}]"
        if [[ "${issue_state}" == "CLOSED" && ( "${ago}" -gt "90" ) ]]; then
            echo "Deleting issue node, age ${ago} days."
            delete_node "${node}"
        else
# The following is done to reduce the number of updates to GitHub due to 
# rate limiting        
            fieldfilter="
            .["${batch}"].data.repository.issues.nodes["${offset}"].projectItems.nodes[] | 
            select(.project.id == \"${PROJECTID}\" ) |
            ((.fieldValues.nodes[] |
                select(.__typename == \"ProjectV2ItemFieldSingleSelectValue\"
                    or .__typename == \"ProjectV2ItemFieldDateValue\"
                    or .__typename == \"ProjectV2ItemFieldNumberValue\"
                ) |
                if (.__typename == \"ProjectV2ItemFieldSingleSelectValue\")
                then
                    \"\"+.field.name+\",\"+.name+\",\"+.id+\",\"+.field.id
                elif (.__typename == \"ProjectV2ItemFieldNumberValue\")
                then
                    \"\"+.field.name+\",\"+(.number | tostring)+
                    \",\"+.id+\",\"+.field.id
                elif (.__typename == \"ProjectV2ItemFieldDateValue\")
                then
                    \"\"+.field.name+\",\"+.date+\",\"+.id+\",\"+.field.id
                else \"\" end
            ))"
            declare -a fields=(`jq "${fieldfilter}" "${ISSUE_FILE}" | \
                                                    tr '\n' ' '`)
            update_number="true"
            update_date="true"
            for field in "${fields[@]}"
            do
                fld_id=`echo "${field}" | sed 's/\"//g' | \
                                          awk -F "," '{ print $4 }'`
                if [[ "${fld_id}" == "${NUMBERFLD}" ]]; then
                    echo "Number present."
                    update_number="false"
                fi
                if [[ "${fld_id}" == "${DATEFLD}" ]]; then
                    echo "Date present."
                    update_date="false"
                fi
            done
            set_fields "${update_number}" \
                       "${update_date}" \
                       "false" \
                       "${node}" \
                       "${issue_number}" \
                       "${issue_created}" \
                       "${O_NEW}"
        fi
    fi
    count=$(($count + 1))
#    echo ${count}
done

# Handle PRs
declare -a prs=(`jq "${PR_FILTER}" "${PR_FILE}" | tr '\n' ' '`)

count=0
for pr in "${prs[@]}"
do
    pr_id=""
    pr_number=""
    pr_state=""
    pr_created=""
    pr_updated=""
    pr_draft=""
    pr_merged=""

# Check if the issue is in the project

    pr=`echo "${pr}" | sed 's/\"//g'`
#    echo "${pr}"
    pr_id=`echo "${pr}" | awk -F "," '{ print $1 }'`
    pr_number=`echo "${pr}" | awk -F "," '{ print $2 }'`
    pr_state=`echo "${pr}" | awk -F "," '{ print $3 }'`
    pr_created=`echo "${pr}" | awk -F "," '{ print $4 }' | \
                               awk -F "T" '{ print $1 }'`
    pr_updated=`echo "${pr}" | awk -F "," '{ print $5 }' | \
                               awk -F "T" '{ print $1 }'`
    pr_draft=`echo "${pr}" | awk -F "," '{ print $6 }'`
    pr_merged=`echo "${pr}" | awk -F "," '{ print $7 }'`

#    echo "${pr_id}"
    echo "Processing pr ${pr_number}"
#    echo "${pr_state}"
#    echo "${pr_created}"
#    echo "${pr_updated}"
#    echo "${pr_draft}"
#    echo "${pr_merged}"
    ago=$(( ($(date +%s) - $(date --date="${pr_updated}" +%s) )/(60*60*24) ))
#    echo "${ago}"
    batch=$(( ${count} / 100 ))
    offset=$(( ${count} - ${batch} * 100 ))
    projfilter=".["${batch}"].data.repository.pullRequests.nodes["${offset}"].projectItems.nodes[]
                 | select(.project.id == \"${PROJECTID}\") | .id"

#    echo "${projfilter}"
    node=`jq "${projfilter}" "${PR_FILE}" 2> /dev/null`
    if [[ -z "${node}" ]]; then
        if [[ "${pr_state}" == "OPEN" ]]; then
            echo "Adding open a PR to project."
            returned_node=""
            add_to_project "${pr_id}" "${PROJECTID}"
            echo "Added with node ${returned_node}."

            if [[ "${pr_draft}" == "false" ]]; then
                echo "No-draft - setting \"in review\"."
                set_fields "false" "false" "true" \
                        "${returned_node}" \
                        "" \
                        "" \
                        "${O_INREVIEW}"
            else
                echo "Draft - setting \"in progress\"."
                set_fields "false" "false" "true" \
                        "${returned_node}" \
                        "" \
                        "" \
                        "${O_INPROGRESS}"
            fi
        fi
    else 
#        echo "${node}"
# We do not update PRs if it is already a part of the project
# only remove if they are older than 90 days
        if [[ ("${pr_state}" == "MERGED" || \
               "${pr_state}" == "CLOSED") && \
               ( "${ago}" -gt "90" ) ]]; then
            echo "Deleting PR node, age ${ago} days."
            delete_node "${node}"
        fi
    fi
    count=$(($count + 1))
#    echo ${count}
done

