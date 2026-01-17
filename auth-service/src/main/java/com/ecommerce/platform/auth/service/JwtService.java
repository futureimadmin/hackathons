package com.ecommerce.platform.auth.service;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.ecommerce.platform.auth.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueResponse;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;

/**
 * Service for JWT token generation and verification
 */
public class JwtService {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtService.class);
    private static final String ISSUER = "ecommerce-ai-platform";
    // Set to 0 for non-expiring tokens (as requested)
    // For production, consider setting to a reasonable value like 24 hours
    private static final long TOKEN_EXPIRY_HOURS = 0;  // 0 = no expiration
    private static final long RESET_TOKEN_EXPIRY_HOURS = 1;
    
    private final String jwtSecret;
    private final Algorithm algorithm;
    
    public JwtService() {
        this.jwtSecret = getJwtSecretFromSecretsManager();
        this.algorithm = Algorithm.HMAC256(jwtSecret);
        logger.info("JwtService initialized");
    }
    
    public JwtService(String jwtSecret) {
        this.jwtSecret = jwtSecret;
        this.algorithm = Algorithm.HMAC256(jwtSecret);
    }
    
    /**
     * Generate JWT token for user
     * Note: TOKEN_EXPIRY_HOURS is set to 0 for non-expiring tokens
     * For production, consider setting a reasonable expiration time
     */
    public String generateToken(User user) {
        Instant now = Instant.now();
        
        var jwtBuilder = JWT.create()
                .withSubject(user.getUserId())
                .withClaim("email", user.getEmail())
                .withClaim("name", user.getName())
                .withIssuedAt(Date.from(now))
                .withIssuer(ISSUER);
        
        // Only set expiration if TOKEN_EXPIRY_HOURS > 0
        if (TOKEN_EXPIRY_HOURS > 0) {
            Instant expiry = now.plus(TOKEN_EXPIRY_HOURS, ChronoUnit.HOURS);
            jwtBuilder.withExpiresAt(Date.from(expiry));
            logger.info("Token generated with expiration: {} hours", TOKEN_EXPIRY_HOURS);
        } else {
            logger.info("Token generated with NO EXPIRATION");
        }
        
        return jwtBuilder.sign(algorithm);
    }
    
    /**
     * Generate password reset token
     */
    public String generateResetToken(User user) {
        Instant now = Instant.now();
        Instant expiry = now.plus(RESET_TOKEN_EXPIRY_HOURS, ChronoUnit.HOURS);
        
        return JWT.create()
                .withSubject(user.getUserId())
                .withClaim("type", "reset")
                .withIssuedAt(Date.from(now))
                .withExpiresAt(Date.from(expiry))
                .withIssuer(ISSUER)
                .sign(algorithm);
    }
    
    /**
     * Verify JWT token and return user ID
     */
    public String verifyToken(String token) {
        try {
            JWTVerifier verifier = JWT.require(algorithm)
                    .withIssuer(ISSUER)
                    .build();
            
            DecodedJWT jwt = verifier.verify(token);
            return jwt.getSubject();
            
        } catch (JWTVerificationException e) {
            logger.warn("Token verification failed: {}", e.getMessage());
            return null;
        }
    }
    
    /**
     * Verify reset token and return user ID
     */
    public String verifyResetToken(String token) {
        try {
            JWTVerifier verifier = JWT.require(algorithm)
                    .withIssuer(ISSUER)
                    .withClaim("type", "reset")
                    .build();
            
            DecodedJWT jwt = verifier.verify(token);
            return jwt.getSubject();
            
        } catch (JWTVerificationException e) {
            logger.warn("Reset token verification failed: {}", e.getMessage());
            return null;
        }
    }
    
    /**
     * Get JWT secret from AWS Secrets Manager
     */
    private String getJwtSecretFromSecretsManager() {
        String secretName = System.getenv().getOrDefault("JWT_SECRET_NAME", "ecommerce-jwt-secret");
        
        try (SecretsManagerClient client = SecretsManagerClient.builder().build()) {
            GetSecretValueRequest request = GetSecretValueRequest.builder()
                    .secretId(secretName)
                    .build();
            
            GetSecretValueResponse response = client.getSecretValue(request);
            String secret = response.secretString();
            
            logger.info("JWT secret retrieved from Secrets Manager");
            return secret;
            
        } catch (Exception e) {
            logger.error("Failed to retrieve JWT secret from Secrets Manager", e);
            // Fallback to environment variable for local development
            String fallbackSecret = System.getenv("JWT_SECRET");
            if (fallbackSecret != null) {
                logger.warn("Using JWT secret from environment variable");
                return fallbackSecret;
            }
            throw new RuntimeException("JWT secret not configured", e);
        }
    }
}
