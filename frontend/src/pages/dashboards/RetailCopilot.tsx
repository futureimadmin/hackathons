import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid, Alert, CircularProgress, Box, TextField, Button, Paper, List, ListItem, ListItemText } from '@mui/material';
import { useEffect, useState } from 'react';
import Navigation from '../../components/Navigation';
import DataTable, { Column } from '../../components/DataTable';
import { retailCopilotService, ChatMessage, InventoryInsight, SalesReport } from '../../services/retailCopilotService';

const inventoryColumns: Column[] = [
  { id: 'product_name', label: 'Product' },
  { id: 'stock_level', label: 'Stock', align: 'right' },
  { id: 'reorder_point', label: 'Reorder Point', align: 'right' },
  { id: 'status', label: 'Status' },
];

const RetailCopilot = () => {
  const location = useLocation();
  const { userName } = location.state || {};

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [conversationId, setConversationId] = useState<string | undefined>();
  const [inventory, setInventory] = useState<InventoryInsight[]>([]);
  const [salesReport, setSalesReport] = useState<SalesReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [chatLoading, setChatLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [inventoryResponse, salesResponse] = await Promise.all([
        retailCopilotService.getInventoryInsights(),
        retailCopilotService.getSalesReport(),
      ]);

      setInventory(inventoryResponse.insights);
      setSalesReport(salesResponse);
    } catch (err: any) {
      console.error('Error loading dashboard data:', err);
      setError(err.response?.data?.error || err.message || 'Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const handleSendMessage = async () => {
    if (!inputMessage.trim()) return;

    const userMessage: ChatMessage = {
      role: 'user',
      content: inputMessage,
      timestamp: new Date().toISOString(),
    };

    setMessages([...messages, userMessage]);
    setInputMessage('');
    setChatLoading(true);

    try {
      const response = await retailCopilotService.chat({
        message: inputMessage,
        conversation_id: conversationId,
      });

      const assistantMessage: ChatMessage = {
        role: 'assistant',
        content: response.response,
        timestamp: new Date().toISOString(),
      };

      setMessages([...messages, userMessage, assistantMessage]);
      setConversationId(response.conversation_id);
    } catch (err: any) {
      console.error('Error sending message:', err);
      const errorMessage: ChatMessage = {
        role: 'assistant',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: new Date().toISOString(),
      };
      setMessages([...messages, userMessage, errorMessage]);
    } finally {
      setChatLoading(false);
    }
  };

  return (
    <>
      <Navigation title="Retail Copilot" userName={userName} />

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Retail Copilot Dashboard
        </Typography>
        <Typography variant="body1" color="text.secondary" paragraph>
          AI assistant for retail teams - Natural language queries and insights
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
              <Paper sx={{ p: 3, height: 500, display: 'flex', flexDirection: 'column' }}>
                <Typography variant="h6" gutterBottom>
                  Chat with Copilot
                </Typography>
                <List sx={{ flexGrow: 1, overflow: 'auto', mb: 2 }}>
                  {messages.map((msg, idx) => (
                    <ListItem key={idx} sx={{ flexDirection: 'column', alignItems: msg.role === 'user' ? 'flex-end' : 'flex-start' }}>
                      <Paper sx={{ p: 2, bgcolor: msg.role === 'user' ? 'primary.light' : 'grey.100', maxWidth: '80%' }}>
                        <ListItemText primary={msg.content} />
                      </Paper>
                    </ListItem>
                  ))}
                </List>
                <Box sx={{ display: 'flex', gap: 1 }}>
                  <TextField
                    fullWidth
                    value={inputMessage}
                    onChange={(e) => setInputMessage(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                    placeholder="Ask me anything about your retail data..."
                    disabled={chatLoading}
                  />
                  <Button variant="contained" onClick={handleSendMessage} disabled={chatLoading}>
                    Send
                  </Button>
                </Box>
              </Paper>
            </Grid>

            <Grid item xs={12} md={6}>
              <Paper sx={{ p: 3 }}>
                <Typography variant="h6" gutterBottom>
                  Sales Summary
                </Typography>
                {salesReport && (
                  <Box>
                    <Typography>Period: {salesReport.period}</Typography>
                    <Typography>Total Sales: ${salesReport.total_sales.toFixed(2)}</Typography>
                    <Typography>Total Orders: {salesReport.total_orders}</Typography>
                    <Typography>Avg Order Value: ${salesReport.avg_order_value.toFixed(2)}</Typography>
                  </Box>
                )}
              </Paper>
            </Grid>

            <Grid item xs={12}>
              <DataTable
                title="Inventory Status"
                columns={inventoryColumns}
                rows={inventory}
              />
            </Grid>
          </Grid>
        )}
      </Container>
    </>
  );
};

export default RetailCopilot;
