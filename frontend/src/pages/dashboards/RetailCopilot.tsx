import { useLocation, useNavigate } from 'react-router-dom';
import { Container, Typography, AppBar, Toolbar, IconButton, Box, Paper } from '@mui/material';
import { ArrowBack } from '@mui/icons-material';

const RetailCopilot = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { userId, userName } = location.state || {};

  return (
    <>
      <AppBar position="static">
        <Toolbar>
          <IconButton edge="start" color="inherit" onClick={() => navigate('/home')} sx={{ mr: 2 }}>
            <ArrowBack />
          </IconButton>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            Retail Copilot
          </Typography>
          <Typography variant="body2">User: {userName} (ID: {userId})</Typography>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>Retail Copilot Dashboard</Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          AI assistant for retail teams - Natural language queries and insights
        </Typography>

        <Paper sx={{ p: 3, minHeight: 500 }}>
          <Typography variant="h6" gutterBottom>Chat Interface</Typography>
          <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1, minHeight: 400 }}>
            <Typography variant="caption">
              Chat interface placeholder - Integrate with LLM for natural language queries
            </Typography>
          </Box>
        </Paper>
      </Container>
    </>
  );
};

export default RetailCopilot;
