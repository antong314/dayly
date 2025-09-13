#!/bin/bash

# Twilio credentials
TWILIO_ACCOUNT_SID="AC..."  # Replace with your Account SID
TWILIO_AUTH_TOKEN="your-auth-token-here"  # Replace with your actual auth token
TWILIO_MESSAGING_SERVICE_SID="MG..."  # Replace with your Messaging Service SID

# Phone number to send to
TO_NUMBER="+1234567890"  # Replace with your phone number

echo "Testing Twilio API directly..."
echo "================================"

# Test sending SMS via Twilio API
curl -X POST https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json \
--data-urlencode "MessagingServiceSid=$TWILIO_MESSAGING_SERVICE_SID" \
--data-urlencode "To=$TO_NUMBER" \
--data-urlencode "Body=Test from Dayly setup" \
-u $TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN

echo -e "\n\nIf this fails with 401, the auth token is wrong."
echo "If it fails with 400, check the messaging service configuration."
echo "If it succeeds, the issue is with how Supabase is sending the credentials."
