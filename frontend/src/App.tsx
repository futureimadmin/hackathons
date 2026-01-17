import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import Login from './pages/Login.tsx';
import Register from './pages/Register.tsx';
import ForgotPassword from './pages/ForgotPassword.tsx';
import Home from './pages/Home.tsx';
import MarketIntelligenceHub from './pages/dashboards/MarketIntelligenceHub.tsx';
import DemandInsightsEngine from './pages/dashboards/DemandInsightsEngine.tsx';
import ComplianceGuardian from './pages/dashboards/ComplianceGuardian.tsx';
import RetailCopilot from './pages/dashboards/RetailCopilot.tsx';
import GlobalMarketPulse from './pages/dashboards/GlobalMarketPulse.tsx';
import Architecture from './pages/Architecture.tsx';
import PrivateRoute from './components/PrivateRoute.tsx';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          
          <Route path="/home" element={
            <PrivateRoute>
              <Home />
            </PrivateRoute>
          } />
          
          <Route path="/dashboard/market-intelligence-hub" element={
            <PrivateRoute>
              <MarketIntelligenceHub />
            </PrivateRoute>
          } />
          
          <Route path="/dashboard/demand-insights-engine" element={
            <PrivateRoute>
              <DemandInsightsEngine />
            </PrivateRoute>
          } />
          
          <Route path="/dashboard/compliance-guardian" element={
            <PrivateRoute>
              <ComplianceGuardian />
            </PrivateRoute>
          } />
          
          <Route path="/dashboard/retail-copilot" element={
            <PrivateRoute>
              <RetailCopilot />
            </PrivateRoute>
          } />
          
          <Route path="/dashboard/global-market-pulse" element={
            <PrivateRoute>
              <GlobalMarketPulse />
            </PrivateRoute>
          } />
          
          <Route path="/architecture" element={<Architecture />} />
          
          <Route path="/" element={<Navigate to="/login" replace />} />
        </Routes>
      </Router>
    </ThemeProvider>
  );
}

export default App;
