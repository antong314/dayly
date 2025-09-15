"""
WhatsApp OTP Service using Twilio Verify
Handles WhatsApp-based authentication flow
"""
import os
from typing import Optional, Dict
from twilio.rest import Client
from dotenv import load_dotenv
import logging

load_dotenv('env.local')

logger = logging.getLogger(__name__)


class WhatsAppOTPService:
    def __init__(self):
        self.account_sid = os.getenv('TWILIO_ACCOUNT_SID')
        self.auth_token = os.getenv('TWILIO_AUTH_TOKEN')
        self.verify_service_sid = os.getenv('TWILIO_VERIFY_SERVICE_SID')
        
        if not all([self.account_sid, self.auth_token, self.verify_service_sid]):
            raise ValueError("Missing required Twilio credentials")
            
        self.client = Client(self.account_sid, self.auth_token)
    
    def send_otp(self, phone_number: str) -> Dict[str, any]:
        """Send WhatsApp OTP using Twilio Verify"""
        try:
            verification = self.client.verify.v2 \
                .services(self.verify_service_sid) \
                .verifications \
                .create(
                    to=phone_number,
                    channel='whatsapp'
                )
            
            logger.info(f"WhatsApp OTP sent to {phone_number}, status: {verification.status}")
            
            return {
                "success": True,
                "status": verification.status,
                "valid": verification.valid,
                "expires_in": 600  # 10 minutes default for Twilio Verify
            }
            
        except Exception as e:
            logger.error(f"Failed to send WhatsApp OTP: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def verify_otp(self, phone_number: str, code: str) -> Dict[str, any]:
        """Verify the OTP code"""
        try:
            verification_check = self.client.verify.v2 \
                .services(self.verify_service_sid) \
                .verification_checks \
                .create(
                    to=phone_number,
                    code=code
                )
            
            logger.info(f"OTP verification for {phone_number}: {verification_check.status}")
            
            return {
                "success": verification_check.status == "approved",
                "status": verification_check.status,
                "valid": verification_check.valid
            }
            
        except Exception as e:
            logger.error(f"Failed to verify OTP: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }


# Singleton instance
whatsapp_otp_service = WhatsAppOTPService()
