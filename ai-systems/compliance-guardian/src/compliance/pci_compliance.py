"""
PCI DSS Compliance Module

Validates payment data handling and ensures PCI DSS compliance.
"""

import re
import pandas as pd
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)


class PCIComplianceChecker:
    """
    Validates PCI DSS compliance for payment data handling.
    
    PCI DSS (Payment Card Industry Data Security Standard) requirements:
    - Protect cardholder data
    - Maintain secure systems
    - Implement strong access control
    - Monitor and test networks
    - Maintain information security policy
    """
    
    def __init__(self):
        self.card_patterns = {
            'visa': re.compile(r'^4[0-9]{12}(?:[0-9]{3})?$'),
            'mastercard': re.compile(r'^5[1-5][0-9]{14}$'),
            'amex': re.compile(r'^3[47][0-9]{13}$'),
            'discover': re.compile(r'^6(?:011|5[0-9]{2})[0-9]{12}$')
        }
    
    def mask_card_number(self, card_number: str) -> str:
        """
        Mask credit card number (PCI DSS Requirement 3.3).
        
        Shows only first 6 and last 4 digits.
        
        Args:
            card_number: Full credit card number
            
        Returns:
            Masked card number
        """
        if not card_number or len(card_number) < 13:
            return "****"
        
        # Remove spaces and dashes
        card_number = re.sub(r'[\s-]', '', str(card_number))
        
        if len(card_number) < 13:
            return "****"
        
        # Show first 6 and last 4 digits
        masked = card_number[:6] + '*' * (len(card_number) - 10) + card_number[-4:]
        
        return masked
    
    def mask_cvv(self, cvv: str) -> str:
        """
        Mask CVV (PCI DSS Requirement 3.2).
        
        CVV should never be stored after authorization.
        
        Args:
            cvv: CVV code
            
        Returns:
            Masked CVV
        """
        return "***"
    
    def validate_card_number(self, card_number: str) -> Dict:
        """
        Validate credit card number using Luhn algorithm.
        
        Args:
            card_number: Credit card number to validate
            
        Returns:
            Dictionary with validation results
        """
        try:
            # Remove spaces and dashes
            card_number = re.sub(r'[\s-]', '', str(card_number))
            
            # Check if it's all digits
            if not card_number.isdigit():
                return {
                    'valid': False,
                    'card_type': None,
                    'error': 'Card number must contain only digits'
                }
            
            # Check length
            if len(card_number) < 13 or len(card_number) > 19:
                return {
                    'valid': False,
                    'card_type': None,
                    'error': 'Invalid card number length'
                }
            
            # Identify card type
            card_type = None
            for card_name, pattern in self.card_patterns.items():
                if pattern.match(card_number):
                    card_type = card_name
                    break
            
            # Luhn algorithm validation
            def luhn_check(card_num):
                digits = [int(d) for d in card_num]
                checksum = 0
                
                # Double every second digit from right to left
                for i in range(len(digits) - 2, -1, -2):
                    digits[i] *= 2
                    if digits[i] > 9:
                        digits[i] -= 9
                
                checksum = sum(digits)
                return checksum % 10 == 0
            
            is_valid = luhn_check(card_number)
            
            return {
                'valid': is_valid,
                'card_type': card_type,
                'masked_number': self.mask_card_number(card_number)
            }
            
        except Exception as e:
            logger.error(f"Error validating card number: {str(e)}")
            return {
                'valid': False,
                'card_type': None,
                'error': str(e)
            }
    
    def check_data_encryption(self, data: pd.DataFrame) -> Dict:
        """
        Check if sensitive data is properly encrypted (PCI DSS Requirement 3.4).
        
        Args:
            data: DataFrame with payment data
            
        Returns:
            Dictionary with encryption compliance status
        """
        issues = []
        
        # Check for unmasked card numbers
        if 'card_number' in data.columns:
            unmasked = data['card_number'].apply(
                lambda x: len(str(x).replace('*', '')) > 10 if pd.notna(x) else False
            )
            if unmasked.any():
                issues.append(f"Found {unmasked.sum()} unmasked card numbers")
        
        # Check for stored CVV
        if 'cvv' in data.columns:
            stored_cvv = data['cvv'].notna()
            if stored_cvv.any():
                issues.append(f"Found {stored_cvv.sum()} stored CVV codes (PCI DSS violation)")
        
        # Check for plaintext PINs
        if 'pin' in data.columns:
            stored_pins = data['pin'].notna()
            if stored_pins.any():
                issues.append(f"Found {stored_pins.sum()} stored PINs (PCI DSS violation)")
        
        return {
            'compliant': len(issues) == 0,
            'issues': issues,
            'total_records': len(data)
        }
    
    def check_access_control(self, access_logs: pd.DataFrame) -> Dict:
        """
        Check access control compliance (PCI DSS Requirement 7).
        
        Args:
            access_logs: DataFrame with access log data
            
        Returns:
            Dictionary with access control compliance status
        """
        issues = []
        
        # Check for unauthorized access attempts
        if 'access_denied' in access_logs.columns:
            denied = access_logs['access_denied'].sum()
            if denied > 0:
                issues.append(f"Found {denied} unauthorized access attempts")
        
        # Check for shared accounts
        if 'user_id' in access_logs.columns:
            user_access = access_logs.groupby('user_id').size()
            suspicious = user_access[user_access > 100]  # More than 100 accesses
            if len(suspicious) > 0:
                issues.append(f"Found {len(suspicious)} users with suspicious access patterns")
        
        # Check for access outside business hours
        if 'access_time' in access_logs.columns:
            access_logs['access_time'] = pd.to_datetime(access_logs['access_time'])
            hour = access_logs['access_time'].dt.hour
            after_hours = ((hour < 6) | (hour >= 22)).sum()
            if after_hours > 0:
                issues.append(f"Found {after_hours} after-hours access attempts")
        
        return {
            'compliant': len(issues) == 0,
            'issues': issues,
            'total_access_attempts': len(access_logs)
        }
    
    def generate_compliance_report(
        self,
        payment_data: pd.DataFrame,
        access_logs: Optional[pd.DataFrame] = None
    ) -> Dict:
        """
        Generate comprehensive PCI DSS compliance report.
        
        Args:
            payment_data: DataFrame with payment transaction data
            access_logs: Optional DataFrame with access logs
            
        Returns:
            Dictionary with compliance report
        """
        try:
            report = {
                'timestamp': pd.Timestamp.now().isoformat(),
                'total_transactions': len(payment_data),
                'compliance_checks': {}
            }
            
            # Check data encryption
            encryption_check = self.check_data_encryption(payment_data)
            report['compliance_checks']['data_encryption'] = encryption_check
            
            # Check access control (if logs provided)
            if access_logs is not None:
                access_check = self.check_access_control(access_logs)
                report['compliance_checks']['access_control'] = access_check
            
            # Overall compliance status
            all_compliant = all(
                check.get('compliant', False)
                for check in report['compliance_checks'].values()
            )
            
            report['overall_compliant'] = all_compliant
            report['compliance_score'] = (
                sum(1 for check in report['compliance_checks'].values() if check.get('compliant', False)) /
                len(report['compliance_checks']) * 100
            )
            
            # Recommendations
            recommendations = []
            if not encryption_check['compliant']:
                recommendations.append("Implement proper data masking for card numbers")
                recommendations.append("Remove stored CVV and PIN data immediately")
            
            if access_logs is not None and not access_check['compliant']:
                recommendations.append("Review and restrict access control policies")
                recommendations.append("Implement multi-factor authentication")
            
            report['recommendations'] = recommendations
            
            logger.info(f"Generated PCI DSS compliance report - Score: {report['compliance_score']:.1f}%")
            
            return report
            
        except Exception as e:
            logger.error(f"Error generating compliance report: {str(e)}")
            raise
    
    def sanitize_payment_data(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Sanitize payment data to ensure PCI DSS compliance.
        
        Args:
            data: DataFrame with payment data
            
        Returns:
            DataFrame with sanitized data
        """
        sanitized = data.copy()
        
        # Mask card numbers
        if 'card_number' in sanitized.columns:
            sanitized['card_number'] = sanitized['card_number'].apply(self.mask_card_number)
        
        # Remove CVV
        if 'cvv' in sanitized.columns:
            sanitized['cvv'] = self.mask_cvv(sanitized['cvv'])
        
        # Remove PIN
        if 'pin' in sanitized.columns:
            sanitized = sanitized.drop('pin', axis=1)
        
        # Mask full name (show only initials)
        if 'cardholder_name' in sanitized.columns:
            sanitized['cardholder_name'] = sanitized['cardholder_name'].apply(
                lambda x: ' '.join([word[0] + '.' for word in str(x).split()]) if pd.notna(x) else None
            )
        
        logger.info(f"Sanitized {len(sanitized)} payment records for PCI DSS compliance")
        
        return sanitized
