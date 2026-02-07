import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid, Alert, CircularProgress, Box } from '@mui/material';
import { useEffect, useState } from 'react';
import Navigation from '../../components/Navigation';
import Chart from '../../components/Chart';
import DataTable, { Column } from '../../components/DataTable';
import { globalMarketService, MarketTrend, RegionalPrice, MarketOpportunity } from '../../services/globalMarketService';

const priceColumns: Column[] = [
  { id: 'region', label: 'Region' },
  { id: 'product_name', label: 'Product' },
  { id: 'avg_price', label: 'Avg Price', align: 'right', format: (val) => `$${val.toFixed(2)}` },
  { id: 'currency', label: 'Currency' },
];

const opportunityColumns: Column[] = [
  { id: 'region', label: 'Region' },
  { id: 'product_category', label: 'Category' },
  { id: 'opportunity_score', label: 'Score', align: 'right', format: (val) => val.toFixed(2) },
  { id: 'recommendation', label: 'Recommendation' },
];

const GlobalMarketPulse = () => {
  const location = useLocation();
  const { userName } = location.state || {};

  const [trends, setTrends] = useState<MarketTrend[]>([]);
  const [prices, setPrices] = useState<RegionalPrice[]>([]);
  const [opportunities, setOpportunities] = useState<MarketOpportunity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [trendsResponse, pricesResponse, opportunitiesResponse] = await Promise.all([
        globalMarketService.getTrends(),
        globalMarketService.getRegionalPrices(),
        globalMarketService.getOpportunities({}),
      ]);

      setTrends(trendsResponse.trends);
      setPrices(pricesResponse.prices);
      setOpportunities(opportunitiesResponse.opportunities);
    } catch (err: any) {
      console.error('Error loading dashboard data:', err);
      setError(err.response?.data?.error || err.message || 'Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Navigation title="Global Market Pulse" userName={userName} />

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Global Market Pulse Dashboard
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Global and regional market trends and price analysis
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
                title="Market Trends by Region"
                data={trends}
                type="line"
                xKey="region"
                yKeys={['trend_score', 'growth_rate']}
                colors={['#1976d2', '#4caf50']}
              />
            </Grid>

            <Grid item xs={12} md={6}>
              <Chart
                title="Regional Price Comparison"
                data={prices}
                type="bar"
                xKey="region"
                yKeys={['avg_price']}
              />
            </Grid>

            <Grid item xs={12}>
              <DataTable
                title="Regional Prices"
                columns={priceColumns}
                rows={prices}
              />
            </Grid>

            <Grid item xs={12}>
              <DataTable
                title="Market Opportunities"
                columns={opportunityColumns}
                rows={opportunities}
              />
            </Grid>
          </Grid>
        )}
      </Container>
    </>
  );
};

export default GlobalMarketPulse;
