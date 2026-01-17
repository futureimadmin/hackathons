# eCommerce AI Analytics Platform - Frontend

React + TypeScript frontend for the eCommerce AI Analytics Platform.

## Features

- ✅ User authentication (login, register, forgot password)
- ✅ JWT token management with automatic expiration checking
- ✅ Home page with 5 system cards
- ✅ Protected routes with authentication
- ✅ Dashboard navigation with user context
- ✅ Material-UI components
- ✅ Responsive design
- ✅ TypeScript for type safety

## Tech Stack

- **React 18** - UI library
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **React Router 6** - Client-side routing
- **Material-UI (MUI)** - Component library
- **Axios** - HTTP client
- **Recharts** - Charting library (ready to integrate)

## Prerequisites

- Node.js 18+ and npm
- API Gateway URL from backend deployment

## Setup

### 1. Install Dependencies

```powershell
cd frontend
npm install
```

### 2. Configure Environment

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and set your API Gateway URL:

```
VITE_API_URL=https://your-api-id.execute-api.us-east-1.amazonaws.com/prod
```

### 3. Run Development Server

```powershell
npm run dev
```

The app will open at `http://localhost:3000`

### 4. Build for Production

```powershell
npm run build
```

Output will be in `dist/` directory.

### 5. Preview Production Build

```powershell
npm run preview
```

## Project Structure

```
frontend/
├── src/
│   ├── components/          # Reusable components
│   │   └── PrivateRoute.tsx # Protected route wrapper
│   ├── pages/               # Page components
│   │   ├── Login.tsx
│   │   ├── Register.tsx
│   │   ├── ForgotPassword.tsx
│   │   ├── Home.tsx
│   │   └── dashboards/      # Dashboard pages
│   │       ├── MarketIntelligenceHub.tsx
│   │       ├── DemandInsightsEngine.tsx
│   │       ├── ComplianceGuardian.tsx
│   │       ├── RetailCopilot.tsx
│   │       └── GlobalMarketPulse.tsx
│   ├── services/            # API services
│   │   └── authService.ts   # Authentication service
│   ├── App.tsx              # Main app component with routing
│   ├── main.tsx             # Entry point
│   └── index.css            # Global styles
├── index.html               # HTML template
├── package.json             # Dependencies
├── tsconfig.json            # TypeScript config
├── vite.config.ts           # Vite config
└── README.md                # This file
```

## Authentication Flow

### Registration
1. User fills registration form
2. Password validation (8+ chars, uppercase, lowercase, number, special char)
3. POST to `/auth/register`
4. Redirect to login page

### Login
1. User enters email and password
2. POST to `/auth/login`
3. Receive JWT token and user info
4. Store token in localStorage
5. Redirect to home page

### Protected Routes
1. Check if token exists in localStorage
2. Verify token hasn't expired
3. If valid, render protected component
4. If invalid, redirect to login

### Logout
1. Remove token from localStorage
2. Redirect to login page

## Navigation Flow

### Home Page
- Displays 5 system cards
- Each card shows system name, description, and icon
- Click "Open Dashboard" to navigate to system dashboard
- Passes `userId` and `userName` in navigation state

### Dashboard Pages
- Receive user context from navigation state
- Display user info in app bar
- Back button returns to home page
- Placeholder content for charts and data tables

## API Integration

### Auth Service (`src/services/authService.ts`)

```typescript
// Register new user
await authService.register(email, password, name);

// Login
const response = await authService.login(email, password);
// Returns: { token, userId, email, name }

// Forgot password
await authService.forgotPassword(email);

// Get current user
const user = authService.getCurrentUser();

// Check if authenticated
const isAuth = authService.isAuthenticated();

// Logout
authService.logout();
```

## Customization

### Adding New Dashboard Features

1. Create component in `src/components/`
2. Import in dashboard page
3. Add data fetching logic
4. Integrate with Recharts for visualizations

### Adding New Routes

1. Add route in `src/App.tsx`
2. Create page component in `src/pages/`
3. Wrap with `<PrivateRoute>` if authentication required

### Styling

- Uses Material-UI theme (customizable in `App.tsx`)
- Global styles in `src/index.css`
- Component-specific styles using MUI's `sx` prop

## Testing

### Manual Testing Checklist

- [ ] Registration with valid data
- [ ] Registration with weak password (should fail)
- [ ] Registration with duplicate email (should fail)
- [ ] Login with correct credentials
- [ ] Login with wrong password (should fail)
- [ ] Forgot password flow
- [ ] Protected route access without login (should redirect)
- [ ] Home page displays 5 system cards
- [ ] Navigation to each dashboard
- [ ] User context passed to dashboards
- [ ] Logout functionality
- [ ] Token expiration handling

## Deployment

### Option 1: AWS S3 + CloudFront

```powershell
# Build
npm run build

# Upload to S3
aws s3 sync dist/ s3://your-bucket-name --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*"
```

### Option 2: AWS Amplify

```powershell
# Install Amplify CLI
npm install -g @aws-amplify/cli

# Initialize Amplify
amplify init

# Add hosting
amplify add hosting

# Publish
amplify publish
```

### Option 3: Vercel/Netlify

Connect your Git repository and deploy automatically.

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| VITE_API_URL | API Gateway base URL | https://abc123.execute-api.us-east-1.amazonaws.com/prod |
| VITE_ENV | Environment name | development, production |

## Troubleshooting

### CORS Errors

**Problem:** Browser blocks API requests

**Solution:**
- Verify API Gateway CORS configuration
- Check `cors_allowed_origin` in Terraform
- Ensure API Gateway returns correct CORS headers

### Token Expiration

**Problem:** User logged out unexpectedly

**Solution:**
- JWT tokens expire after 1 hour
- Implement token refresh logic
- Or prompt user to login again

### Build Errors

**Problem:** TypeScript compilation errors

**Solution:**
```powershell
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install

# Check TypeScript version
npm list typescript
```

## Next Steps

1. ✅ Task 13.1-13.7 complete - Full frontend implementation with components and tests
2. ➡️ Integrate with analytics API (Task 16)
3. ➡️ Implement dashboard features for each system (Tasks 17-21)
4. ➡️ Deploy to AWS (S3 + CloudFront or Amplify)

## References

- [React Documentation](https://react.dev/)
- [Material-UI Documentation](https://mui.com/)
- [React Router Documentation](https://reactrouter.com/)
- [Vite Documentation](https://vitejs.dev/)
- [Recharts Documentation](https://recharts.org/)
