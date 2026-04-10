# SUSE Support Case Skills (Salesforce)

A collection of skills for operating SUSE Support Cases in Salesforce.

## Prerequisites

- OpenClaw
- Agent Browser: For security reasons, there is no skill for login. Please log in manually before using the following skills.

## Login to Salesforce via Okta

This `suse_okta_salesforce_login.sh` script automates the login process to Salesforce via Okta using agent-browser.

It intelligently determines whether login is required and handles multiple scenarios including:

- Existing active Salesforce session
- Cached Okta session (no login required)
- Standard login with username/password
- MFA (Okta Verify push)
- MFA rejection or login failure

### Flowchart

```mermaid
graph TD
    Start((Start)) --> CheckCmd{Check env: <br>is agent-browser<br>installed?}
    CheckCmd -- No --> FailCmd[Fail: agent-browser not found]
    
    CheckCmd -- Yes --> Step1[Step 1: Open Salesforce URL]
    Step1 --> CheckSFTitle{Does Salesforce<br>require login?}
    CheckSFTitle -- Title is NOT 'Login | Salesforce' --> SFSkipped[Log: Salesforce session valid] --> Exit0_1(((Exit 0)))
    
    CheckSFTitle -- Title IS 'Login | Salesforce' --> Step2[Step 2: Clean up agent-browser processes]
    
    Step2 --> Step3[Step 3: Open Okta with Profile]
    Step3 --> CheckOktaTitle{Is Okta<br>already logged in?}
    CheckOktaTitle -- Title is 'My Apps Dashboard' --> DashboardAction1[Click Salesforce in Dashboard] --> Exit0_2(((Exit 0)))
    
    CheckOktaTitle -- Other Title --> Step4[/Step 4: Prompt for Okta Credentials/]
    
    Step4 --> Step5[Step 5: Wait for Login Page & Close Popups]
    Step5 --> FillForm[Fill Credentials & Click Sign In]
    
    FillForm --> Step6[Step 6: Wait for Login Result]
    Step6 --> CheckLoginResult{Evaluate Login Result}
    CheckLoginResult -- Timeout --> FailTimeout1[Fail: Login Timeout]
    CheckLoginResult -- "failed" (DOM shows error) --> FailCreds[Fail: Invalid Credentials]
    CheckLoginResult -- "dashboard" (No MFA needed) --> DashboardAction2[Click Salesforce in Dashboard] --> Exit0_3(((Exit 0)))
    
    CheckLoginResult -- "mfa" (MFA required) --> Step7[Step 7: Handle MFA]
    Step7 --> CheckAutoPush{Is 'Auto-Push'<br>checked?}
    CheckAutoPush -- No --> ClickPush[Click 'Send Push' Button] --> WaitMFA
    CheckAutoPush -- Yes --> WaitMFA[Wait for MFA Result]
    
    WaitMFA --> CheckMFAResult{Evaluate MFA Result}
    CheckMFAResult -- Timeout --> FailTimeout2[Fail: MFA Timeout]
    CheckMFAResult -- "rejected" (User rejected push) --> FailReject[Fail: MFA Rejected]
    CheckMFAResult -- "failed" (Other failure) --> FailMFALogin[Fail: Login failed during MFA]
    
    CheckMFAResult -- "success" (Redirected to Dashboard) --> Step8[Step 8: Click Salesforce in Dashboard]
    Step8 --> Exit0_4(((Exit 0)))

    %% Style definition for Failure nodes
    classDef failNode fill:#ffebee,stroke:#c62828,stroke-width:2px,color:#c62828;
    class FailCmd,FailTimeout1,FailCreds,FailTimeout2,FailReject,FailMFALogin failNode;
    
    %% Style definition for Success nodes
    classDef successNode fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#2e7d32;
    class Exit0_1,Exit0_2,Exit0_3,Exit0_4 successNode;
```

### Usage

```bash
bash ./suse_okta_salesforce_login.sh
```

### Debug

```bash
bash -x ./suse_okta_salesforce_login.sh
```

## Features

- `suse_support_case_accept`: Accept a case
- `suse_support_case_download_files`: Download case attachments
- `suse_support_case_reply`: Reply to a case
- `suse_support_case_search_queue`: View case queues
- `suse_support_case_view`: View case details
