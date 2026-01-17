import { useLocation, useNavigate } from 'react-router-dom';
import { Container, Typography, AppBar, Toolbar, IconButton, Box, Paper, Grid } from '@mui/material';
import { ArrowBack } from '@mui/icons-material';

const DemandInsightsEngine = () => {
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
            Demand Insights Engine
          </Typography>
          <Typography variant="body2">User: {userName} (ID: {userId})</Typography>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>Demand Insights Engine Dashboard</Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Customer insights, demand forecasting, and pricing intelligence
        </Typography>

        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 3 }}>
              <Typography variant="h6" gutterBottom>Customer Segmentation</Typography>
              <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1, minHeight: 200 }}>
                <Typography variant="caption">K-Means clustering visualization</Typography>
              </Box>
            </Paper>
          </Grid>
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 3 }}>
              <Typography variant="h6" gutterBottom>Demand Forecasting</Typography>
              <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1, minHeight: 200 }}>
                <Typography variant="caption">XGBoost forecasting results</Typography>
              </Box>
            </Paper>
          </Grid>
        </Grid>
      </Container>
    </>
  );
};

export default DemandInsightsEngine;
