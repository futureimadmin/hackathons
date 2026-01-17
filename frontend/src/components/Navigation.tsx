import { AppBar, Toolbar, Typography, Button } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import HomeIcon from '@mui/icons-material/Home';
import LogoutIcon from '@mui/icons-material/Logout';
import authService from '../services/authService';

interface NavigationProps {
  title: string;
  userName?: string;
  showHome?: boolean;
}

const Navigation = ({ title, userName, showHome = true }: NavigationProps) => {
  const navigate = useNavigate();

  const handleLogout = () => {
    authService.logout();
    navigate('/login');
  };

  const handleHome = () => {
    navigate('/home');
  };

  return (
    <AppBar position="static">
      <Toolbar>
        <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
          {title}
        </Typography>
        
        {userName && (
          <Typography variant="body1" sx={{ mr: 2 }}>
            Welcome, {userName}
          </Typography>
        )}
        
        {showHome && (
          <Button color="inherit" startIcon={<HomeIcon />} onClick={handleHome}>
            Home
          </Button>
        )}
        
        <Button color="inherit" startIcon={<LogoutIcon />} onClick={handleLogout}>
          Logout
        </Button>
      </Toolbar>
    </AppBar>
  );
};

export default Navigation;
