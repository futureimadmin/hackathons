import { Navigate } from 'react-router-dom';
import authService from '../services/authService';

interface PrivateRouteProps {
  children: React.ReactNode;
}

const PrivateRoute: React.FC<PrivateRouteProps> = ({ children }) => {
  const isAuthenticated = authService.isAuthenticated();
  
  console.log('PrivateRoute check:', {
    isAuthenticated,
    token: authService.getToken(),
    user: authService.getCurrentUser()
  });

  if (!isAuthenticated) {
    console.log('Not authenticated, redirecting to login');
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
};

export default PrivateRoute;
