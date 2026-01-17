# Frontend Quick Start Guide

## Prerequisites

- Node.js 18+ and npm installed
- API Gateway URL from Task 11 (authentication endpoints)

## Installation

```powershell
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install
```

## Configuration

1. Copy the environment template:
```powershell
cp .env.example .env
```

2. Edit `.env` and set your API Gateway URL:
```env
VITE_API_URL=https://your-api-id.execute-api.us-east-1.amazonaws.com/prod
```

Replace `your-api-id` with your actual API Gateway ID from the Terraform output.

## Development

Start the development server:
```powershell
npm run dev
```

The application will open at `http://localhost:5173`

## Testing

Run the property-based navigation test:
```powershell
# Run tests in watch mode
npm test

# Run tests once
npm run test:run

# Run tests with UI
npm run test:ui
```

## Build for Production

```powershell
npm run build
```

The production build will be in the `dist/` directory.

## Usage

### 1. Register a New User
- Navigate to `http://localhost:5173`
- Click "Don't have an account? Sign Up"
- Enter email, password (8+ chars with uppercase, lowercase, number, special char), and name
- Click "Sign Up"

### 2. Login
- Enter your email and password
- Click "Sign In"
- You'll be redirected to the home page

### 3. Navigate to Dashboards
- Click any of the 5 system cards on the home page
- Each dashboard receives your userId and userName
- Click "Home" to return to the home page
- Click "Logout" to sign out

### 4. Explore Components
- **Market Intelligence Hub** has example charts and tables
- Other dashboards are placeholders ready for data integration

## Troubleshooting

### CORS Errors
If you see CORS errors, verify:
1. API Gateway CORS is configured correctly
2. `cors_allowed_origin` in Terraform matches your frontend URL
3. Preflight OPTIONS requests are working

### Module Not Found Errors
If you see "Cannot find module" errors:
1. Ensure all imports use `.tsx` extensions
2. Check that `vite-env.d.ts` exists in `src/`
3. Restart the TypeScript server in your IDE

### Build Errors
Clear and reinstall dependencies:
```powershell
rm -rf node_modules package-lock.json
npm install
```

### Token Issues
If authentication isn't working:
1. Check localStorage for the JWT token
2. Verify the token hasn't expired (1 hour lifetime)
3. Check that the JWT secret matches between frontend and backend

## Next Steps

1. ✅ Task 13 complete - Frontend ready
2. ➡️ Task 14 - Set up on-premise MySQL database
3. ➡️ Task 15 - Verify end-to-end flow
4. ➡️ Task 16 - Implement analytics service
5. ➡️ Tasks 17-21 - Implement 5 AI systems with real data

## Component Usage

See `src/components/README.md` for detailed component documentation and usage examples.

## Testing

The property-based test validates Requirement 2.4 (user context passing):
- Tests all 5 dashboards with multiple users
- Verifies userId and userName are passed correctly
- Detects missing context scenarios
- Run with `npm test`

## Support

For issues or questions:
1. Check `README.md` for comprehensive documentation
2. Check `IMPLEMENTATION_SUMMARY.md` for implementation details
3. Check `TASK_13_COMPLETE.md` for task completion summary
