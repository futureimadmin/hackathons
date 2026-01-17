package com.ecommerce.platform.auth.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.*;

/**
 * Service for sending emails via AWS SES
 */
public class EmailService {
    
    private static final Logger logger = LoggerFactory.getLogger(EmailService.class);
    private final SesClient sesClient;
    private final String fromEmail;
    
    public EmailService() {
        this.sesClient = SesClient.builder().build();
        this.fromEmail = System.getenv().getOrDefault("SES_FROM_EMAIL", "noreply@ecommerce-platform.com");
        logger.info("EmailService initialized with from email: {}", fromEmail);
    }
    
    public EmailService(SesClient sesClient, String fromEmail) {
        this.sesClient = sesClient;
        this.fromEmail = fromEmail;
    }
    
    /**
     * Send password reset email
     */
    public void sendPasswordResetEmail(String toEmail, String userName, String resetToken) {
        String subject = "Password Reset Request - eCommerce AI Platform";
        String resetLink = buildResetLink(resetToken);
        
        String htmlBody = buildPasswordResetHtmlBody(userName, resetLink);
        String textBody = buildPasswordResetTextBody(userName, resetLink);
        
        sendEmail(toEmail, subject, htmlBody, textBody);
    }
    
    /**
     * Send welcome email after registration
     */
    public void sendWelcomeEmail(String toEmail, String userName) {
        String subject = "Welcome to eCommerce AI Platform";
        
        String htmlBody = buildWelcomeHtmlBody(userName);
        String textBody = buildWelcomeTextBody(userName);
        
        sendEmail(toEmail, subject, htmlBody, textBody);
    }
    
    /**
     * Send email using AWS SES
     */
    private void sendEmail(String toEmail, String subject, String htmlBody, String textBody) {
        try {
            Destination destination = Destination.builder()
                    .toAddresses(toEmail)
                    .build();
            
            Content subjectContent = Content.builder()
                    .data(subject)
                    .build();
            
            Content htmlContent = Content.builder()
                    .data(htmlBody)
                    .build();
            
            Content textContent = Content.builder()
                    .data(textBody)
                    .build();
            
            Body body = Body.builder()
                    .html(htmlContent)
                    .text(textContent)
                    .build();
            
            Message message = Message.builder()
                    .subject(subjectContent)
                    .body(body)
                    .build();
            
            SendEmailRequest request = SendEmailRequest.builder()
                    .source(fromEmail)
                    .destination(destination)
                    .message(message)
                    .build();
            
            SendEmailResponse response = sesClient.sendEmail(request);
            logger.info("Email sent successfully to {}, MessageId: {}", toEmail, response.messageId());
            
        } catch (SesException e) {
            logger.error("Failed to send email to {}", toEmail, e);
            throw new RuntimeException("Failed to send email: " + e.getMessage(), e);
        }
    }
    
    /**
     * Build reset link from token
     */
    private String buildResetLink(String resetToken) {
        String frontendUrl = System.getenv().getOrDefault("FRONTEND_URL", "https://platform.example.com");
        return frontendUrl + "/reset-password?token=" + resetToken;
    }
    
    /**
     * Build HTML body for password reset email
     */
    private String buildPasswordResetHtmlBody(String userName, String resetLink) {
        return String.format("""
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .button { display: inline-block; padding: 12px 24px; background-color: #007bff;
                                 color: white; text-decoration: none; border-radius: 4px; margin: 20px 0; }
                        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;
                                 font-size: 12px; color: #666; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h2>Password Reset Request</h2>
                        <p>Hello %s,</p>
                        <p>We received a request to reset your password for your eCommerce AI Platform account.</p>
                        <p>Click the button below to reset your password:</p>
                        <a href="%s" class="button">Reset Password</a>
                        <p>Or copy and paste this link into your browser:</p>
                        <p><a href="%s">%s</a></p>
                        <p>This link will expire in 1 hour.</p>
                        <p>If you didn't request a password reset, please ignore this email or contact support if you have concerns.</p>
                        <div class="footer">
                            <p>This is an automated email from eCommerce AI Platform. Please do not reply.</p>
                        </div>
                    </div>
                </body>
                </html>
                """, userName, resetLink, resetLink, resetLink);
    }
    
    /**
     * Build text body for password reset email
     */
    private String buildPasswordResetTextBody(String userName, String resetLink) {
        return String.format("""
                Password Reset Request
                
                Hello %s,
                
                We received a request to reset your password for your eCommerce AI Platform account.
                
                Click the link below to reset your password:
                %s
                
                This link will expire in 1 hour.
                
                If you didn't request a password reset, please ignore this email or contact support if you have concerns.
                
                ---
                This is an automated email from eCommerce AI Platform. Please do not reply.
                """, userName, resetLink);
    }
    
    /**
     * Build HTML body for welcome email
     */
    private String buildWelcomeHtmlBody(String userName) {
        return String.format("""
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;
                                 font-size: 12px; color: #666; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h2>Welcome to eCommerce AI Platform!</h2>
                        <p>Hello %s,</p>
                        <p>Thank you for registering with eCommerce AI Platform.</p>
                        <p>You now have access to our five integrated AI systems:</p>
                        <ul>
                            <li><strong>Market Intelligence Hub</strong> - Market intelligence and forecasting</li>
                            <li><strong>Demand Insights Engine</strong> - Customer insights and demand forecasting</li>
                            <li><strong>Compliance Guardian</strong> - Risk analysis and compliance monitoring</li>
                            <li><strong>Retail Copilot</strong> - AI assistant for retail teams</li>
                            <li><strong>Global Market Pulse</strong> - Global market trends and analysis</li>
                        </ul>
                        <p>Get started by logging in to your account.</p>
                        <div class="footer">
                            <p>This is an automated email from eCommerce AI Platform. Please do not reply.</p>
                        </div>
                    </div>
                </body>
                </html>
                """, userName);
    }
    
    /**
     * Build text body for welcome email
     */
    private String buildWelcomeTextBody(String userName) {
        return String.format("""
                Welcome to eCommerce AI Platform!
                
                Hello %s,
                
                Thank you for registering with eCommerce AI Platform.
                
                You now have access to our five integrated AI systems:
                - Market Intelligence Hub - Market intelligence and forecasting
                - Demand Insights Engine - Customer insights and demand forecasting
                - Compliance Guardian - Risk analysis and compliance monitoring
                - Retail Copilot - AI assistant for retail teams
                - Global Market Pulse - Global market trends and analysis
                
                Get started by logging in to your account.
                
                ---
                This is an automated email from eCommerce AI Platform. Please do not reply.
                """, userName);
    }
}
