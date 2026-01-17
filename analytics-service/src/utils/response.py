"""
Response Utilities

Helper functions for creating API Gateway responses.
"""

import json
from typing import Dict, Any


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create API Gateway response with CORS headers.
    
    Args:
        status_code: HTTP status code
        body: Response body dictionary
        
    Returns:
        API Gateway response dictionary
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body)
    }


def create_error_response(status_code: int, message: str) -> Dict[str, Any]:
    """
    Create error response.
    
    Args:
        status_code: HTTP status code
        message: Error message
        
    Returns:
        API Gateway error response dictionary
    """
    return create_response(status_code, {
        'error': message,
        'statusCode': status_code
    })
