"""
Conversation Manager for Retail Copilot

Manages conversation history, context, and state across multiple interactions.
"""

import json
import logging
from typing import Dict, List, Optional
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class ConversationManager:
    """
    Manages conversation history and context.
    
    Stores conversations in DynamoDB for persistence across sessions.
    """
    
    def __init__(
        self,
        table_name: str = 'retail-copilot-conversations',
        region: str = 'us-east-1',
        max_history_length: int = 20
    ):
        """
        Initialize conversation manager.
        
        Args:
            table_name: DynamoDB table name for conversations
            region: AWS region
            max_history_length: Maximum messages to keep in history
        """
        self.table_name = table_name
        self.max_history_length = max_history_length
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        
        try:
            self.table = self.dynamodb.Table(table_name)
        except Exception as e:
            logger.warning(f"Could not connect to DynamoDB table: {str(e)}")
            self.table = None
    
    def create_conversation(self, user_id: str, metadata: Optional[Dict] = None) -> str:
        """
        Create a new conversation.
        
        Args:
            user_id: User identifier
            metadata: Additional metadata
            
        Returns:
            Conversation ID
        """
        conversation_id = f"conv-{user_id}-{int(datetime.now().timestamp())}"
        
        conversation = {
            'conversation_id': conversation_id,
            'user_id': user_id,
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
            'messages': [],
            'metadata': metadata or {}
        }
        
        if self.table:
            try:
                self.table.put_item(Item=conversation)
            except ClientError as e:
                logger.error(f"Error creating conversation: {str(e)}")
        
        return conversation_id
    
    def add_message(
        self,
        conversation_id: str,
        role: str,
        content: str,
        metadata: Optional[Dict] = None
    ) -> None:
        """
        Add message to conversation.
        
        Args:
            conversation_id: Conversation identifier
            role: Message role ('user', 'assistant', 'system')
            content: Message content
            metadata: Additional metadata (SQL query, results, etc.)
        """
        message = {
            'role': role,
            'content': content,
            'timestamp': datetime.now().isoformat(),
            'metadata': metadata or {}
        }
        
        if self.table:
            try:
                # Get current conversation
                response = self.table.get_item(Key={'conversation_id': conversation_id})
                
                if 'Item' in response:
                    conversation = response['Item']
                    messages = conversation.get('messages', [])
                    messages.append(message)
                    
                    # Trim history if too long
                    if len(messages) > self.max_history_length:
                        messages = messages[-self.max_history_length:]
                    
                    # Update conversation
                    self.table.update_item(
                        Key={'conversation_id': conversation_id},
                        UpdateExpression='SET messages = :messages, updated_at = :updated_at',
                        ExpressionAttributeValues={
                            ':messages': messages,
                            ':updated_at': datetime.now().isoformat()
                        }
                    )
            
            except ClientError as e:
                logger.error(f"Error adding message: {str(e)}")
    
    def get_conversation(self, conversation_id: str) -> Optional[Dict]:
        """
        Get conversation by ID.
        
        Args:
            conversation_id: Conversation identifier
            
        Returns:
            Conversation data or None
        """
        if not self.table:
            return None
        
        try:
            response = self.table.get_item(Key={'conversation_id': conversation_id})
            return response.get('Item')
        
        except ClientError as e:
            logger.error(f"Error getting conversation: {str(e)}")
            return None
    
    def get_conversation_history(
        self,
        conversation_id: str,
        limit: Optional[int] = None
    ) -> List[Dict]:
        """
        Get conversation message history.
        
        Args:
            conversation_id: Conversation identifier
            limit: Maximum messages to return
            
        Returns:
            List of messages
        """
        conversation = self.get_conversation(conversation_id)
        
        if not conversation:
            return []
        
        messages = conversation.get('messages', [])
        
        if limit:
            messages = messages[-limit:]
        
        return messages
    
    def get_user_conversations(
        self,
        user_id: str,
        limit: int = 10
    ) -> List[Dict]:
        """
        Get all conversations for a user.
        
        Args:
            user_id: User identifier
            limit: Maximum conversations to return
            
        Returns:
            List of conversations
        """
        if not self.table:
            return []
        
        try:
            response = self.table.query(
                IndexName='user_id-index',
                KeyConditionExpression='user_id = :user_id',
                ExpressionAttributeValues={':user_id': user_id},
                Limit=limit,
                ScanIndexForward=False  # Most recent first
            )
            
            return response.get('Items', [])
        
        except ClientError as e:
            logger.error(f"Error getting user conversations: {str(e)}")
            return []
    
    def delete_conversation(self, conversation_id: str) -> bool:
        """
        Delete a conversation.
        
        Args:
            conversation_id: Conversation identifier
            
        Returns:
            True if successful, False otherwise
        """
        if not self.table:
            return False
        
        try:
            self.table.delete_item(Key={'conversation_id': conversation_id})
            return True
        
        except ClientError as e:
            logger.error(f"Error deleting conversation: {str(e)}")
            return False
    
    def format_history_for_llm(
        self,
        conversation_id: str,
        limit: int = 10
    ) -> List[Dict]:
        """
        Format conversation history for LLM input.
        
        Args:
            conversation_id: Conversation identifier
            limit: Maximum messages to include
            
        Returns:
            Formatted message list for LLM
        """
        messages = self.get_conversation_history(conversation_id, limit)
        
        # Format for LLM (role + content)
        formatted = []
        for msg in messages:
            formatted.append({
                'role': msg['role'],
                'content': msg['content']
            })
        
        return formatted
    
    def get_context_summary(self, conversation_id: str) -> str:
        """
        Get a summary of conversation context.
        
        Args:
            conversation_id: Conversation identifier
            
        Returns:
            Context summary string
        """
        conversation = self.get_conversation(conversation_id)
        
        if not conversation:
            return "No previous context."
        
        messages = conversation.get('messages', [])
        
        if not messages:
            return "New conversation."
        
        # Count message types
        user_messages = sum(1 for m in messages if m['role'] == 'user')
        assistant_messages = sum(1 for m in messages if m['role'] == 'assistant')
        
        # Get recent topics (from metadata)
        recent_topics = []
        for msg in messages[-5:]:
            if msg.get('metadata', {}).get('topic'):
                recent_topics.append(msg['metadata']['topic'])
        
        summary_parts = [
            f"Conversation has {len(messages)} messages ({user_messages} from user, {assistant_messages} from assistant)."
        ]
        
        if recent_topics:
            summary_parts.append(f"Recent topics: {', '.join(set(recent_topics))}")
        
        return " ".join(summary_parts)
