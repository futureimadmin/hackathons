import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid, Alert, CircularProgress, Box } from '@mui/material';
import { useEffect, useState } from 'react';
import Navigation from '../../components/Navigation';
import Chart from '../../components/Chart';
import DataTable, { Column } from '../../components/DataTable';
import { complianceService, HighRiskTransaction, FraudStatistics } from '../../services/complianceService';

const transactionColumns: Column[] = [
  { id: 'transaction_id', label: 'Transaction ID' },
  { id: 'customer_id', label: 'Customer ID' },
  { id: 'amount', label: 'Amount', align: 'right', format: (val) => `$${val.toFixed(2)}` },
  { id: 'risk_score', label: 'Risk Score', align: 'right', format: (val) => val.toFixed(2) },
  { id: 'timestamp', label: 'Timestamp' },
];

const ComplianceGuardian = () => {
  const location = useLocation();
  const { userName } = location.state || {};

  const [highRiskTransactions, setHighRiskTransactions] = useState<HighRiskTransaction[]>([]);
  const [fraudStats, setFraudStats] = useState<FraudStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [transactionsResponse, statsResponse] = await Promise.all([
        complianceService.getHighRiskTransactions(),
        complianceService.getFraudStatistics(),
      ]);

      setHighRiskTransactions(transactionsResponse.transactions);
      setFraudStats(statsResponse);
    } catch (err: any) {
      console.error('Error loading dashboard data:', err);
      setError(err.response?.data?.error || err.message || 'Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const statsData = fraudStats ? [
    { metric: 'Total Transactions', value: fraudStats.total_transactions },
    { metric: 'Fraud Detected', value: fraudStats.fraud_detected },
    { metric: 'Fraud Rate', value: (fraudStats.fraud_rate * 100).toFixed(2) + '%' },
    { metric: 'Loss Prevented', value: `$${fraudStats.total_loss_prevented.toFixed(2)}` },
  ] : [];

  return (
    <>
      <Navigation title="Compliance Guardian" userName={userName} />

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Compliance Guardian Dashboard
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          Risk analysis, compliance monitoring, and fraud detection
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
                title="Fraud Statistics"
                data={statsData}
                type="bar"
                xKey="metric"
                yKeys={['value']}
              />
            </Grid>

            <Grid item xs={12} md={6}>
              <Chart
                title="Risk Score Distribution"
                data={highRiskTransactions.map(t => ({ id: t.transaction_id, risk: t.risk_score }))}
                type="bar"
                xKey="id"
                yKeys={['risk']}
              />
            </Grid>

            <Grid item xs={12}>
              <DataTable
                title="High-Risk Transactions"
                columns={transactionColumns}
                rows={highRiskTransactions}
              />
            </Grid>
          </Grid>
        )}
      </Container>
    </>
  );
};

export default ComplianceGuardian;
