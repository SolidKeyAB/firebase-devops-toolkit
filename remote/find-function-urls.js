// Find Correct Function URLs
// Test different URL patterns to find the correct function endpoints

const { GoogleAuth } = require('google-auth-library');
const https = require('https');

// Test different URL patterns (region/project are configurable via env)
const REGION = process.env.FUNCTIONS_REGION || 'europe-west1';
const PROJECT = process.env.FIREBASE_PROJECT || process.env.PROJECT_ID || 'your-firebase-project-id';
const HOST = `${REGION}-${PROJECT}.cloudfunctions.net`;

const URL_PATTERNS = [
  // Pattern 1: Direct function names
  `https://${HOST}/orchestratorService`,
  `https://${HOST}/categoryExtraction`,
  `https://${HOST}/productExtraction`,

  // Pattern 2: With function prefix
  `https://${HOST}/function-orchestratorService`,
  `https://${HOST}/function-categoryExtraction`,
  `https://${HOST}/function-productExtraction`,

  // Pattern 3: With service suffix
  `https://${HOST}/orchestrator-service`,
  `https://${HOST}/category-extraction`,
  `https://${HOST}/product-extraction`,

  // Pattern 4: Lowercase
  `https://${HOST}/orchestratorservice`,
  `https://${HOST}/categoryextraction`,
  `https://${HOST}/productextraction`,

  // Pattern 5: With region prefix
  `https://${HOST}/${REGION}-orchestratorService`,
  `https://${HOST}/${REGION}-categoryExtraction`,
  `https://${HOST}/${REGION}-productExtraction`
];

async function getAccessToken() {
  try {
    const auth = new GoogleAuth({
      scopes: [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/firebase',
        'https://www.googleapis.com/auth/datastore'
      ]
    });
    
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    return token.token;
  } catch (error) {
    console.error('❌ Error getting access token:', error.message);
    return null;
  }
}

async function testUrl(url) {
  try {
    const token = await getAccessToken();
    
    if (!token) {
      return { url, status: 'NO_TOKEN', error: 'Could not get access token' };
    }
    
    return new Promise((resolve) => {
      const options = {
        hostname: HOST,
        port: 443,
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      };
      
      // Extract path from URL
      const path = url.replace(`https://${HOST}`, '');
      
      const req = https.request(options, (res) => {
        let responseBody = '';
        
        res.on('data', (chunk) => {
          responseBody += chunk;
        });
        
        res.on('end', () => {
          resolve({
            url,
            status: res.statusCode,
            response: responseBody.substring(0, 100)
          });
        });
      });
      
      req.on('error', (error) => {
        resolve({
          url,
          status: 'ERROR',
          error: error.message
        });
      });
      
      req.end();
    });
    
  } catch (error) {
    return { url, status: 'ERROR', error: error.message };
  }
}

async function main() {
  console.log('🔍 Finding Correct Function URLs...');
  console.log('=====================================');
  console.log('');
  
  const results = [];
  
  for (const url of URL_PATTERNS) {
    console.log(`🧪 Testing: ${url}`);
    const result = await testUrl(url);
    results.push(result);
    
    if (result.status === 200) {
      console.log(`   ✅ SUCCESS: ${result.status}`);
    } else if (result.status === 403) {
      console.log(`   🔒 FORBIDDEN: ${result.status} (Function exists but requires auth)`);
    } else if (result.status === 401) {
      console.log(`   🔐 UNAUTHORIZED: ${result.status} (Invalid auth)`);
    } else if (result.status === 404) {
      console.log(`   ❌ NOT FOUND: ${result.status}`);
    } else {
      console.log(`   ❓ UNKNOWN: ${result.status}`);
    }
    
    // Small delay between requests
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  console.log('');
  console.log('📊 Results Summary:');
  console.log('====================');
  
  const workingUrls = results.filter(r => r.status === 200 || r.status === 403);
  const notFoundUrls = results.filter(r => r.status === 404);
  const errorUrls = results.filter(r => r.status === 'ERROR' || r.status === 'NO_TOKEN');
  
  console.log(`✅ Working URLs: ${workingUrls.length}`);
  console.log(`❌ Not Found URLs: ${notFoundUrls.length}`);
  console.log(`💥 Error URLs: ${errorUrls.length}`);
  
  if (workingUrls.length > 0) {
    console.log('');
    console.log('🎯 Working URLs:');
    workingUrls.forEach(r => {
      console.log(`   ${r.url} (${r.status})`);
    });
  }
  
  console.log('');
  console.log('💡 Next Steps:');
  console.log('   1. Use the working URLs for pipeline testing');
  console.log('   2. Check Firebase Console for exact function names');
  console.log('   3. Update the pipeline test scripts');
}

// Run the script
main(); 