# Common Components

This directory contains reusable React components used throughout the application.

## Components

### Navigation
Navigation bar with user info, home button, and logout functionality.

**Props:**
- `title` (string, required): Title to display in the navigation bar
- `userName` (string, optional): Name of the logged-in user
- `showHome` (boolean, optional, default: true): Whether to show the home button

**Example:**
```tsx
import Navigation from '../components/Navigation';

<Navigation title="Market Intelligence Hub" userName="John Doe" />
```

### Chart
Wrapper around Recharts for displaying line and bar charts.

**Props:**
- `title` (string, required): Chart title
- `data` (ChartDataPoint[], required): Array of data points
- `type` (ChartType, optional, default: 'line'): Chart type ('line' or 'bar')
- `xKey` (string, required): Key for X-axis data
- `yKeys` (string[], required): Keys for Y-axis data series
- `colors` (string[], optional): Colors for each data series
- `height` (number, optional, default: 300): Chart height in pixels

**Example:**
```tsx
import Chart from '../components/Chart';

const data = [
  { month: 'Jan', sales: 4000, revenue: 2400 },
  { month: 'Feb', sales: 3000, revenue: 1398 },
];

<Chart
  title="Sales Trends"
  data={data}
  type="line"
  xKey="month"
  yKeys={['sales', 'revenue']}
  colors={['#1976d2', '#dc004e']}
/>
```

### DataTable
Paginated table component with customizable columns.

**Props:**
- `title` (string, required): Table title
- `columns` (Column[], required): Column definitions
- `rows` (any[], required): Data rows
- `rowsPerPageOptions` (number[], optional, default: [5, 10, 25, 50]): Pagination options

**Column Interface:**
```tsx
interface Column {
  id: string;              // Key in row data
  label: string;           // Column header label
  align?: 'left' | 'right' | 'center';  // Text alignment
  format?: (value: any) => string;      // Value formatter
}
```

**Example:**
```tsx
import DataTable, { Column } from '../components/DataTable';

const columns: Column[] = [
  { id: 'product', label: 'Product' },
  { id: 'price', label: 'Price', align: 'right', format: (val) => `$${val}` },
];

const rows = [
  { product: 'Product A', price: 29.99 },
  { product: 'Product B', price: 49.99 },
];

<DataTable
  title="Product Pricing"
  columns={columns}
  rows={rows}
/>
```

### Loading
Loading spinner with optional message.

**Props:**
- `message` (string, optional, default: 'Loading...'): Message to display

**Example:**
```tsx
import Loading from '../components/Loading';

{isLoading && <Loading message="Fetching data..." />}
```

### ErrorState
Error display with optional retry button.

**Props:**
- `message` (string, optional, default: 'An error occurred while loading data'): Error message
- `onRetry` (function, optional): Callback function for retry button

**Example:**
```tsx
import ErrorState from '../components/ErrorState';

{error && (
  <ErrorState
    message="Failed to load dashboard data"
    onRetry={() => fetchData()}
  />
)}
```

### PrivateRoute
Route wrapper that requires authentication.

**Props:**
- `children` (ReactNode, required): Components to render if authenticated

**Example:**
```tsx
import PrivateRoute from '../components/PrivateRoute';

<Route path="/dashboard" element={
  <PrivateRoute>
    <Dashboard />
  </PrivateRoute>
} />
```

## Usage Patterns

### Dashboard Page Template
```tsx
import { useLocation } from 'react-router-dom';
import { Container, Typography, Grid } from '@mui/material';
import Navigation from '../../components/Navigation';
import Chart from '../../components/Chart';
import DataTable from '../../components/DataTable';
import Loading from '../../components/Loading';
import ErrorState from '../../components/ErrorState';

const MyDashboard = () => {
  const location = useLocation();
  const { userName } = location.state || {};
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [data, setData] = useState([]);

  useEffect(() => {
    fetchData()
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <Loading />;
  if (error) return <ErrorState message={error.message} onRetry={fetchData} />;

  return (
    <>
      <Navigation title="My Dashboard" userName={userName} />
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Dashboard Title
        </Typography>
        
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <Chart
              title="Chart Title"
              data={data}
              type="line"
              xKey="x"
              yKeys={['y1', 'y2']}
            />
          </Grid>
          
          <Grid item xs={12}>
            <DataTable
              title="Table Title"
              columns={columns}
              rows={rows}
            />
          </Grid>
        </Grid>
      </Container>
    </>
  );
};
```

## Styling

All components use Material-UI's styling system. You can customize them using the `sx` prop:

```tsx
<Chart
  title="Custom Chart"
  data={data}
  xKey="x"
  yKeys={['y']}
  sx={{ mb: 4 }}  // Add margin bottom
/>
```

## Testing

Components are tested using Vitest and React Testing Library. See `src/__tests__/navigation.test.tsx` for examples.

## Future Enhancements

- Add more chart types (pie, area, scatter)
- Add export functionality (CSV, PDF)
- Add filtering and sorting to DataTable
- Add dark mode support
- Add responsive breakpoints for mobile
