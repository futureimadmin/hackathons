"""
Configuration management for data processing jobs
"""

import os
import json
from typing import Dict, Any, Optional
from pathlib import Path


class Config:
    """Configuration container"""
    
    def __init__(self, config_dict: Dict[str, Any]):
        self._config = config_dict
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value"""
        keys = key.split('.')
        value = self._config
        
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
                if value is None:
                    return default
            else:
                return default
        
        return value
    
    def __getitem__(self, key: str) -> Any:
        """Get configuration value using dict syntax"""
        return self.get(key)


def load_config(config_path: Optional[str] = None) -> Config:
    """
    Load configuration from file or environment
    
    Args:
        config_path: Path to configuration file (optional)
        
    Returns:
        Config object
    """
    # Default configuration
    config = {
        'aws': {
            'region': os.environ.get('AWS_DEFAULT_REGION', 'us-east-1'),
            'account_id': os.environ.get('AWS_ACCOUNT_ID', ''),
        },
        'processing': {
            'batch_size': int(os.environ.get('BATCH_SIZE', '10000')),
            'max_retries': int(os.environ.get('MAX_RETRIES', '3')),
            'retry_delay': int(os.environ.get('RETRY_DELAY', '5')),
        },
        'validation': {
            'enabled': os.environ.get('VALIDATION_ENABLED', 'true').lower() == 'true',
            'strict_mode': os.environ.get('STRICT_MODE', 'false').lower() == 'true',
        },
        'deduplication': {
            'enabled': os.environ.get('DEDUPLICATION_ENABLED', 'true').lower() == 'true',
            'timestamp_column': os.environ.get('TIMESTAMP_COLUMN', 'dms_timestamp'),
        },
        'compliance': {
            'pci_dss_enabled': os.environ.get('PCI_DSS_ENABLED', 'true').lower() == 'true',
            'mask_credit_cards': os.environ.get('MASK_CREDIT_CARDS', 'true').lower() == 'true',
        },
        'logging': {
            'level': os.environ.get('LOG_LEVEL', 'INFO'),
            'format': os.environ.get('LOG_FORMAT', 'json'),
        }
    }
    
    # Load from file if provided
    if config_path:
        config_file = Path(config_path)
        if config_file.exists():
            with open(config_file, 'r') as f:
                file_config = json.load(f)
                # Merge file config with defaults
                config.update(file_config)
    
    # Load from environment variable
    config_json = os.environ.get('CONFIG_JSON')
    if config_json:
        env_config = json.loads(config_json)
        config.update(env_config)
    
    return Config(config)
