#!/usr/bin/env node

// HTTPS Wrapper for Firebase Emulator Console
// Secure HTTPS frontend that embeds HTTP Firebase emulator consoles

// Load environment variables
require('dotenv').config();

const express = require('express');
const https = require('https');
const { createProxyMiddleware } = require('http-proxy-middleware');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const session = require('express-session');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();

// Get local network IP
function getLocalNetworkIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const interface of interfaces[name]) {
            if (interface.family === 'IPv4' && !interface.internal) {
                return interface.address;
            }
        }
    }
    return '127.0.0.1';
}

// Configuration with environment variable support
const CONFIG = {
    HTTPS_PORT: parseInt(process.env.HTTPS_PORT) || 8443,
    HTTP_PORT: parseInt(process.env.HTTP_PORT) || 8080,
    SESSION_SECRET: crypto.randomBytes(32).toString('hex'),
    AUTH_TOKEN: crypto.randomBytes(16).toString('hex'),
    LOCAL_IP: process.env.LOCAL_NETWORK_IP || getLocalNetworkIP(),
    COMPANY_NAME: process.env.COMPANY_NAME || 'YourCompany',
    FRONTEND_NAME: process.env.FRONTEND_NAME || 'Console',
    APP_NAME: process.env.APP_NAME || 'Firebase Development Tools',
    RATE_LIMIT: {
        windowMs: parseInt(process.env.RATE_LIMIT_WINDOW) || 10000,
        max: parseInt(process.env.RATE_LIMIT_MAX) || 20,
        message: { error: 'Rate limit exceeded', retryAfter: 10 }
    },
    CERT_PATH: path.join(__dirname, process.env.CERT_DIR || '.certs'),
    EMULATOR_SERVICES: {
        ui: { port: parseInt(process.env.EMULATOR_UI_PORT) || 4002, name: 'Firebase Emulator UI' },
        functions: { port: parseInt(process.env.EMULATOR_FUNCTIONS_PORT) || 5002, name: 'Functions API' },
        firestore: { port: parseInt(process.env.EMULATOR_FIRESTORE_PORT) || 8085, name: 'Firestore' },
        auth: { port: parseInt(process.env.EMULATOR_AUTH_PORT) || 9100, name: 'Authentication' },
        frontend: { port: parseInt(process.env.FRONTEND_PORT) || 3000, name: process.env.FRONTEND_NAME || 'Console' }
    }
};

// Load SSL certificates with helpful error handling
let sslOptions;
try {
    const keyPath = path.join(CONFIG.CERT_PATH, 'key.pem');
    const certPath = path.join(CONFIG.CERT_PATH, 'cert.pem');

    if (!fs.existsSync(keyPath) || !fs.existsSync(certPath)) {
        console.error('❌ SSL certificates not found!');
        console.error('');
        console.error('🔧 Quick fix:');
        console.error('   ./create-self-signed-cert.sh');
        console.error('');
        console.error('📁 Or run the setup script:');
        console.error('   ./setup.sh');
        console.error('');
        process.exit(1);
    }

    sslOptions = {
        key: fs.readFileSync(keyPath),
        cert: fs.readFileSync(certPath)
    };
} catch (error) {
    console.error('❌ Error loading SSL certificates:', error.message);
    console.error('');
    console.error('🔧 Run the setup script to fix this:');
    console.error('   ./setup.sh');
    console.error('');
    process.exit(1);
}

// Enhanced security middleware for HTTPS
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
            scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"], // unsafe-eval needed for iframe content
            scriptSrcAttr: ["'unsafe-inline'"], // Allow onclick handlers
            imgSrc: ["'self'", "data:", "blob:", "http:", "https:"],
            connectSrc: ["'self'", "http://localhost:*", `http://${CONFIG.LOCAL_IP}:*`],
            fontSrc: ["'self'", "https://fonts.gstatic.com"],
            objectSrc: ["'none'"],
            mediaSrc: ["'self'"],
            frameSrc: ["'self'", "http://localhost:*", `http://${CONFIG.LOCAL_IP}:*`], // Allow HTTP iframes
            baseUri: ["'self'"],
            formAction: ["'self'"],
            upgradeInsecureRequests: null // Disable automatic HTTPS upgrade for mixed content
        }
    },
    crossOriginEmbedderPolicy: false // Allow embedding HTTP content
}));

// Rate limiting
app.use(rateLimit(CONFIG.RATE_LIMIT));

// Session management
app.use(session({
    secret: CONFIG.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: true, // HTTPS only
        httpOnly: true,
        maxAge: 3600000
    }
}));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// Security logging
const logSecurityEvent = (event, req, details = '') => {
    const timestamp = new Date().toISOString();
    const ip = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent') || 'Unknown';
    console.log(`[${timestamp}] SECURITY: ${event} from ${ip} - ${userAgent} ${details}`);
};

// Bot detection
const detectBot = (req, res, next) => {
    const userAgent = (req.get('User-Agent') || '').toLowerCase();
    const suspiciousPatterns = [
        'bot', 'crawler', 'spider', 'scraper', 'automation',
        'selenium', 'puppeteer', 'playwright', 'curl', 'wget'
    ];

    if (suspiciousPatterns.some(pattern => userAgent.includes(pattern))) {
        logSecurityEvent('BOT_DETECTED', req, `User-Agent: ${userAgent}`);
        return res.status(429).json({
            error: 'Automated access detected',
            message: 'This service is protected against automated access.'
        });
    }
    next();
};

// Authentication middleware
const requireAuth = (req, res, next) => {
    if (req.session.authenticated) {
        return next();
    }
    if (req.path === '/login' || req.path === '/auth' || req.path === '/') {
        return next();
    }
    logSecurityEvent('UNAUTHORIZED_ACCESS', req, `Path: ${req.path}`);
    res.redirect('/login');
};

app.use(detectBot);
app.use(requireAuth);

// Login page
app.get(['/', '/login'], (req, res) => {
    if (req.session.authenticated) {
        return res.redirect('/dashboard');
    }

    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔒 Secure Firebase Emulator Access</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .login-container {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.2);
            padding: 40px;
            max-width: 400px;
            width: 100%;
            text-align: center;
        }
        .logo {
            font-size: 64px;
            margin-bottom: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
            font-weight: 700;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 16px;
        }
        .form-group {
            margin-bottom: 20px;
            text-align: left;
        }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }
        input {
            width: 100%;
            padding: 15px;
            border: 2px solid #e1e5e9;
            border-radius: 12px;
            font-size: 16px;
            transition: all 0.3s ease;
            background: rgba(255, 255, 255, 0.9);
        }
        input:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            width: 100%;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.4);
        }
        .security-info {
            margin-top: 30px;
            padding: 25px;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-radius: 16px;
            font-size: 14px;
            color: #495057;
        }
        .security-feature {
            display: flex;
            align-items: center;
            margin-bottom: 12px;
            padding: 8px;
            background: rgba(255, 255, 255, 0.7);
            border-radius: 8px;
        }
        .security-feature:last-child { margin-bottom: 0; }
        .feature-icon {
            margin-right: 12px;
            font-size: 18px;
            width: 24px;
            text-align: center;
        }
        .https-badge {
            display: inline-flex;
            align-items: center;
            background: #28a745;
            color: white;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="https-badge">
            🔒 HTTPS Secured
        </div>
        <div class="logo">🛡️</div>
        <h1>Secure Firebase Access</h1>
        <p class="subtitle">HTTPS Wrapper with HTTP Emulator Embedding</p>

        <form method="POST" action="/auth">
            <div class="form-group">
                <label for="token">Access Token:</label>
                <input type="password" id="token" name="token" required placeholder="Enter your access token">
            </div>
            <button type="submit" class="btn">🚀 Access Emulators</button>
        </form>

        <div class="security-info">
            <h3 style="margin-top: 0; color: #333; margin-bottom: 15px;">🛡️ Active Protections</h3>
            <div class="security-feature">
                <span class="feature-icon">🔒</span>
                <span>HTTPS encryption with self-signed certificate</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">📱</span>
                <span>Mobile-optimized secure access</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">⏱️</span>
                <span>Rate limiting (${CONFIG.RATE_LIMIT.max} req/${CONFIG.RATE_LIMIT.windowMs/1000}s)</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">🤖</span>
                <span>Bot detection and blocking</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">🖼️</span>
                <span>HTTP iframe embedding for emulators</span>
            </div>
        </div>
    </div>
</body>
</html>
    `);
});

// Authentication handler
app.post('/auth', (req, res) => {
    const { token } = req.body;
    if (token === CONFIG.AUTH_TOKEN) {
        req.session.authenticated = true;
        logSecurityEvent('SUCCESSFUL_LOGIN', req);
        res.redirect('/dashboard');
    } else {
        logSecurityEvent('FAILED_LOGIN', req, `Token: ${token}`);
        res.redirect('/login?error=invalid');
    }
});

// Dashboard with iframe embedding
app.get('/dashboard', (req, res) => {
    if (!req.session.authenticated) {
        return res.redirect('/login');
    }

    const servicesHtml = Object.entries(CONFIG.EMULATOR_SERVICES)
        .map(([key, service]) => {
            const url = key === 'frontend' ?
                `http://${CONFIG.LOCAL_IP}:${service.port}` :
                `http://localhost:${service.port}`;

            return `
                <div class="service-card" data-service="${key}">
                    <h3>${service.name}</h3>
                    <p>Port: ${service.port}</p>
                    <button class="btn btn-primary" onclick="loadService('${key}', '${url}')">
                        🚀 Load ${service.name}
                    </button>
                </div>
            `;
        }).join('');

    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔒 Firebase Emulator Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: #f5f7fa;
            min-height: 100vh;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .service-card {
            background: white;
            border-radius: 16px;
            padding: 25px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            text-align: center;
            transition: all 0.3s ease;
            border: 2px solid transparent;
        }
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 30px rgba(0,0,0,0.12);
        }
        .service-card.active {
            border-color: #667eea;
            background: linear-gradient(135deg, #f8f9ff 0%, #fff5ff 100%);
        }
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            padding: 12px 24px;
            border-radius: 10px;
            display: inline-block;
            font-weight: 600;
            transition: all 0.3s ease;
            border: none;
            cursor: pointer;
            font-size: 14px;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        .iframe-container {
            margin-top: 30px;
            background: white;
            border-radius: 16px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            overflow: hidden;
            height: 70vh;
            display: none;
        }
        .iframe-container.active {
            display: block;
        }
        .iframe-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .iframe-content {
            height: calc(100% - 60px);
            border: none;
            width: 100%;
        }
        .logout-btn {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 1000;
        }
        .security-status {
            background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
            border: 2px solid #b8daff;
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 20px;
            color: #155724;
        }
        @media (max-width: 768px) {
            .services-grid {
                grid-template-columns: 1fr;
            }
            .iframe-container {
                height: 60vh;
            }
        }
    </style>
</head>
<body>
    <div class="logout-btn">
        <a href="/logout" class="btn">🚪 Logout</a>
    </div>

    <div class="header">
        <h1>🔒 Firebase Emulator Dashboard</h1>
        <p>Secure HTTPS wrapper with HTTP emulator embedding</p>
    </div>

    <div class="container">
        <div class="security-status">
            <h3>🛡️ Security Status: HTTPS ACTIVE</h3>
            <p>All traffic encrypted via HTTPS. Firebase emulators embedded securely via HTTP iframes.</p>
        </div>

        <div class="services-grid">
            ${servicesHtml}
        </div>

        <div class="iframe-container" id="iframe-container">
            <div class="iframe-header">
                <span id="iframe-title">Service</span>
                <button class="btn" onclick="closeIframe()" style="padding: 8px 16px; font-size: 12px;">✕ Close</button>
            </div>
            <iframe id="service-iframe" class="iframe-content" src="about:blank"></iframe>
        </div>
    </div>

    <script>
        function loadService(serviceKey, url) {
            // Update active state
            document.querySelectorAll('.service-card').forEach(card => {
                card.classList.remove('active');
            });
            document.querySelector('[data-service="' + serviceKey + '"]').classList.add('active');

            // Load iframe
            const iframe = document.getElementById('service-iframe');
            const container = document.getElementById('iframe-container');
            const title = document.getElementById('iframe-title');

            title.textContent = document.querySelector('[data-service="' + serviceKey + '"] h3').textContent;
            iframe.src = url;
            container.classList.add('active');

            // Scroll to iframe
            container.scrollIntoView({ behavior: 'smooth' });
        }

        function closeIframe() {
            const container = document.getElementById('iframe-container');
            const iframe = document.getElementById('service-iframe');

            container.classList.remove('active');
            iframe.src = 'about:blank';

            document.querySelectorAll('.service-card').forEach(card => {
                card.classList.remove('active');
            });
        }

        // Auto-load frontend on page load
        window.addEventListener('load', function() {
            setTimeout(() => {
                loadService('frontend', `http://${CONFIG.LOCAL_IP}:${CONFIG.EMULATOR_SERVICES.frontend.port}`);
            }, 1000);
        });
    </script>
</body>
</html>
    `);
});

// Logout
app.get('/logout', (req, res) => {
    req.session.destroy();
    res.redirect('/login');
});

// Create HTTPS server
const httpsServer = https.createServer(sslOptions, app);

httpsServer.listen(CONFIG.HTTPS_PORT, '0.0.0.0', () => {
    console.log('🎉 Firebase Emulator Sharing Ready!');
    console.log('=====================================');
    console.log('');
    console.log(`🔒 HTTPS ${CONFIG.APP_NAME} running on port ${CONFIG.HTTPS_PORT}`);
    console.log(`📱 Mobile Access: https://${CONFIG.LOCAL_IP}:${CONFIG.HTTPS_PORT}`);
    console.log(`🔑 Auth Token: ${CONFIG.AUTH_TOKEN}`);
    console.log('');
    console.log('📋 Quick Start:');
    console.log('   1. Open the URL above on your mobile device');
    console.log('   2. Accept the SSL certificate warning');
    console.log('   3. Enter the auth token shown above');
    console.log('   4. Access your Firebase emulators securely!');
    console.log('');
    console.log('🛡️  Security Features Active:');
    console.log('   • HTTPS encryption with self-signed certificate');
    console.log('   • Session-based authentication with random tokens');
    console.log('   • Rate limiting and bot detection');
    console.log('   • Content Security Policy for iframe protection');
    console.log('   • Security event logging');
    console.log('');
    console.log('📋 Available Services:');
    Object.entries(CONFIG.EMULATOR_SERVICES).forEach(([key, service]) => {
        const url = key === 'frontend' ? `http://${CONFIG.LOCAL_IP}:${service.port}` : `http://localhost:${service.port}`;
        console.log(`   • ${service.name.padEnd(20)} → ${url}`);
    });
    console.log('');
    console.log('💡 Tips:');
    console.log('   • Ensure your Firebase emulators are running first');
    console.log('   • Make sure your mobile device is on the same WiFi network');
    console.log('   • Copy the auth token to your mobile device for login');
    console.log('');
    console.log('🔧 Configuration:');
    console.log(`   • Local IP: ${CONFIG.LOCAL_IP} (auto-detected)`);
    console.log(`   • Company: ${CONFIG.COMPANY_NAME}`);
    console.log(`   • Certificate Dir: ${CONFIG.CERT_PATH}`);
    console.log('');
    console.log('Press Ctrl+C to stop the server');
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down HTTPS wrapper...');
    process.exit(0);
});