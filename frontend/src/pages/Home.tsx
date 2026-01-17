import { useNavigate } from 'react-router-dom';
import {
  Container,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  Typography,
  AppBar,
  Toolbar,
  Box,
  IconButton
} from '@mui/material';
import {
  TrendingUp,
  Insights,
  Security,
  SmartToy,
  Public,
  Logout
} from '@mui/icons-material';
import authService from '../services/authService';

interface SystemCardProps {
  title: string;
  description: string;
  icon: React.ReactNode;
  path: string;
}

const SystemCard: React.FC<SystemCardProps> = ({ title, description, icon, path }) => {
  const navigate = useNavigate();
  const user = authService.getCurrentUser();

  const handleNavigate = () => {
    navigate(path, {
      state: {
        userId: user?.userId,
        userName: user?.name
      }
    });
  };

  return (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          {icon}
          <Typography variant="h5" component="h2" sx={{ ml: 1 }}>
            {title}
          </Typography>
        </Box>
        <Typography variant="body2" color="text.secondary">
          {description}
        </Typography>
      </CardContent>
      <CardActions>
        <Button size="small" onClick={handleNavigate}>
          Open Dashboard
        </Button>
      </CardActions>
    </Card>
  );
};

const Home = () => {
  const navigate = useNavigate();
  const user = authService.getCurrentUser();

  const handleLogout = () => {
    authService.logout();
    navigate('/login');
  };

  const systems = [
    {
      title: 'Market Intelligence Hub',
      description: 'Market intelligence, forecasting, and analytics. Analyze market trends, demand forecasting, competitive pricing, and sales forecasting with confidence intervals.',
      icon: <TrendingUp color="primary" fontSize="large" />,
      path: '/dashboard/market-intelligence-hub'
    },
    {
      title: 'Demand Insights Engine',
      description: 'Customer insights, demand forecasting, and pricing intelligence. Customer segmentation, demand forecasting by category, dynamic pricing, CLV predictions, and churn analysis.',
      icon: <Insights color="primary" fontSize="large" />,
      path: '/dashboard/demand-insights-engine'
    },
    {
      title: 'Compliance Guardian',
      description: 'Risk analysis, compliance, and document understanding. PCI DSS compliance monitoring, fraud detection, transaction risk scoring, and NLP-powered document analysis.',
      icon: <Security color="primary" fontSize="large" />,
      path: '/dashboard/compliance-guardian'
    },
    {
      title: 'Retail Copilot',
      description: 'AI assistance for retail teams, marketplaces, and small businesses. Natural language queries about inventory, orders, customers, product recommendations, and sales reports.',
      icon: <SmartToy color="primary" fontSize="large" />,
      path: '/dashboard/retail-copilot'
    },
    {
      title: 'Global Market Pulse',
      description: 'Global and regional market trends and price analysis. Market trend analysis, regional price comparisons, currency impact, market entry opportunities, and competitor analysis.',
      icon: <Public color="primary" fontSize="large" />,
      path: '/dashboard/global-market-pulse'
    }
  ];

  return (
    <>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            eCommerce AI Analytics Platform
          </Typography>
          <Typography variant="body1" sx={{ mr: 2 }}>
            Welcome, {user?.name}
          </Typography>
          <IconButton color="inherit" onClick={handleLogout}>
            <Logout />
          </IconButton>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Select a System
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Choose from our five integrated AI systems to access powerful analytics and insights.
        </Typography>

        <Grid container spacing={3}>
          {systems.map((system) => (
            <Grid item xs={12} md={6} lg={4} key={system.title}>
              <SystemCard {...system} />
            </Grid>
          ))}
        </Grid>
      </Container>
    </>
  );
};

export default Home;
