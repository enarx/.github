#!/bin/bash

# Command to process issues and prs in a single repo in an org
# update_repo.sh <org> <repo>

echo "$0 $@"

ORG="${1}"
REPO="${2}"


query1="query (\$endCursor: String) {
  repository(name: \"${REPO}\", owner: \"${ORG}\") {
    id
    issues(first: 100, after: \$endCursor) {
      nodes {
        __typename
        id
        number
        state
        createdAt
        updatedAt
        projectItems(first: 100) {
          nodes {
            id
            project {
              id
            }
            fieldValues(first: 20) {
              nodes {
                __typename
                ... on ProjectV2ItemFieldDateValue {
                  id
                  date
                  field {
                    ... on ProjectV2Field {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldNumberValue {
                  id
                  number
                  field {
                    ... on ProjectV2Field {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldSingleSelectValue {
                  id
                  name
                  field {
                    ... on ProjectV2SingleSelectField {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldTextValue {
                  id
                  text
                  field {
                    ... on ProjectV2Field {
                      id
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}"

query2="query (\$endCursor: String) {
  repository(name: \"${REPO}\", owner: \"${ORG}\") {
    id
		pullRequests(first: 100, after: \$endCursor) {
      nodes {
        __typename
        id
        number
        state
        createdAt
        updatedAt
        isDraft
        merged
        projectItems(first: 100) {
          nodes {
            id
            project {
              id
            }
            fieldValues(first: 20) {
              nodes {
                __typename
                ... on ProjectV2ItemFieldDateValue {
                  id
                  date
                  field {
                    ... on ProjectV2Field {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldNumberValue {
                  id
                  number
                  field {
                    ... on ProjectV2Field {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldSingleSelectValue {
                  id
                  name
                  field {
                    ... on ProjectV2SingleSelectField {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldTextValue {
                  id
                  text
                  field {
                    ... on ProjectV2Field {
                      id
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}"

issue_file="all_issues_${ORG}_${REPO}.json"
echo "[" > "${issue_file}"
issues=`gh api graphql --paginate -f query="${query1}" \
        --header "X-Github-Next-Global-ID: 1"`
echo "${issues}" | sed 's/}{/},{/g' \
     >> "${issue_file}"
echo "]" >> "${issue_file}"

pr_file="all_prs_${ORG}_${REPO}.json"
echo "[" > "${pr_file}"
prs=`gh api graphql --paginate -f query="${query2}" \
        --header "X-Github-Next-Global-ID: 1"`
echo "${prs}" | sed 's/}{/},{/g' \
     >> "${pr_file}"
echo "]" >> "${pr_file}"

./update_issues_and_prs.sh "${issue_file}" "${pr_file}" "${ORG}"
