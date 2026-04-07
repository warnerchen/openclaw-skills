#!/usr/bin/env bash

set -euo pipefail

PROFILE="${AGENT_BROWSER_PROFILE:-$HOME/.agent-browser/profile/suse_okta_profile}"
SALESFORCE_URL="https://suse.lightning.force.com/"
OKTA_LOGIN_URL="https://suse.okta.com"
MAX_WAIT_SECONDS=180
POLL_INTERVAL=5

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

wait_page() {
  agent-browser wait --load networkidle >/dev/null
}

get_snapshot_refs() {
  agent-browser snapshot -i 2>/dev/null || true
}

get_snapshot_tree() {
  agent-browser snapshot 2>/dev/null || true
}

get_title() {
  agent-browser get title 2>/dev/null || true
}

get_ref() {
  local snapshot="$1"
  local text="$2"

  awk -v t="$text" '
    index($0, t) {
      if (match($0, /ref=[^], ]+/)) {
        print substr($0, RSTART + 4, RLENGTH - 4)
        exit
      }
    }
  ' <<<"$snapshot"
}

click_close_if_present() {
  local snapshot_refs="$1"
  local close_ref

  close_ref="$(get_ref "$snapshot_refs" 'button "Close"')"
  if [[ -n "$close_ref" ]]; then
    log "Closing popup..."
    agent-browser click "$close_ref" >/dev/null || true
    wait_page
  fi
}

wait_for_login_page() {
  local elapsed=0
  local snapshot_refs

  while (( elapsed < MAX_WAIT_SECONDS )); do
    snapshot_refs="$(get_snapshot_refs)"

    if grep -q 'textbox "Username"' <<<"$snapshot_refs" \
      && grep -q 'textbox "Password"' <<<"$snapshot_refs" \
      && grep -q 'button "Sign In"' <<<"$snapshot_refs"; then
      printf '%s\n' "$snapshot_refs"
      return 0
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  return 1
}

wait_for_login_result() {
  local elapsed=0
  local snapshot_tree
  local snapshot_refs
  local page_title

  while (( elapsed < MAX_WAIT_SECONDS )); do
    snapshot_tree="$(get_snapshot_tree)"
    snapshot_refs="$(get_snapshot_refs)"
    page_title="$(get_title)"

    # Check login failure first (based on DOM tree)
    if grep -q 'Unable to sign in' <<<"$snapshot_tree"; then
      echo "failed"
      return 0
    fi

    # Check if redirected to Okta dashboard (no MFA required)
    if [[ "$page_title" == "My Apps Dashboard | SUSE" ]]; then
      echo "dashboard"
      return 0
    fi

    # Check if MFA page is shown
    if grep -q 'Okta Verify' <<<"$snapshot_refs"; then
      echo "mfa"
      return 0
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  return 1
}

wait_for_mfa_result() {
  local elapsed=0
  local page_title
  local snapshot_tree

  while (( elapsed < MAX_WAIT_SECONDS )); do
    page_title="$(get_title)"
    snapshot_tree="$(get_snapshot_tree)"

    # MFA success → redirected to dashboard
    if [[ "$page_title" == "My Apps Dashboard | SUSE" ]]; then
      echo "success"
      return 0
    fi

    # MFA explicitly rejected by user
    if grep -q 'You have chosen to reject this login.' <<<"$snapshot_tree"; then
      echo "rejected"
      return 0
    fi

    # Fallback failure case
    if grep -q 'Unable to sign in' <<<"$snapshot_tree"; then
      echo "failed"
      return 0
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  return 1
}

wait_for_salesforce_entry() {
  local elapsed=0
  local snapshot_refs

  while (( elapsed < MAX_WAIT_SECONDS )); do
    snapshot_refs="$(get_snapshot_refs)"

    if grep -q 'group "Salesforce"' <<<"$snapshot_refs"; then
      printf '%s\n' "$snapshot_refs"
      return 0
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  return 1
}

open_salesforce_from_dashboard() {
  log "Waiting for Salesforce entry..."

  local snapshot_refs
  local salesforce_ref

  snapshot_refs="$(wait_for_salesforce_entry)" || fail "Salesforce not found"
  salesforce_ref="$(get_ref "$snapshot_refs" 'group "Salesforce"')"

  [[ -n "$salesforce_ref" ]] || fail "Salesforce ref not found"

  log "Clicking Salesforce..."
  agent-browser click "$salesforce_ref" >/dev/null
  wait_page
}

command -v agent-browser >/dev/null 2>&1 || fail "agent-browser not found"

# Step 1: Check if Salesforce session is still valid
log "Opening Salesforce..."
agent-browser open "$SALESFORCE_URL" >/dev/null
wait_page

salesforce_title="$(get_title)"

# If not on login page → already authenticated
if [[ "$salesforce_title" != "Login | Salesforce" ]]; then
  log "Salesforce session is still valid, no login required."
  exit 0
fi

log "Salesforce requires login."

# Step 2: Clean up existing agent-browser processes
log "Cleaning agent-browser processes..."
agent-browser close >/dev/null 2>&1 || true
pkill -9 -f "agent-browser" >/dev/null 2>&1 || true
sleep 1

# Step 3: Open Okta and check if profile is already authenticated
log "Opening Okta..."
agent-browser --profile "$PROFILE" open "$OKTA_LOGIN_URL" >/dev/null
wait_page

okta_title="$(get_title)"

# If already on dashboard → skip login and MFA
if [[ "$okta_title" == "My Apps Dashboard | SUSE" ]]; then
  log "Profile already authenticated, skipping login."
  open_salesforce_from_dashboard
  log "SUCCESS"
  exit 0
fi

# Step 4: Prompt for credentials
read -rp "Okta username: " OKTA_USERNAME
read -rsp "Okta password: " OKTA_PASSWORD
echo

# Step 5: Perform login
login_snapshot="$(wait_for_login_page)" || fail "Login page not detected"

click_close_if_present "$login_snapshot"
login_snapshot="$(get_snapshot_refs)"

username_ref="$(get_ref "$login_snapshot" 'textbox "Username"')"
password_ref="$(get_ref "$login_snapshot" 'textbox "Password"')"
signin_ref="$(get_ref "$login_snapshot" 'button "Sign In"')"

agent-browser fill "@$username_ref" "$OKTA_USERNAME" >/dev/null
agent-browser fill "@$password_ref" "$OKTA_PASSWORD" >/dev/null
agent-browser click "$signin_ref" >/dev/null
wait_page

# Step 6: Evaluate login result
login_result="$(wait_for_login_result)" || fail "Login timeout"

[[ "$login_result" == "failed" ]] && fail "Invalid username or password"

if [[ "$login_result" == "dashboard" ]]; then
  log "Login successful (no MFA)"
  open_salesforce_from_dashboard
  log "SUCCESS"
  exit 0
fi

# Step 7: MFA handling
log "MFA required..."

mfa_snapshot="$(get_snapshot_refs)"
auto_push="$(grep 'Send push automatically' <<<"$mfa_snapshot" || true)"

if [[ "$auto_push" != *"[checked=true"* ]]; then
  push_ref="$(get_ref "$mfa_snapshot" 'button "Send Push"')"
  [[ -z "$push_ref" ]] && push_ref="$(get_ref "$mfa_snapshot" 'button "Push sent!"')"

  [[ -n "$push_ref" ]] || fail "Push button not found"

  agent-browser click "$push_ref" >/dev/null
  wait_page
fi

mfa_result="$(wait_for_mfa_result)" || fail "MFA timeout"

[[ "$mfa_result" == "rejected" ]] && fail "MFA rejected"
[[ "$mfa_result" == "failed" ]] && fail "Login failed during MFA"

wait_page

# Step 8: Open Salesforce
open_salesforce_from_dashboard

log "SUCCESS"