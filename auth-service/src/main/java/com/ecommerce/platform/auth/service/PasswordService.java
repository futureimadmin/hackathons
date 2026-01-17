package com.ecommerce.platform.auth.service;

import at.favre.lib.crypto.bcrypt.BCrypt;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.regex.Pattern;

/**
 * Service for password hashing and validation
 */
public class PasswordService {
    
    private static final Logger logger = LoggerFactory.getLogger(PasswordService.class);
    private static final int BCRYPT_COST = 12;
    
    // Password strength regex patterns
    private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
    private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
    private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[^A-Za-z0-9]");
    
    /**
     * Hash password using BCrypt
     */
    public String hashPassword(String password) {
        if (password == null || password.isEmpty()) {
            throw new IllegalArgumentException("Password cannot be null or empty");
        }
        
        String hash = BCrypt.withDefaults().hashToString(BCRYPT_COST, password.toCharArray());
        logger.debug("Password hashed successfully");
        return hash;
    }
    
    /**
     * Verify password against BCrypt hash
     */
    public boolean verifyPassword(String password, String hash) {
        if (password == null || hash == null) {
            return false;
        }
        
        BCrypt.Result result = BCrypt.verifyer().verify(password.toCharArray(), hash);
        return result.verified;
    }
    
    /**
     * Check if password meets strength requirements
     * - Minimum 8 characters
     * - At least one uppercase letter
     * - At least one lowercase letter
     * - At least one digit
     * - At least one special character
     */
    public boolean isStrongPassword(String password) {
        if (password == null || password.length() < 8) {
            return false;
        }
        
        boolean hasUppercase = UPPERCASE_PATTERN.matcher(password).find();
        boolean hasLowercase = LOWERCASE_PATTERN.matcher(password).find();
        boolean hasDigit = DIGIT_PATTERN.matcher(password).find();
        boolean hasSpecialChar = SPECIAL_CHAR_PATTERN.matcher(password).find();
        
        return hasUppercase && hasLowercase && hasDigit && hasSpecialChar;
    }
    
    /**
     * Get password strength score (0-5)
     */
    public int getPasswordStrength(String password) {
        if (password == null) {
            return 0;
        }
        
        int score = 0;
        
        if (password.length() >= 8) score++;
        if (password.length() >= 12) score++;
        if (UPPERCASE_PATTERN.matcher(password).find()) score++;
        if (LOWERCASE_PATTERN.matcher(password).find()) score++;
        if (DIGIT_PATTERN.matcher(password).find()) score++;
        if (SPECIAL_CHAR_PATTERN.matcher(password).find()) score++;
        
        return Math.min(score, 5);
    }
}
