package com.ecommerce.platform.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.ecommerce.platform.auth.model.*;
import com.ecommerce.platform.auth.service.*;
import com.ecommerce.platform.auth.util.ResponseBuilder;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Main Lambda handler for authentication service
 * Handles user registration, login, password reset, and JWT verification
 */
public class AuthHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {
    
    private static final Logger logger = LoggerFactory.getLogger(AuthHandler.class);
    private static final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());
    
    private final UserService userService;
    private final JwtService jwtService;
    private final PasswordService passwordService;
    private final EmailService emailService;
    
    /**
     * Constructor - initializes services
     */
    public AuthHandler() {
        this.userService = new UserService();
        this.jwtService = new JwtService();
        this.passwordService = new PasswordService();
        this.emailService = new EmailService();
        
        logger.info("AuthHandler initialized");
    }
    
    /**
     * Constructor for testing with dependency injection
     */
    public AuthHandler(UserService userService, JwtService jwtService, 
                      PasswordService passwordService, EmailService emailService) {
        this.userService = userService;
        this.jwtService = jwtService;
        this.passwordService = passwordService;
        this.emailService = emailService;
    }
    
    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent request, Context context) {
        logger.info("Received request: {} {}", request.getHttpMethod(), request.getPath());
        
        try {
            String path = request.getPath();
            String method = request.getHttpMethod();
            
            // Route to appropriate handler
            if (path.equals("/auth/register") && method.equals("POST")) {
                return handleRegister(request);
            } else if (path.equals("/auth/login") && method.equals("POST")) {
                return handleLogin(request);
            } else if (path.equals("/auth/forgot-password") && method.equals("POST")) {
                return handleForgotPassword(request);
            } else if (path.equals("/auth/reset-password") && method.equals("POST")) {
                return handleResetPassword(request);
            } else if (path.equals("/auth/verify") && method.equals("POST")) {
                return handleVerifyToken(request);
            } else {
                return ResponseBuilder.notFound("Endpoint not found");
            }
            
        } catch (Exception e) {
            logger.error("Error processing request", e);
            return ResponseBuilder.internalServerError("Internal server error: " + e.getMessage());
        }
    }
    
    /**
     * Handle user registration
     */
    private APIGatewayProxyResponseEvent handleRegister(APIGatewayProxyRequestEvent request) {
        try {
            RegisterRequest registerRequest = objectMapper.readValue(request.getBody(), RegisterRequest.class);
            
            // Validate input
            if (!isValidEmail(registerRequest.getEmail())) {
                return ResponseBuilder.badRequest("Invalid email format");
            }
            
            if (!passwordService.isStrongPassword(registerRequest.getPassword())) {
                return ResponseBuilder.badRequest(
                    "Password must be at least 8 characters with uppercase, lowercase, number, and special character"
                );
            }
            
            // Check if user already exists
            if (userService.userExists(registerRequest.getEmail())) {
                return ResponseBuilder.conflict("User with this email already exists");
            }
            
            // Hash password
            String passwordHash = passwordService.hashPassword(registerRequest.getPassword());
            
            // Create user
            User user = userService.createUser(
                registerRequest.getEmail(),
                passwordHash,
                registerRequest.getName()
            );
            
            logger.info("User registered successfully: {}", user.getUserId());
            
            Map<String, Object> response = new HashMap<>();
            response.put("userId", user.getUserId());
            response.put("message", "Registration successful");
            
            return ResponseBuilder.ok(response);
            
        } catch (Exception e) {
            logger.error("Error during registration", e);
            return ResponseBuilder.internalServerError("Registration failed: " + e.getMessage());
        }
    }
    
    /**
     * Handle user login
     */
    private APIGatewayProxyResponseEvent handleLogin(APIGatewayProxyRequestEvent request) {
        try {
            LoginRequest loginRequest = objectMapper.readValue(request.getBody(), LoginRequest.class);
            
            // Get user by email
            User user = userService.getUserByEmail(loginRequest.getEmail());
            if (user == null) {
                return ResponseBuilder.unauthorized("Invalid credentials");
            }
            
            // Verify password
            if (!passwordService.verifyPassword(loginRequest.getPassword(), user.getPasswordHash())) {
                return ResponseBuilder.unauthorized("Invalid credentials");
            }
            
            // Generate JWT token
            String token = jwtService.generateToken(user);
            
            logger.info("User logged in successfully: {}", user.getUserId());
            
            Map<String, Object> response = new HashMap<>();
            response.put("token", token);
            response.put("userId", user.getUserId());
            response.put("name", user.getName());
            response.put("expiresIn", 3600); // 1 hour
            
            return ResponseBuilder.ok(response);
            
        } catch (Exception e) {
            logger.error("Error during login", e);
            return ResponseBuilder.internalServerError("Login failed: " + e.getMessage());
        }
    }
    
    /**
     * Handle forgot password request
     */
    private APIGatewayProxyResponseEvent handleForgotPassword(APIGatewayProxyRequestEvent request) {
        try {
            ForgotPasswordRequest forgotRequest = objectMapper.readValue(request.getBody(), ForgotPasswordRequest.class);
            
            // Get user by email
            User user = userService.getUserByEmail(forgotRequest.getEmail());
            if (user == null) {
                // Don't reveal if user exists - return success anyway
                logger.info("Password reset requested for non-existent email: {}", forgotRequest.getEmail());
                Map<String, String> response = new HashMap<>();
                response.put("message", "Password reset email sent");
                return ResponseBuilder.ok(response);
            }
            
            // Generate reset token
            String resetToken = jwtService.generateResetToken(user);
            
            // Store reset token in user record
            userService.updateResetToken(user.getUserId(), resetToken);
            
            // Send email with reset link
            emailService.sendPasswordResetEmail(user.getEmail(), user.getName(), resetToken);
            
            logger.info("Password reset email sent to: {}", user.getEmail());
            
            Map<String, String> response = new HashMap<>();
            response.put("message", "Password reset email sent");
            
            return ResponseBuilder.ok(response);
            
        } catch (Exception e) {
            logger.error("Error during forgot password", e);
            return ResponseBuilder.internalServerError("Forgot password failed: " + e.getMessage());
        }
    }
    
    /**
     * Handle password reset
     */
    private APIGatewayProxyResponseEvent handleResetPassword(APIGatewayProxyRequestEvent request) {
        try {
            ResetPasswordRequest resetRequest = objectMapper.readValue(request.getBody(), ResetPasswordRequest.class);
            
            // Verify reset token
            String userId = jwtService.verifyResetToken(resetRequest.getToken());
            if (userId == null) {
                return ResponseBuilder.unauthorized("Invalid or expired reset token");
            }
            
            // Get user
            User user = userService.getUserById(userId);
            if (user == null) {
                return ResponseBuilder.notFound("User not found");
            }
            
            // Verify token matches stored token
            if (!resetRequest.getToken().equals(user.getResetToken())) {
                return ResponseBuilder.unauthorized("Invalid reset token");
            }
            
            // Validate new password
            if (!passwordService.isStrongPassword(resetRequest.getNewPassword())) {
                return ResponseBuilder.badRequest(
                    "Password must be at least 8 characters with uppercase, lowercase, number, and special character"
                );
            }
            
            // Hash new password
            String passwordHash = passwordService.hashPassword(resetRequest.getNewPassword());
            
            // Update password and clear reset token
            userService.updatePassword(userId, passwordHash);
            
            logger.info("Password reset successfully for user: {}", userId);
            
            Map<String, String> response = new HashMap<>();
            response.put("message", "Password reset successful");
            
            return ResponseBuilder.ok(response);
            
        } catch (Exception e) {
            logger.error("Error during password reset", e);
            return ResponseBuilder.internalServerError("Password reset failed: " + e.getMessage());
        }
    }
    
    /**
     * Handle JWT token verification
     */
    private APIGatewayProxyResponseEvent handleVerifyToken(APIGatewayProxyRequestEvent request) {
        try {
            VerifyTokenRequest verifyRequest = objectMapper.readValue(request.getBody(), VerifyTokenRequest.class);
            
            // Verify token
            String userId = jwtService.verifyToken(verifyRequest.getToken());
            if (userId == null) {
                return ResponseBuilder.unauthorized("Invalid or expired token");
            }
            
            // Get user
            User user = userService.getUserById(userId);
            if (user == null) {
                return ResponseBuilder.notFound("User not found");
            }
            
            Map<String, Object> response = new HashMap<>();
            response.put("valid", true);
            response.put("userId", user.getUserId());
            response.put("email", user.getEmail());
            response.put("name", user.getName());
            
            return ResponseBuilder.ok(response);
            
        } catch (Exception e) {
            logger.error("Error during token verification", e);
            return ResponseBuilder.internalServerError("Token verification failed: " + e.getMessage());
        }
    }
    
    /**
     * Validate email format
     */
    private boolean isValidEmail(String email) {
        if (email == null || email.trim().isEmpty()) {
            return false;
        }
        String emailRegex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";
        return email.matches(emailRegex);
    }
}
