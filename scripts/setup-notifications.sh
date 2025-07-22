#!/bin/bash

# Setup external notification integrations for Alertmanager
set -e

echo "🔔 Setting up external notification integrations..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 External Notification Setup${NC}"
echo "=================================="
echo ""
echo "This script will help you configure external notification integrations"
echo "for Alertmanager (Slack, Email, PagerDuty)."
echo ""

# Function to get user input
get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

echo -e "${YELLOW}🔗 Slack Integration${NC}"
echo "-------------------"
SLACK_WEBHOOK=$(get_input "Enter your Slack webhook URL" "")
if [ -n "$SLACK_WEBHOOK" ]; then
    echo -e "${GREEN}✅ Slack webhook configured${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping Slack integration${NC}"
fi

echo ""
echo -e "${YELLOW}📧 Email Integration${NC}"
echo "-------------------"
EMAIL_ADDRESS=$(get_input "Enter your email address" "")
EMAIL_PASSWORD=$(get_input "Enter your email app password" "")
if [ -n "$EMAIL_ADDRESS" ] && [ -n "$EMAIL_PASSWORD" ]; then
    echo -e "${GREEN}✅ Email integration configured${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping email integration${NC}"
fi

echo ""
echo -e "${YELLOW}🚨 PagerDuty Integration${NC}"
echo "----------------------"
PAGERDUTY_KEY=$(get_input "Enter your PagerDuty service key" "")
if [ -n "$PAGERDUTY_KEY" ]; then
    echo -e "${GREEN}✅ PagerDuty integration configured${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping PagerDuty integration${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Updating Alertmanager configuration...${NC}"

# Create a temporary file for the updated configuration
TEMP_CONFIG=$(mktemp)

# Update the Alertmanager config with user-provided values
cat > "$TEMP_CONFIG" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: '${SLACK_WEBHOOK:-https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK_URL}'
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alertmanager@your-domain.com'
      smtp_auth_username: '${EMAIL_ADDRESS:-your-email@gmail.com}'
      smtp_auth_password: '${EMAIL_PASSWORD:-your-app-password}'

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'slack-notifications'
      routes:
      - match:
          severity: critical
        receiver: 'pager-duty-critical'
        continue: true
      - match:
          severity: warning
        receiver: 'slack-notifications'

    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - channel: '#alerts'
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'
        send_resolved: true
        icon_url: 'https://avatars3.githubusercontent.com/u/3380462'
        icon_emoji: ':warning:'
        actions:
        - type: button
          text: 'View in Grafana'
          url: '{{ template "slack.grafanaURL" . }}'
        - type: button
          text: 'View in Prometheus'
          url: '{{ template "slack.prometheusURL" . }}'

    - name: 'pager-duty-critical'
      pagerduty_configs:
      - service_key: '${PAGERDUTY_KEY:-YOUR_PAGERDUTY_SERVICE_KEY}'
        description: '{{ template "pagerduty.description" . }}'
        severity: '{{ if eq .CommonAnnotations.severity "critical" }}critical{{ else }}warning{{ end }}'
        client: 'AlertManager'
        client_url: '{{ template "pagerduty.clientURL" . }}'

    - name: 'email-notifications'
      email_configs:
      - to: 'sre-team@your-domain.com'
        send_resolved: true
        headers:
          subject: '{{ template "email.subject" . }}'
        html: '{{ template "email.html" . }}'

    templates:
    - '/etc/alertmanager/template/*.tmpl'
EOF

# Apply the updated configuration
if kubectl apply -f "$TEMP_CONFIG"; then
    echo -e "${GREEN}✅ Alertmanager configuration updated successfully${NC}"
else
    echo -e "${RED}❌ Failed to update Alertmanager configuration${NC}"
    exit 1
fi

# Clean up temporary file
rm "$TEMP_CONFIG"

echo ""
echo -e "${BLUE}🔄 Restarting Alertmanager...${NC}"
kubectl rollout restart deployment/alertmanager -n monitoring

echo ""
echo -e "${GREEN}✅ External notification setup completed!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Test the integrations by triggering a test alert"
echo "2. Verify notifications are received in your configured channels"
echo "3. Customize alert templates as needed"
echo ""
echo -e "${YELLOW}🔗 Useful commands:${NC}"
echo "kubectl get pods -n monitoring"
echo "kubectl logs -f deployment/alertmanager -n monitoring"
echo "kubectl port-forward svc/alertmanager 9093:9093 -n monitoring" 