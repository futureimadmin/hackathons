"""
Compliance checking for PCI DSS and other regulations
"""

import re
from typing import List, Dict, Any
import pandas as pd

from src.utils.logger import setup_logger
from src.validators.schema_validator import ValidationResult

logger = setup_logger(__name__)


class ComplianceChecker:
    """Checks data compliance with regulations"""
    
    def __init__(self, config: Any):
        self.config = config
        self.pci_dss_enabled = config.get('compliance.pci_dss_enabled', True)
        self.mask_credit_cards = config.get('compliance.mask_credit_cards', True)
    
    def check_compliance(self, df: pd.DataFrame, table_name: str) -> ValidationResult:
        """
        Check compliance rules
        
        Args:
            df: DataFrame to check
            table_name: Name of the table
            
        Returns:
            ValidationResult with compliance issues
        """
        result = ValidationResult()
        
        # PCI DSS compliance
        if self.pci_dss_enabled:
            self._check_pci_dss(df, table_name, result)
        
        # Check for PII fields
        self._check_pii(df, table_name, result)
        
        logger.info(f"Compliance check completed for {table_name}: passed={result.passed}")
        
        return result
    
    def _check_pci_dss(self, df: pd.DataFrame, table_name: str, result: ValidationResult):
        """Check PCI DSS compliance for payment data"""
        
        # Check for credit card numbers
        credit_card_columns = ['card_number', 'credit_card', 'cc_number', 'payment_card']
        
        for col in credit_card_columns:
            if col in df.columns:
                # Check if credit cards are masked
                unmasked = self._find_unmasked_credit_cards(df[col])
                
                if unmasked > 0:
                    result.add_error(f"Found {unmasked} unmasked credit card numbers in column '{col}'")
                    result.add_stat(f'{col}_unmasked_count', int(unmasked))
        
        # Check for CVV numbers (should never be stored)
        cvv_columns = ['cvv', 'cvv2', 'cvc', 'security_code']
        
        for col in cvv_columns:
            if col in df.columns:
                non_null = df[col].notna().sum()
                if non_null > 0:
                    result.add_error(f"Column '{col}' contains CVV data which should not be stored (PCI DSS violation)")
    
    def _check_pii(self, df: pd.DataFrame, table_name: str, result: ValidationResult):
        """Check for PII fields that may need special handling"""
        
        pii_columns = {
            'ssn': 'Social Security Number',
            'social_security_number': 'Social Security Number',
            'drivers_license': 'Driver\'s License',
            'passport_number': 'Passport Number',
            'tax_id': 'Tax ID'
        }
        
        for col, description in pii_columns.items():
            if col in df.columns:
                non_null = df[col].notna().sum()
                if non_null > 0:
                    result.add_warning(f"Column '{col}' contains {description} - ensure proper encryption/masking")
    
    def _find_unmasked_credit_cards(self, series: pd.Series) -> int:
        """
        Find unmasked credit card numbers
        
        A masked credit card should show only last 4 digits: ****1234 or XXXX1234
        
        Args:
            series: Pandas Series with potential credit card data
            
        Returns:
            Count of unmasked credit cards
        """
        # Pattern for unmasked credit cards (13-19 digits)
        cc_pattern = re.compile(r'^\d{13,19}$')
        
        # Pattern for masked credit cards
        masked_pattern = re.compile(r'^[\*X]{4,15}\d{4}$')
        
        unmasked_count = 0
        
        for value in series.dropna():
            value_str = str(value).replace(' ', '').replace('-', '')
            
            # Check if it looks like a credit card number
            if cc_pattern.match(value_str):
                # Check if it's masked
                if not masked_pattern.match(value_str):
                    unmasked_count += 1
        
        return unmasked_count
    
    def mask_sensitive_fields(self, df: pd.DataFrame, table_name: str) -> pd.DataFrame:
        """
        Mask sensitive fields in DataFrame
        
        Args:
            df: DataFrame to mask
            table_name: Name of the table
            
        Returns:
            DataFrame with masked sensitive fields
        """
        df = df.copy()
        
        if not self.mask_credit_cards:
            return df
        
        # Mask credit card numbers
        credit_card_columns = ['card_number', 'credit_card', 'cc_number', 'payment_card']
        
        for col in credit_card_columns:
            if col in df.columns:
                df[col] = df[col].apply(self._mask_credit_card)
        
        # Remove CVV columns entirely
        cvv_columns = ['cvv', 'cvv2', 'cvc', 'security_code']
        for col in cvv_columns:
            if col in df.columns:
                df = df.drop(columns=[col])
                logger.warning(f"Dropped column '{col}' containing CVV data")
        
        logger.info(f"Masked sensitive fields in {table_name}")
        
        return df
    
    def _mask_credit_card(self, value: Any) -> str:
        """
        Mask credit card number showing only last 4 digits
        
        Args:
            value: Credit card number
            
        Returns:
            Masked credit card number
        """
        if pd.isna(value):
            return value
        
        value_str = str(value).replace(' ', '').replace('-', '')
        
        # Check if it looks like a credit card number
        if re.match(r'^\d{13,19}$', value_str):
            # Mask all but last 4 digits
            return '*' * (len(value_str) - 4) + value_str[-4:]
        
        return value
