# Dockerfile for eCommerce AI Platform Data Processing Jobs
# This container runs data validation, deduplication, and transformation jobs

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Set Python path
ENV PYTHONPATH=/app

# Create directories for logs and temp files
RUN mkdir -p /app/logs /app/temp

# Set environment variables
ENV AWS_DEFAULT_REGION=us-east-1
ENV LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1

# Default command (can be overridden by AWS Batch)
CMD ["python", "-m", "src.main"]
