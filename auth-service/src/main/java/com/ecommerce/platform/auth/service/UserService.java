package com.ecommerce.platform.auth.service;

import com.ecommerce.platform.auth.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Service for managing users in DynamoDB
 */
public class UserService {
    
    private static final Logger logger = LoggerFactory.getLogger(UserService.class);
    private final DynamoDbClient dynamoDb;
    private final String tableName;
    private final String emailIndexName = "email-index";
    
    public UserService() {
        this.dynamoDb = DynamoDbClient.builder().build();
        this.tableName = System.getenv().getOrDefault("DYNAMODB_TABLE_NAME", "ecommerce-users");
        logger.info("UserService initialized with table: {}", tableName);
    }
    
    public UserService(DynamoDbClient dynamoDb, String tableName) {
        this.dynamoDb = dynamoDb;
        this.tableName = tableName;
    }
    
    /**
     * Create a new user
     */
    public User createUser(String email, String passwordHash, String name) {
        String userId = UUID.randomUUID().toString();
        Instant now = Instant.now();
        
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("userId", AttributeValue.builder().s(userId).build());
        item.put("email", AttributeValue.builder().s(email.toLowerCase()).build());
        item.put("passwordHash", AttributeValue.builder().s(passwordHash).build());
        item.put("name", AttributeValue.builder().s(name).build());
        item.put("createdAt", AttributeValue.builder().s(now.toString()).build());
        item.put("updatedAt", AttributeValue.builder().s(now.toString()).build());
        
        PutItemRequest request = PutItemRequest.builder()
                .tableName(tableName)
                .item(item)
                .build();
        
        try {
            dynamoDb.putItem(request);
            logger.info("User created successfully: {}", userId);
            
            User user = new User(userId, email, passwordHash, name);
            user.setCreatedAt(now);
            user.setUpdatedAt(now);
            return user;
            
        } catch (DynamoDbException e) {
            logger.error("Error creating user", e);
            throw new RuntimeException("Failed to create user: " + e.getMessage(), e);
        }
    }
    
    /**
     * Check if user exists by email
     */
    public boolean userExists(String email) {
        return getUserByEmail(email) != null;
    }
    
    /**
     * Get user by email using GSI
     */
    public User getUserByEmail(String email) {
        QueryRequest request = QueryRequest.builder()
                .tableName(tableName)
                .indexName(emailIndexName)
                .keyConditionExpression("email = :email")
                .expressionAttributeValues(Map.of(
                        ":email", AttributeValue.builder().s(email.toLowerCase()).build()
                ))
                .build();
        
        try {
            QueryResponse response = dynamoDb.query(request);
            
            if (response.items().isEmpty()) {
                return null;
            }
            
            return mapToUser(response.items().get(0));
            
        } catch (DynamoDbException e) {
            logger.error("Error querying user by email", e);
            throw new RuntimeException("Failed to query user: " + e.getMessage(), e);
        }
    }
    
    /**
     * Get user by ID
     */
    public User getUserById(String userId) {
        GetItemRequest request = GetItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("userId", AttributeValue.builder().s(userId).build()))
                .build();
        
        try {
            GetItemResponse response = dynamoDb.getItem(request);
            
            if (!response.hasItem()) {
                return null;
            }
            
            return mapToUser(response.item());
            
        } catch (DynamoDbException e) {
            logger.error("Error getting user by ID", e);
            throw new RuntimeException("Failed to get user: " + e.getMessage(), e);
        }
    }
    
    /**
     * Update user password
     */
    public void updatePassword(String userId, String passwordHash) {
        UpdateItemRequest request = UpdateItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("userId", AttributeValue.builder().s(userId).build()))
                .updateExpression("SET passwordHash = :hash, updatedAt = :updated, resetToken = :null")
                .expressionAttributeValues(Map.of(
                        ":hash", AttributeValue.builder().s(passwordHash).build(),
                        ":updated", AttributeValue.builder().s(Instant.now().toString()).build(),
                        ":null", AttributeValue.builder().nul(true).build()
                ))
                .build();
        
        try {
            dynamoDb.updateItem(request);
            logger.info("Password updated for user: {}", userId);
            
        } catch (DynamoDbException e) {
            logger.error("Error updating password", e);
            throw new RuntimeException("Failed to update password: " + e.getMessage(), e);
        }
    }
    
    /**
     * Update reset token
     */
    public void updateResetToken(String userId, String resetToken) {
        // Set expiry to 1 hour from now
        long expiry = Instant.now().plusSeconds(3600).getEpochSecond();
        
        UpdateItemRequest request = UpdateItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("userId", AttributeValue.builder().s(userId).build()))
                .updateExpression("SET resetToken = :token, resetTokenExpiry = :expiry, updatedAt = :updated")
                .expressionAttributeValues(Map.of(
                        ":token", AttributeValue.builder().s(resetToken).build(),
                        ":expiry", AttributeValue.builder().n(String.valueOf(expiry)).build(),
                        ":updated", AttributeValue.builder().s(Instant.now().toString()).build()
                ))
                .build();
        
        try {
            dynamoDb.updateItem(request);
            logger.info("Reset token updated for user: {}", userId);
            
        } catch (DynamoDbException e) {
            logger.error("Error updating reset token", e);
            throw new RuntimeException("Failed to update reset token: " + e.getMessage(), e);
        }
    }
    
    /**
     * Map DynamoDB item to User object
     */
    private User mapToUser(Map<String, AttributeValue> item) {
        User user = new User();
        user.setUserId(item.get("userId").s());
        user.setEmail(item.get("email").s());
        user.setPasswordHash(item.get("passwordHash").s());
        user.setName(item.get("name").s());
        
        if (item.containsKey("resetToken") && item.get("resetToken").s() != null) {
            user.setResetToken(item.get("resetToken").s());
        }
        
        if (item.containsKey("createdAt")) {
            user.setCreatedAt(Instant.parse(item.get("createdAt").s()));
        }
        
        if (item.containsKey("updatedAt")) {
            user.setUpdatedAt(Instant.parse(item.get("updatedAt").s()));
        }
        
        return user;
    }
}
