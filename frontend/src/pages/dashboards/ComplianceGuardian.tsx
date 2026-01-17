import { useLocation, useNavigate } from 'react-router-dom';
import { Container, Typography, AppBar, Toolbar, IconButton, Box, Paper, Grid } from '@mui/material';
import { ArrowBack } from '@mui/icons-material';

const ComplianceGuardian = () => {
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
            Compliance Guardian
          </Typography>
          <Typography variant="body2">User: {userName} (ID: {userId})</Typography>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>Compliance Guardian Dashboard</Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Risk analysis, compliance monitoring, and document understanding
        </Typography>

        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 3 }}>
              <Typography variant="h6" gutterBottom>Fraud Detection</Typography>
              <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1, minHeight: 200 }}>
                <Typography variant="caption">Isolation Forest anomaly detection</Typography>
              </Box>
            </Paper>
          </Grid>
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 3 }}>
              <Typography variant="h6" gutterBottom>Risk Scoring</Typography>
              <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1, minHeight: 200 }}>
                <Typography variant="caption">Transaction risk scores (0-100)</Typography>
              </Box>
            </Paper>
          </Grid>
        </Grid>
      </Container>
    </>
  );
};

export default ComplianceGuardian;
