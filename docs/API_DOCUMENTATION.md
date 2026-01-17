# API Documentation

## Base URL

```
https://api.example.com
```

## Authentication

All endpoints (except `/auth/*`) require JWT authentication.

```bash
# Get token
POST /auth/login
{
  "email": "user@example.com",
  "password": "password"
}

# Use token
curl -H "Authorization: Bearer <token>" https://api.example.com/endpoint
```

## Endpoints

### Authentication

#### POST /auth/register
Register new user

**Request:**
```json
{
  "email": "user@example.com",
  "password": "StrongP@ssw0rd123!",
  "firstName": "John",
  "lastName": "Doe"
}
```

**Response:** 201 Created

#### POST /auth/login
Login user

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password"
}
```

**Response:**
```json
{
  "token": "eyJhbGc...",
  "userId": "USER001",
  "email": "user@example.com",
  "firstName": "John",
  "lastName": "Doe"
}
```

### Market Intelligence Hub

#### POST /market-intelligence/forecast
Generate sales forecast

**Request:**
```json
{
  "product_id": "PROD001",
  "periods": 30,
  "model": "auto"
}
```

**Response:**
```json
{
  "forecast": [100, 105, 110, ...],
  "confidence_intervals": {...},
  "model_used": "prophet",
  "metrics": {
    "rmse": 5.2,
    "mae": 4.1,
    "mape": 3.8
  }
}
```

### Demand Insights Engine

#### GET /demand-insights/segments
Get customer segments

**Parameters:**
- `n_clusters`: Number of clusters (2-10)

**Response:**
```json
{
  "segments": [...],
  "cluster_centers": [...],
  "segment_sizes": [...]
}
```

### Compliance Guardian

#### POST /compliance/fraud-detection
Detect fraudulent transactions

**Request:**
```json
{
  "transaction_ids": ["TXN001", "TXN002"]
}
```

**Response:**
```json
{
  "fraud_scores": {
    "TXN001": 0.85,
    "TXN002": 0.12
  },
  "anomaly_flags": {
    "TXN001": true,
    "TXN002": false
  }
}
```

### Retail Copilot

#### POST /retail-copilot/chat
Chat with AI copilot

**Request:**
```json
{
  "user_id": "USER001",
  "message": "What are the top 5 selling products?"
}
```

**Response:**
```json
{
  "response": "Here are the top 5 selling products...",
  "conversation_id": "CONV001",
  "query_type": "data"
}
```

### Global Market Pulse

#### GET /global-market/trends
Get market trends

**Parameters:**
- `product_id`: Product ID
- `days`: Number of days (30-365)

**Response:**
```json
{
  "trend": [...],
  "seasonal": [...],
  "statistics": {...}
}
```

## Error Codes

- `400` Bad Request - Invalid input
- `401` Unauthorized - Missing or invalid token
- `403` Forbidden - Insufficient permissions
- `404` Not Found - Resource not found
- `500` Internal Server Error - Server error

## Rate Limiting

- 1000 requests per minute per user
- 5000 burst limit

## Pagination

Use `limit` and `offset` parameters:

```
GET /endpoint?limit=100&offset=200
```

## Filtering

Use query parameters:

```
GET /products?category=Electronics&price_min=100&price_max=500
```

## Complete API Reference

See Postman collection: `docs/postman_collection.json`
