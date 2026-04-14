#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AGENT_BROWSER_PROFILE:-/root/.agent-browser/profile/suse_suseid_profile}"
SALESFORCE_URL="https://suse.lightning.force.com/"
SUSEID_URL="https://id.suse.com/"

SALESFORCE_LOGIN_TITLE="Login | Salesforce"
SUSEID_LOGIN_TITLE="SUSEID Login - SUSEID"
SUSEID_TITLE="SUSEID"

MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-180}"
POLL_INTERVAL="${POLL_INTERVAL:-2}"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
    log "ERROR: $*"
    exit 1
}

ab() {
    agent-browser --profile "$PROFILE" "$@"
}

ab_open() {
    ab open "$1" >/dev/null
}

wait_page() {
    agent-browser wait --load networkidle >/dev/null 2>&1 || true
}

get_title() {
    agent-browser get title 2>/dev/null || true
}

get_snapshot_refs() {
    agent-browser snapshot -i 2>/dev/null || true
}

get_snapshot_tree() {
    agent-browser snapshot 2>/dev/null || true
}

extract_ref_from_line() {
    sed -n 's/.*ref=\([^], ]*\).*/\1/p' <<<"$1" | head -n1
}

find_ref() {
    local snapshot="$1"
    shift

    local term line ref
    for term in "$@"; do
        line="$(printf '%s\n' "$snapshot" | grep -iF -m1 "$term" || true)"
        ref="$(extract_ref_from_line "$line")"
        if [[ -n "$ref" ]]; then
            printf '%s\n' "$ref"
            return 0
        fi
    done

    return 1
}

snapshot_has_text() {
    local content="$1"
    shift

    local term
    for term in "$@"; do
        if grep -qiF "$term" <<<"$content"; then
            return 0
        fi
    done
    return 1
}

click_ref() {
    local ref="$1"
    agent-browser click "@$ref" >/dev/null
    wait_page
}

click_ref_new_tab() {
    local ref="$1"
    agent-browser click "@$ref" --new-tab >/dev/null
    wait_page
}

fill_ref() {
    local ref="$1"
    local value="$2"
    agent-browser fill "@$ref" "$value" >/dev/null
}

cleanup_agent_browser() {
    log "Cleaning agent-browser processes..."
    agent-browser close >/dev/null 2>&1 || true
    pkill -TERM -f '[a]gent-browser' >/dev/null 2>&1 || true

    for _ in {1..10}; do
        if ! pgrep -f '[a]gent-browser' >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
    done

    log "agent-browser still running, forcing kill..."
    pkill -KILL -f '[a]gent-browser' >/dev/null 2>&1 || true
    sleep 0.5
}

wait_for_username_page() {
    local elapsed=0
    local snapshot

    while (( elapsed < MAX_WAIT_SECONDS )); do
        snapshot="$(get_snapshot_refs)"

        if find_ref "$snapshot" 'Email or Username' 'Email' 'Username' >/dev/null 2>&1; then
            printf '%s\n' "$snapshot"
            return 0
        fi

        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    return 1
}

wait_for_password_page() {
    local elapsed=0
    local snapshot

    while (( elapsed < MAX_WAIT_SECONDS )); do
        snapshot="$(get_snapshot_refs)"
        if find_ref "$snapshot" 'Password' >/dev/null 2>&1; then
            printf '%s\n' "$snapshot"
            return 0
        fi

        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    return 1
}

normalize_suseid_login_page() {
    local snapshot not_you_ref

    snapshot="$(get_snapshot_refs)"

    if find_ref "$snapshot" 'Not you?' >/dev/null 2>&1; then
        not_you_ref="$(find_ref "$snapshot" 'Not you?' || true)"
        if [[ -n "$not_you_ref" ]]; then
            log 'Detected remembered SUSEID user, clicking "Not you?"...'
            click_ref "$not_you_ref"
            snapshot="$(wait_for_username_page)" || fail 'Username page not detected after clicking "Not you?"'
        fi
    fi

    printf '%s\n' "$snapshot"
}

wait_for_post_password_state() {
    local elapsed=0
    local title snapshot_refs snapshot_tree

    while (( elapsed < MAX_WAIT_SECONDS )); do
        title="$(get_title)"
        snapshot_refs="$(get_snapshot_refs)"
        snapshot_tree="$(get_snapshot_tree)"

        if snapshot_has_text "$snapshot_tree" "Invalid password"; then
            echo "invalid_password"
            return 0
        fi

        if snapshot_has_text "$snapshot_tree" "Invalid Token"; then
            echo "invalid_token"
            return 0
        fi

        if [[ "$title" == "$SUSEID_TITLE" ]]; then
            echo "success"
            return 0
        fi

        if find_ref "$snapshot_refs" \
            'Authentication Code' \
            'Verification Code' \
            'One-time code' \
            'One Time Code' \
            'Passcode' \
            'Token' >/dev/null 2>&1; then
            echo "otp"
            return 0
        fi

        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    return 1
}

wait_for_post_otp_state() {
    local elapsed=0
    local title snapshot_tree

    while (( elapsed < MAX_WAIT_SECONDS )); do
        title="$(get_title)"
        snapshot_tree="$(get_snapshot_tree)"

        if snapshot_has_text "$snapshot_tree" "Invalid Token"; then
            echo "invalid_token"
            return 0
        fi

        if snapshot_has_text "$snapshot_tree" "Invalid password"; then
            echo "invalid_password"
            return 0
        fi

        if [[ "$title" == "$SUSEID_TITLE" ]]; then
            echo "success"
            return 0
        fi

        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    return 1
}

wait_for_salesforce_link() {
    local elapsed=0
    local snapshot ref

    while (( elapsed < MAX_WAIT_SECONDS )); do
        snapshot="$(get_snapshot_refs)"
        ref="$(find_ref "$snapshot" 'Open "Salesforce"' 'Salesforce' || true)"
        if [[ -n "$ref" ]]; then
            printf '%s\n' "$ref"
            return 0
        fi

        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    return 1
}

prompt_suseid_credentials() {
    if [[ -z "${SUSEID_USERNAME:-}" ]]; then
        read -rp "SUSEID username: " SUSEID_USERNAME
    fi

    if [[ -z "${SUSEID_PASSWORD:-}" ]]; then
        read -rsp "SUSEID password: " SUSEID_PASSWORD
        echo
    fi
}

prompt_auth_code() {
    if [[ -z "${SUSEID_AUTH_CODE:-}" ]]; then
        read -rsp "Authentication Code: " SUSEID_AUTH_CODE
        echo
    fi
}

check_salesforce_login_needed() {
    log "Opening Salesforce..."
    ab_open "$SALESFORCE_URL"
    wait_page

    local title
    title="$(get_title)"

    if [[ "$title" != "$SALESFORCE_LOGIN_TITLE" ]]; then
        log "Salesforce does not require login, current title: $title"
        exit 0
    fi

    log "Salesforce requires login."
}

open_salesforce_from_suseid() {
    log "Waiting for Salesforce link on SUSEID page..."

    local salesforce_ref
    salesforce_ref="$(wait_for_salesforce_link)" || fail "Salesforce link not found on SUSEID page"

    log "Opening Salesforce..."
    click_ref_new_tab "$salesforce_ref"

    local final_title
    final_title="$(get_title)"
    log "Current page title after opening Salesforce: ${final_title:-<empty>}"
}

login_suseid() {
    local snapshot username_ref password_ref submit_ref state otp_ref

    prompt_suseid_credentials

    snapshot="$(normalize_suseid_login_page)"

    username_ref="$(find_ref "$snapshot" 'Email or Username' 'Email' 'Username' || true)"
    password_ref="$(find_ref "$snapshot" 'Password' || true)"

    [[ -n "$username_ref" ]] || fail 'Username input not found. Please run: agent-browser snapshot -i'

    log "Filling SUSEID username..."
    fill_ref "$username_ref" "$SUSEID_USERNAME"

    if [[ -z "$password_ref" ]]; then
        submit_ref="$(find_ref "$snapshot" 'Log in' 'Continue' 'Next' || true)"
        [[ -n "$submit_ref" ]] || fail 'Username submit button not found. Please run: agent-browser snapshot -i'

        log "Submitting username..."
        click_ref "$submit_ref"

        snapshot="$(wait_for_password_page)" || fail 'Password page not detected'
    else
        log "Password field is already present on the current page."
    fi

    password_ref="$(find_ref "$snapshot" 'Password' || true)"
    [[ -n "$password_ref" ]] || fail 'Password input not found. Please run: agent-browser snapshot -i'

    log "Filling SUSEID password..."
    fill_ref "$password_ref" "$SUSEID_PASSWORD"

    submit_ref="$(find_ref "$snapshot" 'Continue' 'Log in' 'Verify' || true)"
    [[ -n "$submit_ref" ]] || fail 'Password submit button not found. Please run: agent-browser snapshot -i'

    log "Submitting password..."
    click_ref "$submit_ref"

    state="$(wait_for_post_password_state)" || fail 'Timed out waiting for SUSEID login result'

    case "$state" in
        success)
            log "SUSEID login successful, no Authentication Code required."
            return 0
            ;;
        invalid_password)
            fail "Invalid username or password."
            ;;
        invalid_token)
            fail "Authentication Code validation failed."
            ;;
        otp)
            log "Authentication Code is required."
            ;;
        *)
            fail "Unexpected state after password submit: $state"
            ;;
    esac

    prompt_auth_code

    snapshot="$(get_snapshot_refs)"
    otp_ref="$(find_ref "$snapshot" \
        'Authentication Code' \
        'Verification Code' \
        'One-time code' \
        'One Time Code' \
        'Passcode' \
        'Token' || true)"

    [[ -n "$otp_ref" ]] || fail 'Authentication Code input not found. Please run: agent-browser snapshot -i'

    log "Filling Authentication Code..."
    fill_ref "$otp_ref" "$SUSEID_AUTH_CODE"

    submit_ref="$(find_ref "$snapshot" 'Continue' 'Verify' 'Log in' || true)"
    [[ -n "$submit_ref" ]] || fail 'Authentication Code submit button not found. Please run: agent-browser snapshot -i'

    log "Submitting Authentication Code..."
    click_ref "$submit_ref"

    state="$(wait_for_post_otp_state)" || fail 'Timed out waiting for Authentication Code verification result'

    case "$state" in
        success)
            log "Authentication Code verification successful."
            ;;
        invalid_token)
            fail "Invalid Authentication Code."
            ;;
        invalid_password)
            fail "Invalid username or password."
            ;;
        *)
            fail "Unexpected state after Authentication Code submit: $state"
            ;;
    esac
}

main() {
    command -v agent-browser >/dev/null 2>&1 || fail "agent-browser not found"

    check_salesforce_login_needed

    cleanup_agent_browser

    log "Opening SUSEID..."
    ab_open "$SUSEID_URL"
    wait_page

    local suseid_title snapshot

    suseid_title="$(get_title)"
    snapshot="$(get_snapshot_refs)"

    if [[ "$suseid_title" == "$SUSEID_TITLE" ]]; then
        log "SUSEID is already logged in."
        open_salesforce_from_suseid
        log "SUCCESS"
        exit 0
    fi

    if [[ "$suseid_title" == "$SUSEID_LOGIN_TITLE" ]]; then
        log "SUSEID login is required."
        login_suseid
        open_salesforce_from_suseid
        log "SUCCESS"
        exit 0
    fi

    if find_ref "$snapshot" 'Open "Salesforce"' 'Salesforce' >/dev/null 2>&1; then
        log "Detected Salesforce entry on SUSEID page, treating current session as logged in."
        open_salesforce_from_suseid
        log "SUCCESS"
        exit 0
    fi

    if find_ref "$snapshot" 'Email or Username' 'Email' 'Username' 'Password' 'Not you?' >/dev/null 2>&1; then
        log "Detected SUSEID login form under unexpected title: $suseid_title"
        login_suseid
        open_salesforce_from_suseid
        log "SUCCESS"
        exit 0
    fi

    fail "Unexpected SUSEID page title: $suseid_title"
}

main "$@"