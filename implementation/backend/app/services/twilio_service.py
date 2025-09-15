import os
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
import random
import string
from datetime import datetime, timedelta
from typing import Dict, Optional

class TwilioWhatsAppService:
    def __init__(self):
        self.account_sid = os.getenv('TWILIO_ACCOUNT_SID')
        self.auth_token = os.getenv('TWILIO_AUTH_TOKEN')
        self.messaging_service_sid = os.getenv('TWILIO_MESSAGING_SERVICE_SID', 'MG48114f29890bf47311506150def68d4c')
        self.client = Client(self.account_sid, self.auth_token) if self.account_sid else None
        
        # In-memory storage for OTPs (in production, use Redis or database)
        self.otp_storage: Dict[str, Dict] = {}
    
    def generate_otp(self) -> str:
        """Generate a 6-digit OTP"""
        return ''.join(random.choices(string.digits, k=6))
    
    def send_whatsapp_otp(self, phone_number: str) -> Dict:
        """Send OTP via WhatsApp"""
        if not self.client:
            raise Exception("Twilio client not configured")
        
        # Generate OTP
        otp = self.generate_otp()
        
        # Store OTP with expiration (5 minutes)
        self.otp_storage[phone_number] = {
            'otp': otp,
            'expires_at': datetime.now() + timedelta(minutes=5)
        }
        
        try:
            # Send via WhatsApp
            message = self.client.messages.create(
                body=f'Your Dayly verification code is: {otp}',
                messaging_service_sid=self.messaging_service_sid,
                to=f'whatsapp:{phone_number}'  # WhatsApp format
            )
            
            return {
                'success': True,
                'message_sid': message.sid,
                'expires_in': 300
            }
        except TwilioRestException as e:
            raise Exception(f"Failed to send WhatsApp message: {str(e)}")
    
    def verify_otp(self, phone_number: str, otp: str) -> bool:
        """Verify the OTP"""
        stored = self.otp_storage.get(phone_number)
        
        if not stored:
            return False
        
        # Check expiration
        if datetime.now() > stored['expires_at']:
            del self.otp_storage[phone_number]
            return False
        
        # Check OTP
        if stored['otp'] == otp:
            del self.otp_storage[phone_number]
            return True
        
        return False

# Singleton instance
twilio_service = TwilioWhatsAppService()
