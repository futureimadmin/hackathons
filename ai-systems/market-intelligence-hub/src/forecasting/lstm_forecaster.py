"""
LSTM Forecasting Model

Implements LSTM (Long Short-Term Memory) neural network for time series forecasting.
Handles complex non-linear patterns and long-term dependencies.
"""

import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.preprocessing import MinMaxScaler
import logging
from typing import Dict, List, Tuple, Optional

logger = logging.getLogger(__name__)


class LSTMForecaster:
    """LSTM neural network forecasting model."""
    
    def __init__(
        self,
        lookback: int = 30,
        lstm_units: int = 50,
        dropout: float = 0.2,
        epochs: int = 50,
        batch_size: int = 32
    ):
        """
        Initialize LSTM forecaster.
        
        Args:
            lookback: Number of past time steps to use for prediction
            lstm_units: Number of LSTM units in hidden layer
            dropout: Dropout rate for regularization
            epochs: Number of training epochs
            batch_size: Batch size for training
        """
        self.lookback = lookback
        self.lstm_units = lstm_units
        self.dropout = dropout
        self.epochs = epochs
        self.batch_size = batch_size
        self.model = None
        self.scaler = MinMaxScaler(feature_range=(0, 1))
        self.history = None
        
    def create_sequences(
        self,
        data: np.ndarray,
        lookback: int
    ) -> Tuple[np.ndarray, np.ndarray]:
        """
        Create sequences for LSTM training.
        
        Args:
            data: Scaled time series data
            lookback: Number of past steps to use
            
        Returns:
            Tuple of (X, y) arrays
        """
        X, y = [], []
        for i in range(lookback, len(data)):
            X.append(data[i-lookback:i, 0])
            y.append(data[i, 0])
        
        X = np.array(X)
        y = np.array(y)
        
        # Reshape X for LSTM [samples, time steps, features]
        X = np.reshape(X, (X.shape[0], X.shape[1], 1))
        
        return X, y
    
    def build_model(self, input_shape: Tuple[int, int]):
        """
        Build LSTM model architecture.
        
        Args:
            input_shape: Shape of input data (time steps, features)
        """
        model = keras.Sequential([
            layers.LSTM(
                self.lstm_units,
                return_sequences=True,
                input_shape=input_shape
            ),
            layers.Dropout(self.dropout),
            layers.LSTM(self.lstm_units, return_sequences=False),
            layers.Dropout(self.dropout),
            layers.Dense(25),
            layers.Dense(1)
        ])
        
        model.compile(
            optimizer='adam',
            loss='mean_squared_error',
            metrics=['mae']
        )
        
        self.model = model
        logger.info(f"LSTM model built with {self.lstm_units} units")
    
    def fit(self, series: pd.Series, validation_split: float = 0.2):
        """
        Fit LSTM model to time series data.
        
        Args:
            series: Time series data
            validation_split: Fraction of data to use for validation
        """
        logger.info("Fitting LSTM model...")
        
        # Scale data
        data = series.values.reshape(-1, 1)
        scaled_data = self.scaler.fit_transform(data)
        
        # Create sequences
        X, y = self.create_sequences(scaled_data, self.lookback)
        
        # Build model
        self.build_model(input_shape=(X.shape[1], 1))
        
        # Train model
        self.history = self.model.fit(
            X, y,
            epochs=self.epochs,
            batch_size=self.batch_size,
            validation_split=validation_split,
            verbose=0,
            callbacks=[
                keras.callbacks.EarlyStopping(
                    monitor='val_loss',
                    patience=10,
                    restore_best_weights=True
                )
            ]
        )
        
        logger.info(f"LSTM model trained for {len(self.history.history['loss'])} epochs")
    
    def forecast(self, series: pd.Series, steps: int) -> Dict:
        """
        Generate forecast.
        
        Args:
            series: Historical time series data
            steps: Number of periods to forecast
            
        Returns:
            Dictionary with forecast values
        """
        if self.model is None:
            raise ValueError("Model must be fitted before forecasting")
        
        logger.info(f"Generating {steps}-step forecast with LSTM...")
        
        # Scale data
        data = series.values.reshape(-1, 1)
        scaled_data = self.scaler.transform(data)
        
        # Use last lookback values as starting point
        current_sequence = scaled_data[-self.lookback:].reshape(1, self.lookback, 1)
        
        # Generate predictions iteratively
        predictions = []
        for _ in range(steps):
            # Predict next value
            next_pred = self.model.predict(current_sequence, verbose=0)
            predictions.append(next_pred[0, 0])
            
            # Update sequence with prediction
            current_sequence = np.append(
                current_sequence[:, 1:, :],
                next_pred.reshape(1, 1, 1),
                axis=1
            )
        
        # Inverse transform predictions
        predictions = np.array(predictions).reshape(-1, 1)
        predictions = self.scaler.inverse_transform(predictions)
        
        # Calculate approximate confidence intervals
        # Using standard deviation of training residuals
        train_predictions = self.model.predict(
            self.create_sequences(scaled_data, self.lookback)[0],
            verbose=0
        )
        train_predictions = self.scaler.inverse_transform(train_predictions)
        train_actual = data[self.lookback:]
        residuals = train_actual - train_predictions
        std_residual = np.std(residuals)
        
        result = {
            'forecast': predictions.flatten().tolist(),
            'lower_bound': (predictions.flatten() - 1.96 * std_residual).tolist(),
            'upper_bound': (predictions.flatten() + 1.96 * std_residual).tolist(),
            'model': 'LSTM',
            'lookback': self.lookback,
            'lstm_units': self.lstm_units,
            'epochs_trained': len(self.history.history['loss'])
        }
        
        return result
    
    def evaluate(self, test_series: pd.Series, train_series: pd.Series) -> Dict:
        """
        Evaluate model performance on test data.
        
        Args:
            test_series: Test time series data
            train_series: Training time series data (needed for sequence creation)
            
        Returns:
            Dictionary with RMSE, MAE, MAPE metrics
        """
        if self.model is None:
            raise ValueError("Model must be fitted before evaluation")
        
        # Combine train and test for sequence creation
        combined = pd.concat([train_series, test_series])
        data = combined.values.reshape(-1, 1)
        scaled_data = self.scaler.transform(data)
        
        # Create sequences for test data
        test_start_idx = len(train_series)
        predictions = []
        
        for i in range(test_start_idx, len(combined)):
            sequence = scaled_data[i-self.lookback:i].reshape(1, self.lookback, 1)
            pred = self.model.predict(sequence, verbose=0)
            predictions.append(pred[0, 0])
        
        # Inverse transform
        predictions = np.array(predictions).reshape(-1, 1)
        predictions = self.scaler.inverse_transform(predictions)
        
        # Calculate metrics
        actual = test_series.values
        predicted = predictions.flatten()
        
        rmse = np.sqrt(np.mean((actual - predicted) ** 2))
        mae = np.mean(np.abs(actual - predicted))
        mape = np.mean(np.abs((actual - predicted) / actual)) * 100
        
        metrics = {
            'rmse': float(rmse),
            'mae': float(mae),
            'mape': float(mape)
        }
        
        logger.info(f"Evaluation metrics: RMSE={rmse:.2f}, MAE={mae:.2f}, MAPE={mape:.2f}%")
        return metrics
    
    def get_training_history(self) -> Dict:
        """
        Get training history (loss, validation loss).
        
        Returns:
            Dictionary with training metrics
        """
        if self.history is None:
            return {}
        
        return {
            'loss': self.history.history['loss'],
            'val_loss': self.history.history['val_loss'],
            'mae': self.history.history['mae'],
            'val_mae': self.history.history['val_mae']
        }
