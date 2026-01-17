"""
LLM Client for Retail Copilot

Provides integration with large language models (GPT-4, Claude, or alternatives)
for natural language understanding and response generation.
"""

import os
import json
import logging
from typing import Dict, List, Optional, Any
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class LLMClient:
    """
    Client for interacting with Large Language Models.
    
    Supports multiple LLM providers:
    - AWS Bedrock (Claude, Titan)
    - OpenAI (GPT-4)
    - Self-hosted models
    """
    
    def __init__(
        self,
        provider: str = 'bedrock',
        model_id: str = 'anthropic.claude-v2',
        region: str = 'us-east-1',
        temperature: float = 0.7,
        max_tokens: int = 2000
    ):
        """
        Initialize LLM client.
        
        Args:
            provider: LLM provider ('bedrock', 'openai', 'self-hosted')
            model_id: Model identifier
            region: AWS region for Bedrock
            temperature: Sampling temperature (0.0-1.0)
            max_tokens: Maximum tokens in response
        """
        self.provider = provider
        self.model_id = model_id
        self.temperature = temperature
        self.max_tokens = max_tokens
        
        if provider == 'bedrock':
            self.client = boto3.client('bedrock-runtime', region_name=region)
        elif provider == 'openai':
            # OpenAI client would be initialized here
            pass
        else:
            logger.warning(f"Unknown provider: {provider}")
    
    def generate_response(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        conversation_history: Optional[List[Dict]] = None
    ) -> str:
        """
        Generate response from LLM.
        
        Args:
            prompt: User prompt/question
            system_prompt: System instructions
            conversation_history: Previous conversation messages
            
        Returns:
            Generated response text
        """
        try:
            if self.provider == 'bedrock':
                return self._generate_bedrock(prompt, system_prompt, conversation_history)
            elif self.provider == 'openai':
                return self._generate_openai(prompt, system_prompt, conversation_history)
            else:
                return self._generate_fallback(prompt)
        
        except Exception as e:
            logger.error(f"Error generating LLM response: {str(e)}")
            return "I apologize, but I'm having trouble processing your request right now. Please try again."
    
    def _generate_bedrock(
        self,
        prompt: str,
        system_prompt: Optional[str],
        conversation_history: Optional[List[Dict]]
    ) -> str:
        """Generate response using AWS Bedrock."""
        try:
            # Build conversation context
            messages = []
            if conversation_history:
                messages.extend(conversation_history)
            
            messages.append({
                "role": "user",
                "content": prompt
            })
            
            # Prepare request body based on model
            if 'claude' in self.model_id.lower():
                body = {
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": self.max_tokens,
                    "temperature": self.temperature,
                    "messages": messages
                }
                
                if system_prompt:
                    body["system"] = system_prompt
            
            else:  # Amazon Titan or other models
                body = {
                    "inputText": prompt,
                    "textGenerationConfig": {
                        "maxTokenCount": self.max_tokens,
                        "temperature": self.temperature,
                        "topP": 0.9
                    }
                }
            
            # Invoke model
            response = self.client.invoke_model(
                modelId=self.model_id,
                body=json.dumps(body)
            )
            
            # Parse response
            response_body = json.loads(response['body'].read())
            
            if 'claude' in self.model_id.lower():
                return response_body['content'][0]['text']
            else:
                return response_body['results'][0]['outputText']
        
        except ClientError as e:
            logger.error(f"Bedrock API error: {str(e)}")
            raise
    
    def _generate_openai(
        self,
        prompt: str,
        system_prompt: Optional[str],
        conversation_history: Optional[List[Dict]]
    ) -> str:
        """Generate response using OpenAI API."""
        # Placeholder for OpenAI integration
        logger.warning("OpenAI integration not implemented")
        return self._generate_fallback(prompt)
    
    def _generate_fallback(self, prompt: str) -> str:
        """Fallback response when LLM is unavailable."""
        return (
            "I'm currently operating in limited mode. "
            "I can help you with basic queries about inventory, orders, and customers. "
            "Please try rephrasing your question or contact support for assistance."
        )
    
    def extract_sql_from_response(self, response: str) -> Optional[str]:
        """
        Extract SQL query from LLM response.
        
        Args:
            response: LLM response text
            
        Returns:
            Extracted SQL query or None
        """
        # Look for SQL code blocks
        if '```sql' in response.lower():
            start = response.lower().find('```sql') + 6
            end = response.find('```', start)
            if end > start:
                return response[start:end].strip()
        
        # Look for SELECT statements
        if 'SELECT' in response.upper():
            lines = response.split('\n')
            sql_lines = []
            in_sql = False
            
            for line in lines:
                if 'SELECT' in line.upper():
                    in_sql = True
                
                if in_sql:
                    sql_lines.append(line)
                    
                    if ';' in line:
                        break
            
            if sql_lines:
                return '\n'.join(sql_lines).strip()
        
        return None
    
    def validate_sql_safety(self, sql: str) -> bool:
        """
        Validate SQL query for safety.
        
        Args:
            sql: SQL query to validate
            
        Returns:
            True if safe, False otherwise
        """
        sql_upper = sql.upper()
        
        # Disallow dangerous operations
        dangerous_keywords = [
            'DROP', 'DELETE', 'TRUNCATE', 'ALTER', 'CREATE',
            'INSERT', 'UPDATE', 'GRANT', 'REVOKE', 'EXEC'
        ]
        
        for keyword in dangerous_keywords:
            if keyword in sql_upper:
                logger.warning(f"Dangerous SQL keyword detected: {keyword}")
                return False
        
        # Require SELECT
        if 'SELECT' not in sql_upper:
            logger.warning("SQL query must be a SELECT statement")
            return False
        
        return True
