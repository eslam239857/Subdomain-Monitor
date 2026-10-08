```bash
#!/bin/bash

# ============================================================
# Subdomain Monitor + Discord Alerts + Live Host Detection
# ============================================================

# Discord Webhook
# Before running:
# export DISCORD_WEBHOOK_URL="YOUR_WEBHOOK_URL"

if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    echo "[!] خطأ: DISCORD_WEBHOOK_URL غير موجود."
    echo "[*] استخدم:"
    echo '    export DISCORD_WEBHOOK_URL="YOUR_WEBHOOK_URL"'
    exit 1
fi

# ============================================================
# File Configuration
# ============================================================

DOMAINS_FILE="domain.txt"
OLD_SUBDOMAINS="subdomains_old.txt"

NEW_SCAN_OUTPUT="subdomains_current_scan.txt"
DIFFERENCE_FILE="new_subdomains_found.txt"

LIVE_FILE="live_subdomains.txt"
DEAD_FILE="dead_subdomains.txt"


# ============================================================
# 1. Check Requirements
# ============================================================

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "[!] Error: $DOMAINS_FILE not found!"
    exit 1
fi

if ! command -v subfinder >/dev/null 2>&1; then
    echo "[!] Error: subfinder is not installed or not in PATH."
    exit 1
fi

if ! command -v httpx >/dev/null 2>&1; then
    echo "[!] Error: httpx is not installed or not in PATH."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "[!] Error: curl is not installed."
    exit 1
fi

if [ ! -f "$OLD_SUBDOMAINS" ]; then
    touch "$OLD_SUBDOMAINS"
    echo "[*] Created $OLD_SUBDOMAINS."
fi


# ============================================================
# 2. Run Subfinder
# ============================================================

echo "[*] Starting Subfinder scan..."

if ! subfinder \
    -dL "$DOMAINS_FILE" \
    -all \
    -silent \
    -o "$NEW_SCAN_OUTPUT"
then
    echo "[!] Subfinder scan failed."
    exit 1
fi

echo "[+] Subfinder scan completed successfully."


# ============================================================
# 3. Find New Subdomains
# ============================================================

echo "[*] Comparing current results with historical results..."

grep -Fvxf "$OLD_SUBDOMAINS" "$NEW_SCAN_OUTPUT" \
    > "$DIFFERENCE_FILE"

NEW_COUNT=$(wc -l < "$DIFFERENCE_FILE" | tr -d ' ')


# ============================================================
# 4. No New Subdomains
# ============================================================

if [ "$NEW_COUNT" -eq 0 ]; then

    echo "[-] No new subdomains found."

    rm -f \
        "$NEW_SCAN_OUTPUT" \
        "$DIFFERENCE_FILE"

    echo "[*] Scan completed."

    exit 0
fi

echo "[+] Found $NEW_COUNT new subdomains!"


# ============================================================
# 5. Run httpx
# ============================================================

echo "[*] Checking live hosts with httpx..."

if ! httpx \
    -l "$DIFFERENCE_FILE" \
    -silent \
    -o "$LIVE_FILE"
then

    echo "[!] httpx scan failed!"
    echo "[!] Results will NOT be classified as dead."

    # Send error notification to Discord

    ERROR_MESSAGE="⚠️ **httpx Scan Failed**

New subdomains were discovered, but the live-host check failed.

📊 New Subdomains: \`$NEW_COUNT\`

The results were NOT classified as Not Live."

    if command -v python3 >/dev/null 2>&1; then

        JSON_PAYLOAD=$(python3 -c '
import json
import sys

message = sys.stdin.read()

print(json.dumps({
    "content": message
}))
' <<< "$ERROR_MESSAGE")

        curl -sS \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$JSON_PAYLOAD" \
            "$DISCORD_WEBHOOK_URL" \
            > /dev/null

    else

        curl -sS \
            -H "Content-Type: application/json" \
            -X POST \
            -d "{\"content\":\"$ERROR_MESSAGE\"}" \
            "$DISCORD_WEBHOOK_URL" \
            > /dev/null

    fi

    rm -f \
        "$NEW_SCAN_OUTPUT" \
        "$DIFFERENCE_FILE" \
        "$LIVE_FILE"

    exit 1
fi


# ============================================================
# 6. Verify httpx Output
# ============================================================

if [ ! -f "$LIVE_FILE" ]; then

    echo "[!] httpx completed but output file was not created."
    echo "[!] Results will NOT be classified as dead."

    rm -f \
        "$NEW_SCAN_OUTPUT" \
        "$DIFFERENCE_FILE"

    exit 1
fi

echo "[+] httpx scan completed successfully."


# ============================================================
# 7. Clean httpx Results
# ============================================================

sed -i '/^[[:space:]]*$/d' "$LIVE_FILE"

sed -E \
    -e 's#^https?://##' \
    -e 's#/.*$##' \
    "$LIVE_FILE" \
    | sort -u > "${LIVE_FILE}.clean"

sort -u "$DIFFERENCE_FILE" > "${DIFFERENCE_FILE}.sorted"


# ============================================================
# 8. Find Not Live Hosts
# ============================================================

grep -Fvxf \
    "${LIVE_FILE}.clean" \
    "${DIFFERENCE_FILE}.sorted" \
    > "$DEAD_FILE"


# ============================================================
# 9. Statistics
# ============================================================

LIVE_COUNT=$(wc -l < "${LIVE_FILE}.clean" | tr -d ' ')
DEAD_COUNT=$(wc -l < "$DEAD_FILE" | tr -d ' ')

echo ""
echo "================================"
echo "          Scan Results"
echo "================================"
echo "[+] New Subdomains : $NEW_COUNT"
echo "[+] Live Hosts     : $LIVE_COUNT"
echo "[-] Not Live       : $DEAD_COUNT"
echo "================================"
echo ""


# ============================================================
# 10. Build Discord Message
# ============================================================

MESSAGE="🚀 **New Subdomains Discovered!**

📊 **Statistics**
New: \`$NEW_COUNT\`
Live: \`$LIVE_COUNT\`
Not Live: \`$DEAD_COUNT\`

🔎 **httpx Status:** \`SUCCESS\`

"


# ============================================================
# 11. Live Hosts
# ============================================================

MESSAGE+="✅ **LIVE HOSTS**\n\`\`\`\n"

LIVE_LINES=0

while IFS= read -r line; do

    [ -z "$line" ] && continue

    MESSAGE+="$line\n"

    LIVE_LINES=$((LIVE_LINES + 1))

    if [ "$LIVE_LINES" -ge 15 ]; then

        if [ "$LIVE_COUNT" -gt 15 ]; then
            MESSAGE+="... and more\n"
        fi

        break
    fi

done < "${LIVE_FILE}.clean"

MESSAGE+="\`\`\`\n"


# ============================================================
# 12. Not Live Hosts
# ============================================================

MESSAGE+="❌ **NOT LIVE**\n\`\`\`\n"

DEAD_LINES=0

while IFS= read -r line; do

    [ -z "$line" ] && continue

    MESSAGE+="$line\n"

    DEAD_LINES=$((DEAD_LINES + 1))

    if [ "$DEAD_LINES" -ge 15 ]; then

        if [ "$DEAD_COUNT" -gt 15 ]; then
            MESSAGE+="... and more\n"
        fi

        break
    fi

done < "$DEAD_FILE"

MESSAGE+="\`\`\`"


# ============================================================
# 13. Send Results to Discord
# ============================================================

echo "[*] Sending results to Discord..."

if command -v python3 >/dev/null 2>&1; then

    JSON_PAYLOAD=$(python3 -c '
import json
import sys

message = sys.stdin.read()

print(json.dumps({
    "content": message
}))
' <<< "$MESSAGE")

    if curl -sS \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$JSON_PAYLOAD" \
        "$DISCORD_WEBHOOK_URL" \
        > /dev/null
    then
        echo "[+] Discord notification sent successfully."
    else
        echo "[!] Failed to send Discord notification."
    fi

else

    if curl -sS \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"content\":\"$MESSAGE\"}" \
        "$DISCORD_WEBHOOK_URL" \
        > /dev/null
    then
        echo "[+] Discord notification sent successfully."
    else
        echo "[!] Failed to send Discord notification."
    fi

fi


# ============================================================
# 14. Update Historical Database
# ============================================================

echo "[*] Updating $OLD_SUBDOMAINS..."

cat "$DIFFERENCE_FILE" >> "$OLD_SUBDOMAINS"

sort -u "$OLD_SUBDOMAINS" -o "$OLD_SUBDOMAINS"

TOTAL_SUBDOMAINS=$(wc -l < "$OLD_SUBDOMAINS" | tr -d ' ')

echo "[+] Total stored subdomains: $TOTAL_SUBDOMAINS"


# ============================================================
# 15. Cleanup
# ============================================================

rm -f \
    "$NEW_SCAN_OUTPUT" \
    "$DIFFERENCE_FILE" \
    "$LIVE_FILE" \
    "${LIVE_FILE}.clean" \
    "$DEAD_FILE" \
    "${DIFFERENCE_FILE}.sorted"


# ============================================================
# Finished
# ============================================================

echo ""
echo "================================"
echo "[+] Scan completed successfully!"
echo "================================"
```
