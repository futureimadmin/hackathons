import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Paper, Typography, Box } from '@mui/material';

export type ChartType = 'line' | 'bar';

export interface ChartDataPoint {
  [key: string]: string | number;
}

interface ChartProps {
  title: string;
  data: ChartDataPoint[];
  type?: ChartType;
  xKey: string;
  yKeys: string[];
  colors?: string[];
  height?: number;
}

const Chart = ({ 
  title, 
  data, 
  type = 'line', 
  xKey, 
  yKeys, 
  colors = ['#1976d2', '#dc004e', '#4caf50', '#ff9800', '#9c27b0'],
  height = 300 
}: ChartProps) => {
  const ChartComponent = type === 'line' ? LineChart : BarChart;

  return (
    <Paper elevation={2} sx={{ p: 2, mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        {title}
      </Typography>
      <Box sx={{ width: '100%', height }}>
        <ResponsiveContainer>
          <ChartComponent data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey={xKey} />
            <YAxis />
            <Tooltip />
            <Legend />
            {type === 'line' ? (
              yKeys.map((key, index) => (
                <Line
                  key={key}
                  type="monotone"
                  dataKey={key}
                  stroke={colors[index % colors.length]}
                />
              ))
            ) : (
              yKeys.map((key, index) => (
                <Bar
                  key={key}
                  dataKey={key}
                  fill={colors[index % colors.length]}
                />
              ))
            )}
          </ChartComponent>
        </ResponsiveContainer>
      </Box>
    </Paper>
  );
};

export default Chart;
