package com.ecommerce.platform.auth.util;

import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.util.HashMap;
import java.util.Map;

/**
 * Utility class for building API Gateway responses
 */
public class ResponseBuilder {
    
    private static final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());
    
    private static final Map<String, String> CORS_HEADERS = new HashMap<>() {{
        put("Access-Control-Allow-Origin", "*");
        put("Access-Control-Allow-Headers", "Content-Type,Authorization");
        put("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS");
        put("Content-Type", "application/json");
    }};
    
    public static APIGatewayProxyResponseEvent ok(Object body) {
        return buildResponse(200, body);
    }
    
    public static APIGatewayProxyResponseEvent created(Object body) {
        return buildResponse(201, body);
    }
    
    public static APIGatewayProxyResponseEvent badRequest(String message) {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        return buildResponse(400, error);
    }
    
    public static APIGatewayProxyResponseEvent unauthorized(String message) {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        return buildResponse(401, error);
    }
    
    public static APIGatewayProxyResponseEvent notFound(String message) {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        return buildResponse(404, error);
    }
    
    public static APIGatewayProxyResponseEvent conflict(String message) {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        return buildResponse(409, error);
    }
    
    public static APIGatewayProxyResponseEvent internalServerError(String message) {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        return buildResponse(500, error);
    }
    
    private static APIGatewayProxyResponseEvent buildResponse(int statusCode, Object body) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setStatusCode(statusCode);
        response.setHeaders(CORS_HEADERS);
        
        try {
            String jsonBody = objectMapper.writeValueAsString(body);
            response.setBody(jsonBody);
        } catch (Exception e) {
            response.setBody("{\"error\":\"Failed to serialize response\"}");
            response.setStatusCode(500);
        }
        
        return response;
    }
}
