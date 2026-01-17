"""
Logging configuration for data processing jobs
"""

import logging
import sys
import os
from typing import Optional

import structlog


def setup_logger(name: Optional[str] = None, level: Optional[str] = None) -> logging.Logger:
    """
    Set up structured logging
    
    Args:
        name: Logger name (defaults to root logger)
        level: Log level (defaults to INFO or LOG_LEVEL env var)
        
    Returns:
        Configured logger
    """
    # Get log level from environment or parameter
    log_level = level or os.environ.get('LOG_LEVEL', 'INFO')
    log_level = getattr(logging, log_level.upper())
    
    # Configure structlog
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Configure standard logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )
    
    # Get logger
    logger = structlog.get_logger(name)
    
    return logger
