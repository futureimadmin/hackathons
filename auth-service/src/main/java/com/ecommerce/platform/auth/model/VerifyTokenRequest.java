package com.ecommerce.platform.auth.model;

public class VerifyTokenRequest {
    private String token;
    
    public VerifyTokenRequest() {}
    
    public VerifyTokenRequest(String token) {
        this.token = token;
    }
    
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
}
