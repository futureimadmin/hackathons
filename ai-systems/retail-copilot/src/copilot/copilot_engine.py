"""
Retail Copilot Engine

Main engine for Microsoft Copilot-like behavior: answers, examples, step-by-step guidance, and references.
"""

import logging
from typing import Dict, List, Optional, Any
from llm.llm_client import LLMClient
from nlp.nl_to_sql import NLToSQLConverter
from conversation.conversation_manager import ConversationManager
from data.athena_client import AthenaClient

logger = logging.getLogger(__name__)


class RetailCopilotEngine:
    """
    Main engine for Retail Copilot functionality.
    
    Provides Microsoft Copilot-like assistance for retail teams, marketing teams,
    and small businesses with answers, examples, step-by-step guidance, and references.
    """
    
    def __init__(
        self,
        llm_client: LLMClient,
        athena_client: AthenaClient,
        conversation_manager: ConversationManager
    ):
        """
        Initialize Retail Copilot engine.
        
        Args:
            llm_client: LLM client for natural language processing
            athena_client: Athena client for data access
            conversation_manager: Conversation manager for history
        """
        self.llm_client = llm_client
        self.athena_client = athena_client
        self.conversation_manager = conversation_manager
        self.nl_to_sql = NLToSQLConverter(llm_client)
    
    def process_query(
        self,
        user_id: str,
        conversation_id: str,
        query: str,
        context: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Process user query and generate response.
        
        Args:
            user_id: User identifier
            conversation_id: Conversation identifier
            query: User query/question
            context: Additional context
            
        Returns:
            Response dictionary with answer, examples, steps, and references
        """
        try:
            # Add user message to conversation
            self.conversation_manager.add_message(
                conversation_id=conversation_id,
                role='user',
                content=query
            )
            
            # Determine query type
            query_type = self._classify_query(query)
            
            # Route to appropriate handler
            if query_type == 'data_query':
                response = self._handle_data_query(conversation_id, query, context)
            elif query_type == 'how_to':
                response = self._handle_how_to_query(conversation_id, query, context)
            elif query_type == 'recommendation':
                response = self._handle_recommendation_query(conversation_id, query, context)
            elif query_type == 'explanation':
                response = self._handle_explanation_query(conversation_id, query, context)
            else:
                response = self._handle_general_query(conversation_id, query, context)
            
            # Add assistant response to conversation
            self.conversation_manager.add_message(
                conversation_id=conversation_id,
                role='assistant',
                content=response['answer'],
                metadata={
                    'query_type': query_type,
                    'has_data': response.get('data') is not None,
                    'has_examples': len(response.get('examples', [])) > 0,
                    'has_steps': len(response.get('steps', [])) > 0
                }
            )
            
            return response
        
        except Exception as e:
            logger.error(f"Error processing query: {str(e)}")
            return {
                'answer': "I apologize, but I encountered an error processing your request. Please try rephrasing your question.",
                'error': str(e)
            }
    
    def _classify_query(self, query: str) -> str:
        """
        Classify query type.
        
        Args:
            query: User query
            
        Returns:
            Query type: 'data_query', 'how_to', 'recommendation', 'explanation', 'general'
        """
        query_lower = query.lower()
        
        # Data queries
        data_keywords = ['show', 'list', 'how many', 'what are', 'find', 'get', 'display', 'count']
        if any(keyword in query_lower for keyword in data_keywords):
            return 'data_query'
        
        # How-to queries
        how_to_keywords = ['how to', 'how do i', 'how can i', 'steps to', 'guide', 'tutorial']
        if any(keyword in query_lower for keyword in how_to_keywords):
            return 'how_to'
        
        # Recommendation queries
        recommendation_keywords = ['recommend', 'suggest', 'should i', 'best way', 'advice']
        if any(keyword in query_lower for keyword in recommendation_keywords):
            return 'recommendation'
        
        # Explanation queries
        explanation_keywords = ['what is', 'explain', 'why', 'difference between', 'meaning of']
        if any(keyword in query_lower for keyword in explanation_keywords):
            return 'explanation'
        
        return 'general'
    
    def _handle_data_query(
        self,
        conversation_id: str,
        query: str,
        context: Optional[Dict]
    ) -> Dict[str, Any]:
        """Handle data-related queries."""
        # Convert NL to SQL
        sql_result = self.nl_to_sql.convert(query, context)
        
        if not sql_result['sql']:
            return {
                'answer': sql_result['explanation'],
                'query_type': 'data_query',
                'sql_generated': False
            }
        
        # Execute SQL query
        try:
            data = self.athena_client.execute_query(sql_result['sql'])
            
            # Generate natural language answer
            answer = self._generate_data_answer(query, data, sql_result['sql'])
            
            return {
                'answer': answer,
                'data': data.to_dict('records') if not data.empty else [],
                'sql': sql_result['sql'],
                'explanation': sql_result['explanation'],
                'query_type': 'data_query',
                'sql_generated': True,
                'examples': self._generate_data_examples(query, data),
                'references': self._generate_references('data_query')
            }
        
        except Exception as e:
            logger.error(f"Error executing SQL: {str(e)}")
            return {
                'answer': f"I generated a query but encountered an error executing it: {str(e)}",
                'sql': sql_result['sql'],
                'error': str(e),
                'query_type': 'data_query'
            }
    
    def _handle_how_to_query(
        self,
        conversation_id: str,
        query: str,
        context: Optional[Dict]
    ) -> Dict[str, Any]:
        """Handle how-to queries with step-by-step guidance."""
        # Get conversation history
        history = self.conversation_manager.format_history_for_llm(conversation_id, limit=5)
        
        # Generate step-by-step guide
        prompt = f"""Provide a step-by-step guide to answer this question: {query}

Format your response as:
1. Brief overview
2. Numbered steps with clear instructions
3. Practical examples
4. Common pitfalls to avoid
5. Additional resources

Focus on retail, eCommerce, and small business contexts."""
        
        response = self.llm_client.generate_response(
            prompt=prompt,
            system_prompt=self._get_copilot_system_prompt(),
            conversation_history=history
        )
        
        # Extract steps
        steps = self._extract_steps(response)
        
        return {
            'answer': response,
            'steps': steps,
            'query_type': 'how_to',
            'examples': self._generate_how_to_examples(query),
            'references': self._generate_references('how_to')
        }
    
    def _handle_recommendation_query(
        self,
        conversation_id: str,
        query: str,
        context: Optional[Dict]
    ) -> Dict[str, Any]:
        """Handle recommendation queries."""
        history = self.conversation_manager.format_history_for_llm(conversation_id, limit=5)
        
        prompt = f"""Provide recommendations for: {query}

Include:
1. Clear recommendation with rationale
2. Pros and cons
3. Practical examples
4. Alternative approaches
5. Implementation tips

Focus on retail, marketing, and small business contexts."""
        
        response = self.llm_client.generate_response(
            prompt=prompt,
            system_prompt=self._get_copilot_system_prompt(),
            conversation_history=history
        )
        
        return {
            'answer': response,
            'query_type': 'recommendation',
            'examples': self._generate_recommendation_examples(query),
            'references': self._generate_references('recommendation')
        }
    
    def _handle_explanation_query(
        self,
        conversation_id: str,
        query: str,
        context: Optional[Dict]
    ) -> Dict[str, Any]:
        """Handle explanation queries."""
        history = self.conversation_manager.format_history_for_llm(conversation_id, limit=5)
        
        prompt = f"""Explain: {query}

Provide:
1. Clear, concise explanation
2. Real-world examples
3. Key concepts and terminology
4. Practical applications
5. Related topics

Use simple language suitable for retail and small business professionals."""
        
        response = self.llm_client.generate_response(
            prompt=prompt,
            system_prompt=self._get_copilot_system_prompt(),
            conversation_history=history
        )
        
        return {
            'answer': response,
            'query_type': 'explanation',
            'examples': self._generate_explanation_examples(query),
            'references': self._generate_references('explanation')
        }
    
    def _handle_general_query(
        self,
        conversation_id: str,
        query: str,
        context: Optional[Dict]
    ) -> Dict[str, Any]:
        """Handle general queries."""
        history = self.conversation_manager.format_history_for_llm(conversation_id, limit=5)
        
        response = self.llm_client.generate_response(
            prompt=query,
            system_prompt=self._get_copilot_system_prompt(),
            conversation_history=history
        )
        
        return {
            'answer': response,
            'query_type': 'general',
            'references': self._generate_references('general')
        }
    
    def _get_copilot_system_prompt(self) -> str:
        """Get system prompt for Microsoft Copilot-like behavior."""
        return """You are Retail Copilot, an AI assistant for retail teams, marketing teams, and small businesses.

Your role is to provide:
1. **Clear Answers**: Direct, actionable responses to questions
2. **Practical Examples**: Real-world examples relevant to retail and eCommerce
3. **Step-by-Step Guidance**: Detailed instructions for complex tasks
4. **References**: Links to relevant resources and documentation

**Communication Style:**
- Professional yet friendly
- Clear and concise
- Avoid jargon unless necessary
- Use bullet points and formatting for readability
- Provide context and rationale for recommendations

**Focus Areas:**
- Inventory management
- Order processing
- Customer analytics
- Product recommendations
- Sales reporting
- Marketing campaigns
- Pricing strategies
- Customer service

**Always:**
- Verify information accuracy
- Provide sources when possible
- Offer alternatives when appropriate
- Ask clarifying questions if needed
- Be helpful and supportive"""
    
    def _generate_data_answer(self, query: str, data, sql: str) -> str:
        """Generate natural language answer from data."""
        if data.empty:
            return "I found no results for your query. The data might not be available or the filters might be too restrictive."
        
        row_count = len(data)
        
        # Generate summary based on query
        summary = f"I found {row_count} result{'s' if row_count != 1 else ''} for your query."
        
        # Add insights if data is small enough
        if row_count <= 5:
            summary += " Here's what I found:\n\n"
            for idx, row in data.iterrows():
                summary += f"- {self._format_row(row)}\n"
        else:
            summary += f" Here are the top results:\n\n"
            for idx, row in data.head(5).iterrows():
                summary += f"- {self._format_row(row)}\n"
            summary += f"\n(Showing 5 of {row_count} results)"
        
        return summary
    
    def _format_row(self, row) -> str:
        """Format a data row for display."""
        parts = []
        for col, val in row.items():
            if val is not None:
                parts.append(f"{col}: {val}")
        return ", ".join(parts[:3])  # Limit to first 3 columns
    
    def _extract_steps(self, response: str) -> List[str]:
        """Extract numbered steps from response."""
        steps = []
        lines = response.split('\n')
        
        for line in lines:
            line = line.strip()
            # Look for numbered steps
            if line and (line[0].isdigit() or line.startswith('-') or line.startswith('•')):
                steps.append(line)
        
        return steps
    
    def _generate_data_examples(self, query: str, data) -> List[Dict]:
        """Generate examples for data queries."""
        return [
            {
                'title': 'View Full Results',
                'description': 'The complete dataset is available in the data section below.'
            },
            {
                'title': 'Export Data',
                'description': 'You can export this data to CSV or Excel for further analysis.'
            }
        ]
    
    def _generate_how_to_examples(self, query: str) -> List[Dict]:
        """Generate examples for how-to queries."""
        return [
            {
                'title': 'Quick Start',
                'description': 'Follow the numbered steps above for a complete guide.'
            }
        ]
    
    def _generate_recommendation_examples(self, query: str) -> List[Dict]:
        """Generate examples for recommendation queries."""
        return [
            {
                'title': 'Best Practice',
                'description': 'Consider the pros and cons listed above when making your decision.'
            }
        ]
    
    def _generate_explanation_examples(self, query: str) -> List[Dict]:
        """Generate examples for explanation queries."""
        return [
            {
                'title': 'Learn More',
                'description': 'Check the references section for additional resources.'
            }
        ]
    
    def _generate_references(self, query_type: str) -> List[Dict]:
        """Generate reference links."""
        references = [
            {
                'title': 'eCommerce Analytics Platform Documentation',
                'url': '/docs/platform-overview',
                'description': 'Complete platform documentation and guides'
            },
            {
                'title': 'Retail Best Practices',
                'url': '/docs/retail-best-practices',
                'description': 'Industry best practices for retail operations'
            }
        ]
        
        if query_type == 'data_query':
            references.append({
                'title': 'Data Query Guide',
                'url': '/docs/data-queries',
                'description': 'Learn how to query and analyze your data'
            })
        
        return references
