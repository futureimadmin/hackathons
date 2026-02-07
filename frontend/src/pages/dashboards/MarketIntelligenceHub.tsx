import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid, Alert, CircularProgress, Box } from '@mui/material';
import { useEffect, useState } from 'react';
import Navigation from '../../components/Navigation';
import Chart from '../../components/Chart';
import DataTable, { Column } from '../../components/DataTable';
import { marketIntelligenceService, TrendData, ForecastData, PricingData } from '../../services/marketIntelligenceService';

const pricingColumns: Column[] = [
  { id: 'product', label: 'Product' },
  { id: 'ourPrice', label: 'Our Price', align: 'right', format: (val) => `$${val}` },
  { id: 'competitor1', label: 'Competitor 1', align: 'right', format: (val) => `$${val}` },
  { id: 'competitor2', label: 'Competitor 2', align: 'right', format: (val) => `$${val}` },
  { id: 'marketAvg', label: 'Market Avg', align: 'right', format: (val) => `$${val}` },
];

const MarketIntelligenceHub = () => {
  const location = useLocation();
  const { userName } = location.state || {};

  const [trendData, setTrendData] = useState<TrendData[]>([]);
  const [forecastData, setForecastData] = useState<ForecastData[]>([]);
  const [pricingData, setPricingData] = useState<PricingData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Load all data in parallel
      const [trendsResponse, forecastResponse, pricingResponse] = await Promise.all([
        marketIntelligenceService.getTrends(),
        marketIntelligenceService.generateForecast({ horizon: 30, model: 'auto' }),
        marketIntelligenceService.getCompetitivePricing(),
      ]);

      setTrendData(trendsResponse.trends);
      setForecastData(forecastResponse.forecast);
      setPricingData(pricingResponse.pricing);
    } catch (err: any) {
      console.error('Error loading dashboard data:', err);
      setError(err.response?.data?.error || err.message || 'Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Navigation title="Market Intelligence Hub" userName={userName} />

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Market Intelligence Hub Dashboard
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Market intelligence, forecasting, and analytics powered by real-time data
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 3 }}>
            {error}
          </Alert>
        )}

        {loading ? (
          <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
            <CircularProgress />
          </Box>
        ) : (
          <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
              <Chart
                title="Market Trends"
                data={trendData}
                type="line"
                xKey="month"
                yKeys={['sales', 'revenue']}
              />
            </Grid>

            <Grid item xs={12} md={6}>
              <Chart
                title="Sales Forecasting (AI Model)"
                data={forecastData}
                type="line"
                xKey="month"
                yKeys={['actual', 'forecast', 'lower', 'upper']}
                colors={['#1976d2', '#dc004e', '#4caf50', '#ff9800']}
              />
            </Grid>

            <Grid item xs={12}>
              <DataTable
                title="Competitive Pricing Analysis"
                columns={pricingColumns}
                rows={pricingData}
              />
            </Grid>
          </Grid>
        )}
      </Container>
    </>
  );
};

export default MarketIntelligenceHub;
