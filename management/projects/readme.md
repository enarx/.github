# Scripts for project management

This folder contains scripts used for project management.
The goal of the scripts is to periodically scan "enarx" and "profianinc" 
organizations and add issues and PRs to the corresponding projects
located in each of the organizations.

## Logic

**New open issues**, that are not a part of the corresponding project, 
are added, and the project fields "Created On" and "Number" are
automatically populated with the issue creation day
and the issue number. This is done for easier sorting and filtering 
of the issues during the triage.

**New open PRs** are added with the "In Review" state if they are marked
as a non "draft" and the "draft" PRs are added with the "In Progress" state.

**Closed issues and PRs** that are marked as "Done", are removed from
the project after 90 days (hardcoded) without an update. 

## Implementation

### Github

 * The scripts leverage the `gh api graphql` to do GitHub operations.
 * GitHub has a rate limiting policy. One can make not more than 
   5000 requests.
   To overcome this the code periodically checks how many requests are left 
   and pauses till the reset time + one minute. As a result the job might
   run for 3-4 hours.
 * The project ID and the IDs of the corresponding fields and options
   are hardcoded in the body of the scripts
   (inside `update_issues_and_prs.sh`).
 * To reduce number round trips, the scripts download all the PRs 
   and issues for a repository in batches of 100, save it into 
   a corresponding json file and then process the json file 
   and only perform the necessary modifications.
 * At the moment of writing, GitHub did not support more than one 
   mutation in a single request so batching of the requests 
   was not an option.
 * At the moment of writing, GitHub supported 1200 object in a projectV2.
   No check is conducted how many objects are in the project,
   but the pruning period (90 day) can be adjusted in future.

### Scripts

* **update_all.sh** - the root script that runs the whole job.
This script should be run as a part of the automation.
* **update_org.sh** - the top script for a single organization.
This script updates issues and prs for a single organization.
It detects whether there are some repos that need to be skipped
and then calls the per repo script. It also does the rate 
limiting checks, and if there are less than 2000 operations left,
sleeps until the next time slice.
* **update_repo.sh** - the per repo script.
This scrips downloads all the issues and PRs for a repo 
and stores them in json files.
* **update_issues_and_prs.sh** - the script to do the per repo 
modifications.
This scripts processes the json files using jq and identifies
what changes to make. It then calls `gh` command line 
to make the changes, if they are needed. After processing issues,
it processes the PRs.

The scripts do not check the passed arguments since they are
supposed to be used in conjunction with each other and can assume
that the correct parameters are passed.

For debugging, inspect comments at the top of each file
to determine, what parameters are passed and what they mean.
