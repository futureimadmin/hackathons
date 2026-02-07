import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'https://your-api-gateway-url.amazonaws.com/prod';

export interface User {
  userId: string;
  email: string;
  name: string;
}

export interface AuthResponse {
  token: string;
  userId: string;
  email: string;
  name: string;
}

class AuthService {
  async register(email: string, password: string, name: string): Promise<User> {
    const response = await axios.post<User>(`${API_URL}/auth/register`, {
      email,
      password,
      name
    });
    return response.data;
  }

  async login(email: string, password: string): Promise<AuthResponse> {
    const response = await axios.post<AuthResponse>(`${API_URL}/auth/login`, {
      email,
      password
    });
    
    if (response.data.token) {
      localStorage.setItem('token', response.data.token);
      localStorage.setItem('user', JSON.stringify({
        userId: response.data.userId,
        email: response.data.email,
        name: response.data.name
      }));
    }
    
    return response.data;
  }

  async forgotPassword(email: string): Promise<void> {
    await axios.post(`${API_URL}/auth/forgot-password`, { email });
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    await axios.post(`${API_URL}/auth/reset-password`, {
      token,
      newPassword
    });
  }

  logout(): void {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  }

  getCurrentUser(): User | null {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      return JSON.parse(userStr);
    }
    return null;
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  isAuthenticated(): boolean {
    const token = this.getToken();
    if (!token) {
      console.log('No token found');
      return false;
    }

    // Check if token is valid and not expired
    try {
      // Check if it's a JWT (has 3 parts separated by dots)
      const parts = token.split('.');
      if (parts.length === 3) {
        const payload = JSON.parse(atob(parts[1]));
        console.log('Token payload:', payload);
        
        // If token has expiration, check it
        if (payload.exp) {
          const exp = payload.exp * 1000; // Convert to milliseconds
          const isValid = Date.now() < exp;
          console.log('Token expiration check:', { exp: new Date(exp), now: new Date(), isValid });
          return isValid;
        }
        
        // If no expiration (non-expiring token), just check if token exists and is valid JSON
        console.log('Token has no expiration, treating as valid');
        return true;
      } else {
        // Not a JWT format, just check if token exists
        console.log('Token is not JWT format, treating as valid');
        return true;
      }
    } catch (error) {
      // Invalid token format
      console.error('Token validation error:', error);
      return false;
    }
  }
}

export default new AuthService();
