"""
Schema validation for data quality checks
"""

from typing import Dict, List, Any, Optional
import pandas as pd
import re

from src.utils.logger import setup_logger

logger = setup_logger(__name__)


class ValidationResult:
    """Container for validation results"""
    
    def __init__(self):
        self.passed = True
        self.errors = []
        self.warnings = []
        self.stats = {}
    
    def add_error(self, error: str):
        """Add validation error"""
        self.passed = False
        self.errors.append(error)
        logger.error(f"Validation error: {error}")
    
    def add_warning(self, warning: str):
        """Add validation warning"""
        self.warnings.append(warning)
        logger.warning(f"Validation warning: {warning}")
    
    def add_stat(self, key: str, value: Any):
        """Add validation statistic"""
        self.stats[key] = value


class SchemaValidator:
    """Validates DataFrame schema against expected schema"""
    
    def __init__(self, expected_schema: Optional[Dict[str, Any]] = None):
        """
        Initialize schema validator
        
        Args:
            expected_schema: Dictionary defining expected schema
                {
                    'columns': ['col1', 'col2', ...],
                    'types': {'col1': 'int64', 'col2': 'object', ...},
                    'nullable': {'col1': False, 'col2': True, ...},
                    'ranges': {'col1': {'min': 0, 'max': 100}, ...},
                    'formats': {'email': r'^[\w\.-]+@[\w\.-]+\.\w+$', ...}
                }
        """
        self.expected_schema = expected_schema or {}
    
    def validate(self, df: pd.DataFrame) -> ValidationResult:
        """
        Validate DataFrame against expected schema
        
        Args:
            df: DataFrame to validate
            
        Returns:
            ValidationResult with errors and warnings
        """
        result = ValidationResult()
        
        # Basic stats
        result.add_stat('total_records', len(df))
        result.add_stat('total_columns', len(df.columns))
        
        # Validate columns
        if 'columns' in self.expected_schema:
            self._validate_columns(df, result)
        
        # Validate data types
        if 'types' in self.expected_schema:
            self._validate_types(df, result)
        
        # Validate nullable constraints
        if 'nullable' in self.expected_schema:
            self._validate_nullable(df, result)
        
        # Validate ranges
        if 'ranges' in self.expected_schema:
            self._validate_ranges(df, result)
        
        # Validate formats
        if 'formats' in self.expected_schema:
            self._validate_formats(df, result)
        
        logger.info(f"Schema validation completed: passed={result.passed}, errors={len(result.errors)}, warnings={len(result.warnings)}")
        
        return result
    
    def _validate_columns(self, df: pd.DataFrame, result: ValidationResult):
        """Validate column names"""
        expected_cols = set(self.expected_schema['columns'])
        actual_cols = set(df.columns)
        
        # Check for missing columns
        missing_cols = expected_cols - actual_cols
        if missing_cols:
            result.add_error(f"Missing columns: {missing_cols}")
        
        # Check for extra columns (warning only)
        extra_cols = actual_cols - expected_cols
        if extra_cols:
            result.add_warning(f"Extra columns: {extra_cols}")
        
        result.add_stat('missing_columns', list(missing_cols))
        result.add_stat('extra_columns', list(extra_cols))
    
    def _validate_types(self, df: pd.DataFrame, result: ValidationResult):
        """Validate data types"""
        expected_types = self.expected_schema['types']
        
        for col, expected_type in expected_types.items():
            if col not in df.columns:
                continue
            
            actual_type = str(df[col].dtype)
            
            # Check if types match (allow some flexibility)
            if not self._types_compatible(actual_type, expected_type):
                result.add_error(f"Column '{col}' has type '{actual_type}', expected '{expected_type}'")
    
    def _validate_nullable(self, df: pd.DataFrame, result: ValidationResult):
        """Validate nullable constraints"""
        nullable_rules = self.expected_schema['nullable']
        
        for col, nullable in nullable_rules.items():
            if col not in df.columns:
                continue
            
            null_count = df[col].isnull().sum()
            
            if not nullable and null_count > 0:
                result.add_error(f"Column '{col}' has {null_count} null values but should not be nullable")
            
            result.add_stat(f'{col}_null_count', int(null_count))
    
    def _validate_ranges(self, df: pd.DataFrame, result: ValidationResult):
        """Validate numeric ranges"""
        range_rules = self.expected_schema['ranges']
        
        for col, range_spec in range_rules.items():
            if col not in df.columns:
                continue
            
            # Skip if column is not numeric
            if not pd.api.types.is_numeric_dtype(df[col]):
                continue
            
            min_val = range_spec.get('min')
            max_val = range_spec.get('max')
            
            if min_val is not None:
                below_min = (df[col] < min_val).sum()
                if below_min > 0:
                    result.add_error(f"Column '{col}' has {below_min} values below minimum {min_val}")
            
            if max_val is not None:
                above_max = (df[col] > max_val).sum()
                if above_max > 0:
                    result.add_error(f"Column '{col}' has {above_max} values above maximum {max_val}")
    
    def _validate_formats(self, df: pd.DataFrame, result: ValidationResult):
        """Validate string formats using regex"""
        format_rules = self.expected_schema['formats']
        
        for col, pattern in format_rules.items():
            if col not in df.columns:
                continue
            
            # Skip null values
            non_null = df[col].dropna()
            
            if len(non_null) == 0:
                continue
            
            # Check format
            regex = re.compile(pattern)
            invalid = ~non_null.astype(str).str.match(regex)
            invalid_count = invalid.sum()
            
            if invalid_count > 0:
                result.add_error(f"Column '{col}' has {invalid_count} values not matching format pattern")
                result.add_stat(f'{col}_invalid_format_count', int(invalid_count))
    
    def _types_compatible(self, actual: str, expected: str) -> bool:
        """Check if data types are compatible"""
        # Exact match
        if actual == expected:
            return True
        
        # Integer types
        if expected in ['int', 'int64', 'int32', 'integer']:
            return actual in ['int64', 'int32', 'int16', 'int8']
        
        # Float types
        if expected in ['float', 'float64', 'float32']:
            return actual in ['float64', 'float32', 'float16']
        
        # String types
        if expected in ['str', 'string', 'object']:
            return actual in ['object', 'string']
        
        # Boolean types
        if expected in ['bool', 'boolean']:
            return actual in ['bool', 'boolean']
        
        # Datetime types
        if expected in ['datetime', 'datetime64']:
            return 'datetime' in actual
        
        return False


def get_default_schema(table_name: str) -> Dict[str, Any]:
    """
    Get default schema for common tables
    
    Args:
        table_name: Name of the table
        
    Returns:
        Schema dictionary
    """
    schemas = {
        'customers': {
            'columns': ['customer_id', 'email', 'first_name', 'last_name', 'created_at'],
            'types': {
                'customer_id': 'object',
                'email': 'object',
                'first_name': 'object',
                'last_name': 'object',
                'created_at': 'datetime64'
            },
            'nullable': {
                'customer_id': False,
                'email': False,
                'first_name': False,
                'last_name': False,
                'created_at': False
            },
            'formats': {
                'email': r'^[\w\.-]+@[\w\.-]+\.\w+$'
            }
        },
        'orders': {
            'columns': ['order_id', 'customer_id', 'order_date', 'total', 'order_status'],
            'types': {
                'order_id': 'object',
                'customer_id': 'object',
                'order_date': 'datetime64',
                'total': 'float64',
                'order_status': 'object'
            },
            'nullable': {
                'order_id': False,
                'customer_id': False,
                'order_date': False,
                'total': False,
                'order_status': False
            },
            'ranges': {
                'total': {'min': 0}
            }
        },
        'products': {
            'columns': ['product_id', 'name', 'price', 'category_id'],
            'types': {
                'product_id': 'object',
                'name': 'object',
                'price': 'float64',
                'category_id': 'object'
            },
            'nullable': {
                'product_id': False,
                'name': False,
                'price': False,
                'category_id': True
            },
            'ranges': {
                'price': {'min': 0}
            }
        }
    }
    
    return schemas.get(table_name, {})
