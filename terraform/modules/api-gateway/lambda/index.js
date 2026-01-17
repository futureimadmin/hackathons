/**
 * JWT Token Authorizer for API Gateway
 * Verifies JWT tokens and generates IAM policies
 */

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const jwt = require('jsonwebtoken');

const secretsManager = new SecretsManagerClient({});
let jwtSecret = null;

/**
 * Get JWT secret from Secrets Manager (cached)
 */
async function getJwtSecret() {
  if (jwtSecret) {
    return jwtSecret;
  }

  const secretName = process.env.JWT_SECRET_NAME;
  
  try {
    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await secretsManager.send(command);
    jwtSecret = response.SecretString;
    return jwtSecret;
  } catch (error) {
    console.error('Error retrieving JWT secret:', error);
    throw new Error('Failed to retrieve JWT secret');
  }
}

/**
 * Generate IAM policy for API Gateway
 */
function generatePolicy(principalId, effect, resource, context = {}) {
  const authResponse = {
    principalId: principalId
  };

  if (effect && resource) {
    authResponse.policyDocument = {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource
        }
      ]
    };
  }

  // Add user context to be passed to Lambda
  if (Object.keys(context).length > 0) {
    authResponse.context = context;
  }

  return authResponse;
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
  console.log('Authorizer event:', JSON.stringify(event, null, 2));

  const token = event.authorizationToken;
  const methodArn = event.methodArn;

  if (!token) {
    console.error('No authorization token provided');
    throw new Error('Unauthorized');
  }

  // Extract token from "Bearer <token>" format
  const tokenParts = token.split(' ');
  const bearerToken = tokenParts.length === 2 && tokenParts[0] === 'Bearer' 
    ? tokenParts[1] 
    : token;

  try {
    // Get JWT secret
    const secret = await getJwtSecret();

    // Verify JWT token
    const decoded = jwt.verify(bearerToken, secret, {
      algorithms: ['HS256']
    });

    console.log('Token verified successfully for user:', decoded.userId);

    // Generate allow policy with user context
    const policy = generatePolicy(
      decoded.userId,
      'Allow',
      methodArn,
      {
        userId: decoded.userId,
        email: decoded.email || '',
        name: decoded.name || ''
      }
    );

    return policy;

  } catch (error) {
    console.error('Token verification failed:', error.message);

    if (error.name === 'TokenExpiredError') {
      console.error('Token expired at:', error.expiredAt);
    } else if (error.name === 'JsonWebTokenError') {
      console.error('Invalid token:', error.message);
    }

    // Return deny policy
    throw new Error('Unauthorized');
  }
};
