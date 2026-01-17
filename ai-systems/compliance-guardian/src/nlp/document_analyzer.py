"""
Document Understanding with NLP

Uses transformer models (BERT/RoBERTa) for document analysis, entity extraction,
and document classification for compliance purposes.
"""

import logging
from typing import Dict, List, Any, Tuple
import pandas as pd
import numpy as np

try:
    from transformers import (
        AutoTokenizer, 
        AutoModelForTokenClassification,
        AutoModelForSequenceClassification,
        pipeline
    )
    import torch
    TRANSFORMERS_AVAILABLE = True
except ImportError:
    TRANSFORMERS_AVAILABLE = False
    logging.warning("Transformers library not available. NLP features will be limited.")

logger = logging.getLogger(__name__)


class DocumentAnalyzer:
    """
    Document understanding and analysis using NLP.
    
    Features:
    - Entity extraction from compliance documents
    - Document type classification
    - Compliance validation
    - Key information extraction
    """
    
    def __init__(self, model_name: str = "distilbert-base-uncased"):
        """
        Initialize document analyzer.
        
        Args:
            model_name: Hugging Face model name for NLP tasks
        """
        self.model_name = model_name
        self.ner_pipeline = None
        self.classifier_pipeline = None
        
        if TRANSFORMERS_AVAILABLE:
            try:
                # Initialize NER pipeline for entity extraction
                self.ner_pipeline = pipeline(
                    "ner",
                    model="dslim/bert-base-NER",
                    aggregation_strategy="simple"
                )
                
                # Initialize classification pipeline for document type
                self.classifier_pipeline = pipeline(
                    "text-classification",
                    model="distilbert-base-uncased-finetuned-sst-2-english"
                )
                
                logger.info(f"Document analyzer initialized with model: {model_name}")
            except Exception as e:
                logger.error(f"Error initializing NLP models: {str(e)}")
                self.ner_pipeline = None
                self.classifier_pipeline = None
        else:
            logger.warning("Transformers not available. Using rule-based fallback.")
    
    def extract_entities(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract named entities from text.
        
        Args:
            text: Input text to analyze
            
        Returns:
            List of entities with type, text, and confidence
        """
        if not text or not isinstance(text, str):
            return []
        
        if self.ner_pipeline:
            try:
                # Use transformer model for entity extraction
                entities = self.ner_pipeline(text)
                
                # Format results
                formatted_entities = []
                for entity in entities:
                    formatted_entities.append({
                        'entity_type': entity['entity_group'],
                        'text': entity['word'],
                        'confidence': float(entity['score']),
                        'start': entity['start'],
                        'end': entity['end']
                    })
                
                return formatted_entities
            
            except Exception as e:
                logger.error(f"Error extracting entities: {str(e)}")
                return self._extract_entities_rule_based(text)
        else:
            # Fallback to rule-based extraction
            return self._extract_entities_rule_based(text)
    
    def _extract_entities_rule_based(self, text: str) -> List[Dict[str, Any]]:
        """
        Rule-based entity extraction fallback.
        
        Args:
            text: Input text
            
        Returns:
            List of entities
        """
        import re
        
        entities = []
        
        # Extract email addresses
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        for match in re.finditer(email_pattern, text):
            entities.append({
                'entity_type': 'EMAIL',
                'text': match.group(),
                'confidence': 1.0,
                'start': match.start(),
                'end': match.end()
            })
        
        # Extract credit card numbers (masked)
        card_pattern = r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'
        for match in re.finditer(card_pattern, text):
            entities.append({
                'entity_type': 'CARD_NUMBER',
                'text': match.group(),
                'confidence': 1.0,
                'start': match.start(),
                'end': match.end()
            })
        
        # Extract dates
        date_pattern = r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'
        for match in re.finditer(date_pattern, text):
            entities.append({
                'entity_type': 'DATE',
                'text': match.group(),
                'confidence': 1.0,
                'start': match.start(),
                'end': match.end()
            })
        
        # Extract amounts
        amount_pattern = r'\$\s?\d+(?:,\d{3})*(?:\.\d{2})?'
        for match in re.finditer(amount_pattern, text):
            entities.append({
                'entity_type': 'AMOUNT',
                'text': match.group(),
                'confidence': 1.0,
                'start': match.start(),
                'end': match.end()
            })
        
        return entities
    
    def classify_document(self, text: str) -> Dict[str, Any]:
        """
        Classify document type.
        
        Args:
            text: Document text
            
        Returns:
            Document classification with type and confidence
        """
        if not text or not isinstance(text, str):
            return {'document_type': 'UNKNOWN', 'confidence': 0.0}
        
        # Rule-based classification based on keywords
        text_lower = text.lower()
        
        # Define document types and keywords
        document_types = {
            'INVOICE': ['invoice', 'bill', 'payment due', 'total amount', 'subtotal'],
            'RECEIPT': ['receipt', 'purchased', 'transaction', 'thank you for your purchase'],
            'CONTRACT': ['agreement', 'contract', 'terms and conditions', 'party', 'hereby'],
            'POLICY': ['policy', 'procedure', 'guidelines', 'compliance', 'regulation'],
            'REPORT': ['report', 'analysis', 'summary', 'findings', 'conclusion'],
            'STATEMENT': ['statement', 'account', 'balance', 'transactions', 'period'],
            'COMPLIANCE_DOC': ['pci dss', 'gdpr', 'compliance', 'audit', 'certification'],
            'FRAUD_ALERT': ['fraud', 'suspicious', 'alert', 'unauthorized', 'investigation']
        }
        
        # Score each document type
        scores = {}
        for doc_type, keywords in document_types.items():
            score = sum(1 for keyword in keywords if keyword in text_lower)
            if score > 0:
                scores[doc_type] = score / len(keywords)
        
        if scores:
            # Get document type with highest score
            best_type = max(scores, key=scores.get)
            confidence = scores[best_type]
            
            return {
                'document_type': best_type,
                'confidence': float(confidence),
                'all_scores': scores
            }
        else:
            return {
                'document_type': 'UNKNOWN',
                'confidence': 0.0,
                'all_scores': {}
            }
    
    def validate_compliance_document(self, text: str, doc_type: str = None) -> Dict[str, Any]:
        """
        Validate compliance document for required elements.
        
        Args:
            text: Document text
            doc_type: Document type (optional, will be inferred if not provided)
            
        Returns:
            Validation results with compliance status
        """
        if not text:
            return {
                'is_compliant': False,
                'missing_elements': ['Document is empty'],
                'validation_score': 0.0
            }
        
        # Classify document if type not provided
        if not doc_type:
            classification = self.classify_document(text)
            doc_type = classification['document_type']
        
        # Define required elements for each document type
        required_elements = {
            'INVOICE': ['invoice number', 'date', 'amount', 'customer', 'payment'],
            'RECEIPT': ['date', 'amount', 'transaction', 'merchant'],
            'CONTRACT': ['parties', 'terms', 'signature', 'date'],
            'POLICY': ['policy', 'effective date', 'scope', 'compliance'],
            'COMPLIANCE_DOC': ['compliance', 'requirements', 'audit', 'certification'],
            'FRAUD_ALERT': ['transaction', 'date', 'amount', 'reason', 'action']
        }
        
        # Get required elements for this document type
        required = required_elements.get(doc_type, [])
        
        if not required:
            return {
                'is_compliant': True,
                'missing_elements': [],
                'validation_score': 1.0,
                'message': f'No specific requirements for document type: {doc_type}'
            }
        
        # Check for required elements
        text_lower = text.lower()
        missing = []
        found = []
        
        for element in required:
            if element.lower() in text_lower:
                found.append(element)
            else:
                missing.append(element)
        
        # Calculate validation score
        validation_score = len(found) / len(required) if required else 1.0
        is_compliant = validation_score >= 0.8  # 80% threshold
        
        return {
            'is_compliant': is_compliant,
            'document_type': doc_type,
            'required_elements': required,
            'found_elements': found,
            'missing_elements': missing,
            'validation_score': float(validation_score)
        }
    
    def analyze_document(self, text: str) -> Dict[str, Any]:
        """
        Comprehensive document analysis.
        
        Args:
            text: Document text
            
        Returns:
            Complete analysis including entities, classification, and validation
        """
        if not text:
            return {
                'error': 'Empty document',
                'entities': [],
                'classification': {'document_type': 'UNKNOWN', 'confidence': 0.0},
                'validation': {'is_compliant': False, 'validation_score': 0.0}
            }
        
        # Extract entities
        entities = self.extract_entities(text)
        
        # Classify document
        classification = self.classify_document(text)
        
        # Validate compliance
        validation = self.validate_compliance_document(text, classification['document_type'])
        
        # Extract key information
        key_info = self._extract_key_information(text, entities)
        
        return {
            'entities': entities,
            'classification': classification,
            'validation': validation,
            'key_information': key_info,
            'text_length': len(text),
            'entity_count': len(entities)
        }
    
    def _extract_key_information(self, text: str, entities: List[Dict]) -> Dict[str, Any]:
        """
        Extract key information from document.
        
        Args:
            text: Document text
            entities: Extracted entities
            
        Returns:
            Key information dictionary
        """
        key_info = {
            'emails': [],
            'card_numbers': [],
            'dates': [],
            'amounts': []
        }
        
        # Group entities by type
        for entity in entities:
            entity_type = entity['entity_type']
            entity_text = entity['text']
            
            if entity_type == 'EMAIL':
                key_info['emails'].append(entity_text)
            elif entity_type == 'CARD_NUMBER':
                # Mask card number for security
                masked = self._mask_card_number(entity_text)
                key_info['card_numbers'].append(masked)
            elif entity_type == 'DATE':
                key_info['dates'].append(entity_text)
            elif entity_type == 'AMOUNT':
                key_info['amounts'].append(entity_text)
        
        return key_info
    
    def _mask_card_number(self, card_number: str) -> str:
        """
        Mask credit card number for security.
        
        Args:
            card_number: Card number to mask
            
        Returns:
            Masked card number
        """
        # Remove spaces and dashes
        clean = card_number.replace(' ', '').replace('-', '')
        
        if len(clean) >= 10:
            # Show first 6 and last 4 digits
            return f"{clean[:6]}{'*' * (len(clean) - 10)}{clean[-4:]}"
        else:
            # Mask all but last 4
            return '*' * (len(clean) - 4) + clean[-4:]
    
    def batch_analyze_documents(self, documents: List[str]) -> List[Dict[str, Any]]:
        """
        Analyze multiple documents in batch.
        
        Args:
            documents: List of document texts
            
        Returns:
            List of analysis results
        """
        results = []
        
        for i, doc in enumerate(documents):
            try:
                analysis = self.analyze_document(doc)
                analysis['document_index'] = i
                results.append(analysis)
            except Exception as e:
                logger.error(f"Error analyzing document {i}: {str(e)}")
                results.append({
                    'document_index': i,
                    'error': str(e),
                    'entities': [],
                    'classification': {'document_type': 'ERROR', 'confidence': 0.0}
                })
        
        return results
    
    def summarize_batch_results(self, results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Summarize batch analysis results.
        
        Args:
            results: List of analysis results
            
        Returns:
            Summary statistics
        """
        if not results:
            return {'error': 'No results to summarize'}
        
        # Count document types
        doc_types = {}
        compliant_count = 0
        total_entities = 0
        
        for result in results:
            if 'error' not in result or result.get('classification'):
                doc_type = result.get('classification', {}).get('document_type', 'UNKNOWN')
                doc_types[doc_type] = doc_types.get(doc_type, 0) + 1
                
                if result.get('validation', {}).get('is_compliant', False):
                    compliant_count += 1
                
                total_entities += result.get('entity_count', 0)
        
        return {
            'total_documents': len(results),
            'document_types': doc_types,
            'compliant_documents': compliant_count,
            'compliance_rate': compliant_count / len(results) * 100 if results else 0,
            'total_entities_extracted': total_entities,
            'avg_entities_per_document': total_entities / len(results) if results else 0
        }
