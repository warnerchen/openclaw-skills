# SUSE Support Case Skills (Salesforce)

A collection of skills for operating SUSE Support Cases in Salesforce.

## Prerequisites

- OpenClaw
- Agent Browser: For security reasons, there is no skill for login. Please log in manually before using the following skills.

## Login to Salesforce via SUSEID

This `suse_suseid_salesforce_login.sh` script automates the login process to Salesforce via SUSEID using `agent-browser`.

> Since Okta will be migrated to SUSEID, please do not use `suse_okta_salesforce_login.sh` to log in to Salesforce.

### Flowchart

```mermaid
graph TD
    Start((Start)) --> CheckCmd{"Check env<br/>agent-browser installed?"}
    CheckCmd -- No --> FailCmd["Fail: agent-browser not found"]
    CheckCmd -- Yes --> Step1["Step 1: Open Salesforce URL"]

    Step1 --> CheckSFTitle{"Does Salesforce<br/>require login?"}
    CheckSFTitle -- No --> SFSkipped["Log: Salesforce session valid"]
    SFSkipped --> Exit0_1(((Exit 0)))

    CheckSFTitle -- Yes --> Step2["Step 2: Clean up agent-browser processes"]
    Step2 --> Step3["Step 3: Open SUSEID with Profile"]
    Step3 --> CheckSUSEIDState{"Check SUSEID page state"}

    CheckSUSEIDState -- "Title = SUSEID" --> StepOpenSF1["Open Salesforce from SUSEID page"]
    StepOpenSF1 --> Exit0_2(((Exit 0)))

    CheckSUSEIDState -- "Title = SUSEID Login - SUSEID" --> Step4["Step 4: Start SUSEID login flow"]
    CheckSUSEIDState -- "Login form detected under unexpected title" --> Step4
    CheckSUSEIDState -- Other --> FailUnexpected["Fail: Unexpected SUSEID page"]

    Step4 --> NormalizePage{"Is page showing<br/>remembered user?"}
    NormalizePage -- Yes --> ClickNotYou["Click Not you?"]
    ClickNotYou --> WaitUserPage["Wait for username page"]
    NormalizePage -- No --> PromptCreds["Prompt for SUSEID username and password"]
    WaitUserPage --> PromptCreds

    PromptCreds --> FillUsername["Fill username"]
    FillUsername --> CheckPasswordField{"Is password field<br/>already present?"}

    CheckPasswordField -- No --> SubmitUsername["Click Log in / Continue / Next"]
    SubmitUsername --> WaitPassword["Wait for password page"]

    CheckPasswordField -- Yes --> FillPassword["Fill password"]
    WaitPassword --> FillPassword

    FillPassword --> SubmitPassword["Click Continue / Log in / Verify"]
    SubmitPassword --> WaitPasswordResult["Wait for login result"]

    WaitPasswordResult --> CheckPasswordResult{"Evaluate result after password submit"}
    CheckPasswordResult -- Success --> StepOpenSF2["Open Salesforce from SUSEID page"]
    CheckPasswordResult -- Invalid credentials --> FailCreds["Fail: Invalid username or password"]
    CheckPasswordResult -- Invalid token --> FailToken1["Fail: Authentication Code validation failed"]
    CheckPasswordResult -- OTP required --> PromptOTP["Prompt for Authentication Code"]
    CheckPasswordResult -- Timeout --> FailTimeout1["Fail: Login timeout"]

    PromptOTP --> FillOTP["Fill Authentication Code"]
    FillOTP --> SubmitOTP["Click Continue / Verify / Log in"]
    SubmitOTP --> WaitOTPResult["Wait for OTP result"]

    WaitOTPResult --> CheckOTPResult{"Evaluate OTP result"}
    CheckOTPResult -- Success --> StepOpenSF3["Open Salesforce from SUSEID page"]
    CheckOTPResult -- Invalid token --> FailToken2["Fail: Invalid Authentication Code"]
    CheckOTPResult -- Invalid credentials --> FailCreds2["Fail: Invalid username or password"]
    CheckOTPResult -- Timeout --> FailTimeout2["Fail: OTP timeout"]

    StepOpenSF2 --> Exit0_3(((Exit 0)))
    StepOpenSF3 --> Exit0_4(((Exit 0)))

    classDef failNode fill:#ffebee,stroke:#c62828,stroke-width:2px,color:#c62828;
    class FailCmd,FailUnexpected,FailCreds,FailToken1,FailTimeout1,FailToken2,FailCreds2,FailTimeout2 failNode;

    classDef successNode fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#2e7d32;
    class Exit0_1,Exit0_2,Exit0_3,Exit0_4 successNode;
```

### Usage

```bash
bash ./suse_suseid_salesforce_login.sh
```

### Debug

```bash
bash -x ./suse_suseid_salesforce_login.sh
```

## Features

- `suse_support_case_accept`: Accept a case
- `suse_support_case_download_files`: Download case attachments
- `suse_support_case_reply`: Reply to a case
- `suse_support_case_search_queue`: View case queues
- `suse_support_case_view`: View case details
