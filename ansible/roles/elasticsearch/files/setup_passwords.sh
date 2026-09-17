#!/bin/bash

# Elasticsearch Password Setup Script
# This script is invoked by Ansible and must never block forever.

set -euo pipefail

ELASTICSEARCH_HOST="${ELASTICSEARCH_HOST:-127.0.0.1}"
ELASTICSEARCH_PORT="${ELASTICSEARCH_PORT:-9200}"
NEW_PASSWORD="${ELASTICSEARCH_PASSWORD:-elastic}"
EXPECT_TIMEOUT="${EXPECT_TIMEOUT:-120}"

ES_URL="http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT"

echo "=== Elasticsearch Password Bootstrap ==="
echo "Host: $ELASTICSEARCH_HOST  Port: $ELASTICSEARCH_PORT  URL: $ES_URL"

# --- Step 1: Wait for HTTP to be reachable ---
echo ""
echo "--- Step 1: Checking Elasticsearch HTTP reachability ---"
for i in {1..30}; do
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$ES_URL/_cluster/health" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        echo "✓ Elasticsearch HTTP is reachable (code=$http_code)"
        break
    fi
    echo "  attempt $i/30 — last_code=$http_code"
    sleep 2
done

http_code=$(curl -s -o /dev/null -w "%{http_code}" "$ES_URL/_cluster/health" 2>/dev/null || echo "000")
if [ "$http_code" != "200" ] && [ "$http_code" != "401" ]; then
    echo "✗ Elasticsearch HTTP is not reachable (code=$http_code) — cannot set passwords"
    exit 1
fi

# --- Step 2: Check if passwords are already set ---
echo ""
echo "--- Step 2: Checking if elastic user can already authenticate ---"
auth_response=$(curl -sS -u "elastic:$NEW_PASSWORD" "$ES_URL/_security/_authenticate" 2>/dev/null || echo "")
auth_username=$(echo "$auth_response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4 || echo "")
echo "  auth response username='$auth_username'"

if [ "$auth_username" = "elastic" ]; then
    echo "✓ Passwords already set — nothing to do"
    exit 0
fi

echo "  Passwords not set yet, proceeding to bootstrap..."

# --- Step 3: Run elasticsearch-setup-passwords via expect ---
echo ""
echo "--- Step 3: Running elasticsearch-setup-passwords interactive ---"
echo "  expect timeout=${EXPECT_TIMEOUT}s"

cd /usr/share/elasticsearch

EXPECT_SCRIPT=$(mktemp /tmp/es_pw_expect.XXXXXX)
cat > "$EXPECT_SCRIPT" <<'EXPECT_END'
log_user 1
set timeout [lindex $argv 0]
set pw      [lindex $argv 1]

puts ">>> spawning elasticsearch-setup-passwords interactive"
spawn bin/elasticsearch-setup-passwords interactive

puts ">>> waiting for y/N confirmation prompt"
expect {
    "Please confirm that you would like to continue*y/N*" {
        puts ">>> got confirmation prompt, sending y"
        send "y\r"
    }
    timeout {
        puts ">>> TIMEOUT waiting for confirmation prompt"
        exit 1
    }
    eof {
        puts ">>> EOF before confirmation prompt"
        exit 1
    }
}

foreach user {elastic apm_system kibana_system logstash_system beats_system remote_monitoring_user} {
    puts ">>> waiting for Enter password for \[$user\]"
    expect {
        "Enter password for*$user*:" {
            puts ">>> sending password for $user"
            send "$pw\r"
        }
        timeout {
            puts ">>> TIMEOUT waiting for Enter password for $user"
            exit 1
        }
        eof {
            puts ">>> EOF waiting for Enter password for $user"
            exit 1
        }
    }

    puts ">>> waiting for Reenter password for \[$user\]"
    expect {
        "Reenter password for*$user*:" {
            puts ">>> sending reenter password for $user"
            send "$pw\r"
        }
        timeout {
            puts ">>> TIMEOUT waiting for Reenter password for $user"
            exit 1
        }
        eof {
            puts ">>> EOF waiting for Reenter password for $user"
            exit 1
        }
    }
}

puts ">>> waiting for eof"
expect eof
puts ">>> done"
EXPECT_END

echo "  Running expect script: $EXPECT_SCRIPT"
expect "$EXPECT_SCRIPT" "$EXPECT_TIMEOUT" "$NEW_PASSWORD"
rc=$?
rm -f "$EXPECT_SCRIPT"

echo ""
if [ $rc -ne 0 ]; then
    echo "✗ expect exited with code $rc"
    exit $rc
fi

# --- Step 4: Verify ---
echo "--- Step 4: Verifying passwords were set ---"
auth_response=$(curl -sS -u "elastic:$NEW_PASSWORD" "$ES_URL/_security/_authenticate" 2>/dev/null || echo "")
auth_username=$(echo "$auth_response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ "$auth_username" = "elastic" ]; then
    echo "✓ Password bootstrap successful — elastic user authenticated"
else
    echo "✗ Password bootstrap may have failed — auth check returned: $auth_response"
    exit 1
fi
