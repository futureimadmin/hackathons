"""
Customer Segmentation

Implements K-Means clustering with RFM (Recency, Frequency, Monetary) analysis
for customer segmentation.
"""

import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score, davies_bouldin_score
import logging
from typing import Dict, List, Tuple, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class CustomerSegmentation:
    """Customer segmentation using K-Means clustering on RFM features."""
    
    def __init__(self, n_clusters: int = None, max_clusters: int = 10):
        """
        Initialize customer segmentation.
        
        Args:
            n_clusters: Number of clusters (if None, will auto-determine)
            max_clusters: Maximum number of clusters to test
        """
        self.n_clusters = n_clusters
        self.max_clusters = max_clusters
        self.model = None
        self.scaler = StandardScaler()
        self.optimal_k = None
        self.segment_profiles = None
        
    def calculate_rfm(
        self,
        customer_data: pd.DataFrame,
        reference_date: Optional[datetime] = None
    ) -> pd.DataFrame:
        """
        Calculate RFM (Recency, Frequency, Monetary) features.
        
        Args:
            customer_data: DataFrame with customer_id, order_date, order_total
            reference_date: Reference date for recency calculation
            
        Returns:
            DataFrame with RFM features
        """
        if reference_date is None:
            reference_date = customer_data['order_date'].max()
        
        logger.info(f"Calculating RFM features with reference date: {reference_date}")
        
        # Calculate RFM metrics
        rfm = customer_data.groupby('customer_id').agg({
            'order_date': lambda x: (reference_date - x.max()).days,  # Recency
            'order_id': 'count',  # Frequency
            'order_total': 'sum'  # Monetary
        }).reset_index()
        
        rfm.columns = ['customer_id', 'recency', 'frequency', 'monetary']
        
        # Add additional features
        rfm['avg_order_value'] = customer_data.groupby('customer_id')['order_total'].mean().values
        rfm['days_since_first_order'] = customer_data.groupby('customer_id')['order_date'].apply(
            lambda x: (reference_date - x.min()).days
        ).values
        
        # Calculate customer lifetime (in days)
        rfm['customer_lifetime'] = rfm['days_since_first_order']
        
        # Calculate purchase frequency (orders per day)
        rfm['purchase_frequency'] = rfm['frequency'] / (rfm['customer_lifetime'] + 1)
        
        logger.info(f"Calculated RFM for {len(rfm)} customers")
        return rfm
    
    def find_optimal_clusters(self, features: pd.DataFrame) -> int:
        """
        Find optimal number of clusters using elbow method and silhouette score.
        
        Args:
            features: Scaled feature matrix
            
        Returns:
            Optimal number of clusters
        """
        logger.info("Finding optimal number of clusters...")
        
        inertias = []
        silhouette_scores = []
        davies_bouldin_scores = []
        
        k_range = range(2, min(self.max_clusters + 1, len(features)))
        
        for k in k_range:
            kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
            labels = kmeans.fit_predict(features)
            
            inertias.append(kmeans.inertia_)
            silhouette_scores.append(silhouette_score(features, labels))
            davies_bouldin_scores.append(davies_bouldin_score(features, labels))
        
        # Find elbow point (maximum second derivative)
        if len(inertias) >= 3:
            second_derivatives = np.diff(np.diff(inertias))
            elbow_k = np.argmax(second_derivatives) + 2  # +2 because of double diff
        else:
            elbow_k = 3
        
        # Find best silhouette score
        best_silhouette_k = np.argmax(silhouette_scores) + 2
        
        # Use average of elbow and silhouette methods
        optimal_k = int((elbow_k + best_silhouette_k) / 2)
        optimal_k = max(2, min(optimal_k, self.max_clusters))
        
        logger.info(f"Optimal clusters: {optimal_k} (elbow: {elbow_k}, silhouette: {best_silhouette_k})")
        
        return optimal_k
    
    def fit(self, rfm_data: pd.DataFrame) -> 'CustomerSegmentation':
        """
        Fit K-Means clustering model.
        
        Args:
            rfm_data: DataFrame with RFM features
            
        Returns:
            Self for method chaining
        """
        # Select features for clustering
        feature_cols = ['recency', 'frequency', 'monetary', 'avg_order_value', 'purchase_frequency']
        features = rfm_data[feature_cols].copy()
        
        # Handle missing values
        features = features.fillna(features.median())
        
        # Scale features
        features_scaled = self.scaler.fit_transform(features)
        
        # Determine optimal number of clusters if not specified
        if self.n_clusters is None:
            self.optimal_k = self.find_optimal_clusters(features_scaled)
        else:
            self.optimal_k = self.n_clusters
        
        # Fit K-Means
        logger.info(f"Fitting K-Means with {self.optimal_k} clusters...")
        self.model = KMeans(n_clusters=self.optimal_k, random_state=42, n_init=10)
        self.model.fit(features_scaled)
        
        logger.info("K-Means model fitted successfully")
        return self
    
    def predict(self, rfm_data: pd.DataFrame) -> np.ndarray:
        """
        Predict cluster labels for customers.
        
        Args:
            rfm_data: DataFrame with RFM features
            
        Returns:
            Array of cluster labels
        """
        if self.model is None:
            raise ValueError("Model must be fitted before prediction")
        
        feature_cols = ['recency', 'frequency', 'monetary', 'avg_order_value', 'purchase_frequency']
        features = rfm_data[feature_cols].copy()
        features = features.fillna(features.median())
        features_scaled = self.scaler.transform(features)
        
        return self.model.predict(features_scaled)
    
    def create_segment_profiles(self, rfm_data: pd.DataFrame, labels: np.ndarray) -> pd.DataFrame:
        """
        Create profiles for each segment.
        
        Args:
            rfm_data: DataFrame with RFM features
            labels: Cluster labels
            
        Returns:
            DataFrame with segment profiles
        """
        rfm_with_labels = rfm_data.copy()
        rfm_with_labels['segment'] = labels
        
        # Calculate segment statistics
        profiles = rfm_with_labels.groupby('segment').agg({
            'customer_id': 'count',
            'recency': ['mean', 'median'],
            'frequency': ['mean', 'median'],
            'monetary': ['mean', 'median', 'sum'],
            'avg_order_value': ['mean', 'median'],
            'purchase_frequency': ['mean', 'median']
        }).reset_index()
        
        # Flatten column names
        profiles.columns = ['_'.join(col).strip('_') for col in profiles.columns.values]
        profiles.rename(columns={'segment': 'segment', 'customer_id_count': 'customer_count'}, inplace=True)
        
        # Add segment names based on characteristics
        profiles['segment_name'] = profiles.apply(self._name_segment, axis=1)
        
        # Calculate segment value (total monetary)
        profiles['total_value'] = profiles['monetary_sum']
        profiles['avg_customer_value'] = profiles['monetary_mean']
        
        self.segment_profiles = profiles
        logger.info(f"Created profiles for {len(profiles)} segments")
        
        return profiles
    
    def _name_segment(self, row: pd.Series) -> str:
        """
        Assign descriptive name to segment based on characteristics.
        
        Args:
            row: Segment profile row
            
        Returns:
            Segment name
        """
        recency = row['recency_mean']
        frequency = row['frequency_mean']
        monetary = row['monetary_mean']
        
        # High value, high frequency, low recency = Champions
        if monetary > 1000 and frequency > 10 and recency < 30:
            return "Champions"
        # High value, low recency = Loyal Customers
        elif monetary > 500 and recency < 60:
            return "Loyal Customers"
        # High frequency, low recency = Potential Loyalists
        elif frequency > 5 and recency < 90:
            return "Potential Loyalists"
        # Recent customers = New Customers
        elif recency < 30 and frequency <= 2:
            return "New Customers"
        # High recency, low frequency = At Risk
        elif recency > 180 and frequency < 3:
            return "At Risk"
        # High recency, high past value = Hibernating
        elif recency > 180 and monetary > 300:
            return "Hibernating"
        # Low value, low frequency = Lost
        elif recency > 365:
            return "Lost"
        else:
            return "Promising"
    
    def get_segment_summary(self) -> Dict:
        """
        Get summary of all segments.
        
        Returns:
            Dictionary with segment summary
        """
        if self.segment_profiles is None:
            raise ValueError("Segment profiles not created yet")
        
        summary = {
            'total_segments': len(self.segment_profiles),
            'total_customers': int(self.segment_profiles['customer_count'].sum()),
            'total_value': float(self.segment_profiles['total_value'].sum()),
            'segments': self.segment_profiles.to_dict('records')
        }
        
        return summary
