# SUSE Support Case Skills (Salesforce)

A collection of skills for operating SUSE Support Cases in Salesforce.

## Prerequisites

- OpenClaw
- Agent Browser: For security reasons, there is no skill for login. Please log in manually before using the following skills.

## Login to Salesforce via Okta

```bash
# Open the login page
agent-browser --profile ~/.agent-browser/profile/suse_okta_profile open https://suse.okta.com

# Verify the references (Refs) of each button
agent-browser snapshot -i

# Enter the username
agent-browser fill @e7 "<your_username>"

# Enter the password
agent-browser fill @e8 "<your_password>"

# Click Log In to proceed to the multi-factor authentication page
agent-browser click e5

# Use Okta Verify for authentication
agent-browser click e5

# After verification, you will be redirected to the My Applications dashboard; locate Salesforce
agent-browser snapshot -i | grep "Salesforce"
    - group "Salesforce" [ref=e38] clickable [cursor:pointer]

# Click Salesforce
agent-browser click e38

# Salesforce usually loads slowly; you can use the following command to wait until the page is fully loaded
agent-browser wait --load networkidle
```

## Features

- `suse_support_case_accept`: Accept a case

- `suse_support_case_download_files`: Download case attachments

- `suse_support_case_reply`: Reply to a case

- `suse_support_case_search_queue`: View case queues

- `suse_support_case_view`: View case details
