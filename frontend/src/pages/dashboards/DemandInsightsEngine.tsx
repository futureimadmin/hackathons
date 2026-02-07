import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid, Alert, CircularProgress, Box } from '@mui/material';
import { useEffect, useState } from 'react';
import Navigation from '../../components/Navigation';
import Chart from '../../components/Chart';
import DataTable, { Column } from '../../components/DataTable';
import { demandInsightsService, CustomerSegment, DemandForecast, PriceElasticity } from '../../services/demandInsightsService';

const segmentColumns: Column[] = [
  { id: 'segment_name', label: 'Segment' },
  { id: 'customer_count', label: 'Customers', align: 'right' },
  { id: 'avg_clv', label: 'Avg CLV', align: 'right', format: (val) => `$${val.toFixed(2)}` },
  { id: 'characteristics', label: 'Characteristics' },
];

const DemandInsightsEngine = () => {
  const location = useLocation();
  const { userName } = location.state || {};

  const [segments, setSegments] = useState<CustomerSegment[]>([]);
  const [forecasts, setForecasts] = useState<DemandForecast[]>([]);
  const [elasticity, setElasticity] = useState<PriceElasticity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [segmentsResponse, forecastResponse, elasticityResponse] = await Promise.all([
        demandInsightsService.getSegments(),
        demandInsightsService.generateForecast({ horizon: 30 }),
        demandInsightsService.getPriceElasticity({}),
      ]);

      setSegments(segmentsResponse.segments);
      setForecasts(forecastResponse.forecasts);
      setElasticity(elasticityResponse.elasticity);
    } catch (err: any) {
      console.error('Error loading dashboard data:', err);
      setError(err.response?.data?.error || err.message || 'Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Navigation title="Demand Insights Engine" userName={userName} />

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Demand Insights Engine Dashboard
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Customer insights, demand forecasting, and pricing intelligence
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
                title="Demand Forecasting"
                data={forecasts}
                type="line"
                xKey="date"
                yKeys={['forecast_demand', 'lower_bound', 'upper_bound']}
                colors={['#1976d2', '#4caf50', '#ff9800']}
              />
            </Grid>

            <Grid item xs={12} md={6}>
              <Chart
                title="Price Elasticity"
                data={elasticity}
                type="bar"
                xKey="product_name"
                yKeys={['elasticity']}
              />
            </Grid>

            <Grid item xs={12}>
              <DataTable
                title="Customer Segmentation"
                columns={segmentColumns}
                rows={segments}
              />
            </Grid>
          </Grid>
        )}
      </Container>
    </>
  );
};

export default DemandInsightsEngine;
