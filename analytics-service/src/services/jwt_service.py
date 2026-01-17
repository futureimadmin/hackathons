"""
JWT Service

Handles JWT token verification for authentication.
"""

import jwt
import boto3
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)


class JWTService:
    """Service for JWT token verification."""
    
    def __init__(self, secret_name: str):
        """
        Initialize JWT service.
        
        Args:
            secret_name: AWS Secrets Manager secret name for JWT secret
        """
        self.secret_name = secret_name
        self._secret = None
        self.secrets_client = boto3.client('secretsmanager')
    
    def _get_secret(self) -> str:
        """
        Get JWT secret from AWS Secrets Manager.
        
        Returns:
            JWT secret string
        """
        if self._secret is None:
            try:
                response = self.secrets_client.get_secret_value(SecretId=self.secret_name)
                self._secret = response['SecretString']
                logger.info("JWT secret loaded from Secrets Manager")
            except Exception as e:
                logger.error(f"Error loading JWT secret: {str(e)}", exc_info=True)
                raise
        
        return self._secret
    
    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Verify JWT token and extract claims.
        
        Args:
            token: JWT token string
            
        Returns:
            Dictionary of claims if valid, None otherwise
        """
        try:
            secret = self._get_secret()
            
            # Decode and verify token
            claims = jwt.decode(
                token,
                secret,
                algorithms=['HS256'],
                options={'verify_exp': True}
            )
            
            logger.info(f"Token verified for user: {claims.get('userId')}")
            return claims
            
        except jwt.ExpiredSignatureError:
            logger.warning("Token has expired")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid token: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Error verifying token: {str(e)}", exc_info=True)
            return None
