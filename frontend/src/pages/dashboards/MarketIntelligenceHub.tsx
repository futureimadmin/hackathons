import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid } from '@mui/material';
import Navigation from '../../components/Navigation';
import Chart from '../../components/Chart';
import DataTable, { Column } from '../../components/DataTable';

// Sample data for demonstration
const trendData = [
  { month: 'Jan', sales: 4000, revenue: 2400 },
  { month: 'Feb', sales: 3000, revenue: 1398 },
  { month: 'Mar', sales: 2000, revenue: 9800 },
  { month: 'Apr', sales: 2780, revenue: 3908 },
  { month: 'May', sales: 1890, revenue: 4800 },
  { month: 'Jun', sales: 2390, revenue: 3800 },
];

const forecastData = [
  { month: 'Jul', actual: 2400, forecast: 2500, lower: 2200, upper: 2800 },
  { month: 'Aug', actual: 2210, forecast: 2300, lower: 2000, upper: 2600 },
  { month: 'Sep', actual: 0, forecast: 2600, lower: 2300, upper: 2900 },
  { month: 'Oct', actual: 0, forecast: 2800, lower: 2500, upper: 3100 },
];

const pricingColumns: Column[] = [
  { id: 'product', label: 'Product' },
  { id: 'ourPrice', label: 'Our Price', align: 'right', format: (val) => `$${val}` },
  { id: 'competitor1', label: 'Competitor 1', align: 'right', format: (val) => `$${val}` },
  { id: 'competitor2', label: 'Competitor 2', align: 'right', format: (val) => `$${val}` },
  { id: 'marketAvg', label: 'Market Avg', align: 'right', format: (val) => `$${val}` },
];

const pricingData = [
  { product: 'Product A', ourPrice: 29.99, competitor1: 32.99, competitor2: 28.99, marketAvg: 30.66 },
  { product: 'Product B', ourPrice: 49.99, competitor1: 45.99, competitor2: 52.99, marketAvg: 49.66 },
  { product: 'Product C', ourPrice: 19.99, competitor1: 22.99, competitor2: 19.99, marketAvg: 20.99 },
  { product: 'Product D', ourPrice: 99.99, competitor1: 95.99, competitor2: 105.99, marketAvg: 100.66 },
];

const MarketIntelligenceHub = () => {
  const location = useLocation();
  const { userName } = location.state || {};

  return (
    <>
      <Navigation title="Market Intelligence Hub" userName={userName} />

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Market Intelligence Hub Dashboard
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Market intelligence, forecasting, and analytics
        </Typography>

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
              title="Sales Forecasting (ARIMA Model)"
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
      </Container>
    </>
  );
};

export default MarketIntelligenceHub;
