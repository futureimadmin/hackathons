import { Box, Typography, Button, Paper } from '@mui/material';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';

interface ErrorStateProps {
  message?: string;
  onRetry?: () => void;
}

const ErrorState = ({ 
  message = 'An error occurred while loading data', 
  onRetry 
}: ErrorStateProps) => {
  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '400px',
        p: 3
      }}
    >
      <Paper
        elevation={2}
        sx={{
          p: 4,
          textAlign: 'center',
          maxWidth: 500
        }}
      >
        <ErrorOutlineIcon 
          sx={{ 
            fontSize: 80, 
            color: 'error.main',
            mb: 2 
          }} 
        />
        <Typography variant="h5" gutterBottom color="error">
          Error
        </Typography>
        <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
          {message}
        </Typography>
        {onRetry && (
          <Button 
            variant="contained" 
            color="primary" 
            onClick={onRetry}
          >
            Try Again
          </Button>
        )}
      </Paper>
    </Box>
  );
};

export default ErrorState;
