"""
Business rule validation for data quality
"""

from typing import List, Dict, Any
import pandas as pd

from src.utils.logger import setup_logger
from src.validators.schema_validator import ValidationResult

logger = setup_logger(__name__)


class BusinessRuleValidator:
    """Validates business rules on data"""
    
    def __init__(self):
        self.rules = []
    
    def validate(self, df: pd.DataFrame, table_name: str) -> ValidationResult:
        """
        Validate business rules
        
        Args:
            df: DataFrame to validate
            table_name: Name of the table
            
        Returns:
            ValidationResult with errors and warnings
        """
        result = ValidationResult()
        
        # Apply table-specific rules
        if table_name == 'orders':
            self._validate_orders(df, result)
        elif table_name == 'order_items':
            self._validate_order_items(df, result)
        elif table_name == 'inventory':
            self._validate_inventory(df, result)
        elif table_name == 'products':
            self._validate_products(df, result)
        elif table_name == 'payments':
            self._validate_payments(df, result)
        
        logger.info(f"Business rule validation completed for {table_name}: passed={result.passed}")
        
        return result
    
    def _validate_orders(self, df: pd.DataFrame, result: ValidationResult):
        """Validate orders table business rules"""
        
        # Rule: Order total should be positive
        if 'total' in df.columns:
            negative_totals = (df['total'] < 0).sum()
            if negative_totals > 0:
                result.add_error(f"Found {negative_totals} orders with negative total")
        
        # Rule: Order date should not be in the future
        if 'order_date' in df.columns:
            df['order_date'] = pd.to_datetime(df['order_date'], errors='coerce')
            future_dates = (df['order_date'] > pd.Timestamp.now()).sum()
            if future_dates > 0:
                result.add_warning(f"Found {future_dates} orders with future dates")
        
        # Rule: Subtotal + tax + shipping should equal total (with tolerance)
        if all(col in df.columns for col in ['subtotal', 'tax', 'shipping_cost', 'total']):
            calculated_total = df['subtotal'] + df['tax'] + df['shipping_cost']
            tolerance = 0.01
            mismatch = (abs(calculated_total - df['total']) > tolerance).sum()
            if mismatch > 0:
                result.add_error(f"Found {mismatch} orders where subtotal + tax + shipping != total")
    
    def _validate_order_items(self, df: pd.DataFrame, result: ValidationResult):
        """Validate order_items table business rules"""
        
        # Rule: Quantity should be positive
        if 'quantity' in df.columns:
            non_positive = (df['quantity'] <= 0).sum()
            if non_positive > 0:
                result.add_error(f"Found {non_positive} order items with non-positive quantity")
        
        # Rule: Unit price should be non-negative
        if 'unit_price' in df.columns:
            negative_prices = (df['unit_price'] < 0).sum()
            if negative_prices > 0:
                result.add_error(f"Found {negative_prices} order items with negative unit price")
        
        # Rule: Total should equal quantity * unit_price - discount
        if all(col in df.columns for col in ['quantity', 'unit_price', 'discount', 'total']):
            calculated_total = df['quantity'] * df['unit_price'] - df['discount']
            tolerance = 0.01
            mismatch = (abs(calculated_total - df['total']) > tolerance).sum()
            if mismatch > 0:
                result.add_error(f"Found {mismatch} order items where quantity * unit_price - discount != total")
    
    def _validate_inventory(self, df: pd.DataFrame, result: ValidationResult):
        """Validate inventory table business rules"""
        
        # Rule: Quantity should be non-negative
        if 'quantity' in df.columns:
            negative_qty = (df['quantity'] < 0).sum()
            if negative_qty > 0:
                result.add_error(f"Found {negative_qty} inventory records with negative quantity")
        
        # Rule: Reserved quantity should not exceed total quantity
        if all(col in df.columns for col in ['quantity', 'reserved_quantity']):
            over_reserved = (df['reserved_quantity'] > df['quantity']).sum()
            if over_reserved > 0:
                result.add_error(f"Found {over_reserved} inventory records where reserved > total quantity")
        
        # Rule: Available quantity should equal quantity - reserved_quantity
        if all(col in df.columns for col in ['quantity', 'reserved_quantity', 'available_quantity']):
            calculated_available = df['quantity'] - df['reserved_quantity']
            mismatch = (df['available_quantity'] != calculated_available).sum()
            if mismatch > 0:
                result.add_warning(f"Found {mismatch} inventory records where available != quantity - reserved")
    
    def _validate_products(self, df: pd.DataFrame, result: ValidationResult):
        """Validate products table business rules"""
        
        # Rule: Price should be positive
        if 'price' in df.columns:
            non_positive = (df['price'] <= 0).sum()
            if non_positive > 0:
                result.add_error(f"Found {non_positive} products with non-positive price")
        
        # Rule: Cost should not exceed price (warning only)
        if all(col in df.columns for col in ['cost', 'price']):
            cost_exceeds_price = (df['cost'] > df['price']).sum()
            if cost_exceeds_price > 0:
                result.add_warning(f"Found {cost_exceeds_price} products where cost > price")
        
        # Rule: Weight should be positive if present
        if 'weight' in df.columns:
            negative_weight = (df['weight'] < 0).sum()
            if negative_weight > 0:
                result.add_error(f"Found {negative_weight} products with negative weight")
    
    def _validate_payments(self, df: pd.DataFrame, result: ValidationResult):
        """Validate payments table business rules"""
        
        # Rule: Payment amount should be positive
        if 'amount' in df.columns:
            non_positive = (df['amount'] <= 0).sum()
            if non_positive > 0:
                result.add_error(f"Found {non_positive} payments with non-positive amount")
        
        # Rule: Payment date should not be in the future
        if 'payment_date' in df.columns:
            df['payment_date'] = pd.to_datetime(df['payment_date'], errors='coerce')
            future_dates = (df['payment_date'] > pd.Timestamp.now()).sum()
            if future_dates > 0:
                result.add_warning(f"Found {future_dates} payments with future dates")
        
        # Rule: Completed payments should have transaction ID
        if all(col in df.columns for col in ['payment_status', 'transaction_id']):
            completed_no_txn = ((df['payment_status'] == 'completed') & (df['transaction_id'].isnull())).sum()
            if completed_no_txn > 0:
                result.add_warning(f"Found {completed_no_txn} completed payments without transaction ID")


def validate_referential_integrity(
    df: pd.DataFrame,
    foreign_keys: Dict[str, tuple],
    reference_data: Dict[str, pd.DataFrame]
) -> ValidationResult:
    """
    Validate referential integrity (foreign key constraints)
    
    Args:
        df: DataFrame to validate
        foreign_keys: Dictionary mapping column names to (ref_table, ref_column) tuples
        reference_data: Dictionary of reference DataFrames
        
    Returns:
        ValidationResult with errors
    """
    result = ValidationResult()
    
    for fk_column, (ref_table, ref_column) in foreign_keys.items():
        if fk_column not in df.columns:
            continue
        
        if ref_table not in reference_data:
            result.add_warning(f"Reference table '{ref_table}' not available for FK validation")
            continue
        
        ref_df = reference_data[ref_table]
        
        if ref_column not in ref_df.columns:
            result.add_warning(f"Reference column '{ref_column}' not found in '{ref_table}'")
            continue
        
        # Get valid reference values
        valid_values = set(ref_df[ref_column].dropna().unique())
        
        # Check for invalid foreign keys
        fk_values = df[fk_column].dropna()
        invalid_fks = ~fk_values.isin(valid_values)
        invalid_count = invalid_fks.sum()
        
        if invalid_count > 0:
            result.add_error(
                f"Column '{fk_column}' has {invalid_count} values not found in '{ref_table}.{ref_column}'"
            )
            result.add_stat(f'{fk_column}_invalid_fk_count', int(invalid_count))
    
    return result
