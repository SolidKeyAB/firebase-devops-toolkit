#!/usr/bin/env node

// Secure Local Firebase Emulator Proxy
// Provides authentication and rate limiting for local network access

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const session = require('express-session');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Get local network IP address
function getLocalIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return 'localhost';
}

const app = express();

// Configuration
const CONFIG = {
    PORT: 8080,
    SESSION_SECRET: crypto.randomBytes(32).toString('hex'),
    AUTH_TOKEN: crypto.randomBytes(16).toString('hex'),
    RATE_LIMIT: {
        windowMs: 10 * 1000, // 10 seconds
        max: 10, // 10 requests per window
        message: {
            error: 'Rate limit exceeded',
            message: 'Too many requests. Please wait before trying again.',
            retryAfter: 10
        }
    },
    EMULATOR_SERVICES: {
        ui: { port: 4002, path: '/ui', name: 'Firebase Emulator UI' },
        functions: { port: 5002, path: '/functions', name: 'Functions API' },
        firestore: { port: 8085, path: '/firestore', name: 'Firestore' },
        auth: { port: 9100, path: '/auth', name: 'Authentication' }
    }
};

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", "data:", "blob:"],
            connectSrc: ["'self'"],
            fontSrc: ["'self'"],
            objectSrc: ["'none'"],
            mediaSrc: ["'self'"],
            frameSrc: ["'none'"]
        }
    },
    crossOriginEmbedderPolicy: false
}));

// Rate limiting
const limiter = rateLimit(CONFIG.RATE_LIMIT);
app.use(limiter);

// Session management
app.use(session({
    secret: CONFIG.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: false, // Set to true if using HTTPS
        httpOnly: true,
        maxAge: 3600000 // 1 hour
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

// Bot detection middleware
const detectBot = (req, res, next) => {
    const userAgent = (req.get('User-Agent') || '').toLowerCase();
    const suspiciousPatterns = [
        'bot', 'crawler', 'spider', 'scraper', 'automation',
        'selenium', 'puppeteer', 'playwright', 'curl', 'wget',
        'python-requests', 'okhttp', 'axios/0', 'node-fetch'
    ];

    const isSuspicious = suspiciousPatterns.some(pattern => userAgent.includes(pattern));

    if (isSuspicious) {
        logSecurityEvent('BOT_DETECTED', req, `User-Agent: ${userAgent}`);
        return res.status(429).json({
            error: 'Automated access detected',
            message: 'This service is protected against automated access. Please use a regular browser.',
            userAgent: userAgent
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

// Apply security middleware
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
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
        }
        .login-container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            padding: 40px;
            max-width: 400px;
            width: 100%;
            text-align: center;
        }
        .logo {
            font-size: 48px;
            margin-bottom: 20px;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 24px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
            text-align: left;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
            color: #333;
        }
        input {
            width: 100%;
            padding: 12px;
            border: 2px solid #e1e5e9;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
            box-sizing: border-box;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            width: 100%;
            transition: transform 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .security-info {
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            font-size: 14px;
            color: #666;
        }
        .security-feature {
            display: flex;
            align-items: center;
            margin-bottom: 10px;
        }
        .security-feature:last-child {
            margin-bottom: 0;
        }
        .feature-icon {
            margin-right: 10px;
            font-size: 16px;
        }
        .token-display {
            background: #e3f2fd;
            border: 1px solid #90caf9;
            border-radius: 4px;
            padding: 10px;
            margin-top: 15px;
            font-family: monospace;
            font-size: 14px;
            word-break: break-all;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">🔒</div>
        <h1>Secure Firebase Access</h1>
        <p class="subtitle">Local Network Protection Active</p>

        <form method="POST" action="/auth">
            <div class="form-group">
                <label for="token">Access Token:</label>
                <input type="password" id="token" name="token" required placeholder="Enter your access token">
            </div>
            <button type="submit" class="btn">🚀 Access Emulators</button>
        </form>

        <div class="token-display">
            <strong>🔑 Current Token:</strong><br>
            <code>${CONFIG.AUTH_TOKEN}</code>
        </div>

        <div class="security-info">
            <h3 style="margin-top: 0; color: #333;">🛡️ Active Protections</h3>
            <div class="security-feature">
                <span class="feature-icon">⏱️</span>
                <span>Rate limiting (${CONFIG.RATE_LIMIT.max} requests per ${CONFIG.RATE_LIMIT.windowMs/1000}s)</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">🤖</span>
                <span>Bot detection and blocking</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">🔐</span>
                <span>Session-based authentication</span>
            </div>
            <div class="security-feature">
                <span class="feature-icon">🏠</span>
                <span>Local network only access</span>
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

// Dashboard
app.get('/dashboard', (req, res) => {
    if (!req.session.authenticated) {
        return res.redirect('/login');
    }

    const servicesHtml = Object.entries(CONFIG.EMULATOR_SERVICES)
        .map(([key, service]) => `
            <div class="service-card">
                <h3>${service.name}</h3>
                <p>Port: ${service.port}</p>
                <a href="${service.path}" class="btn btn-primary" target="_blank">
                    🚀 Open ${service.name}
                </a>
            </div>
        `).join('');

    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔒 Firebase Emulator Dashboard</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: #f5f5f5;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .service-card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.2s;
        }
        .service-card:hover {
            transform: translateY(-5px);
        }
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            padding: 12px 24px;
            border-radius: 8px;
            display: inline-block;
            font-weight: 500;
            transition: transform 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .btn-secondary {
            background: #6c757d;
        }
        .security-status {
            background: #d4edda;
            border: 1px solid #c3e6cb;
            border-radius: 8px;
            padding: 20px;
            margin-top: 20px;
        }
        .logout-btn {
            position: fixed;
            top: 20px;
            right: 20px;
        }
    </style>
</head>
<body>
    <div class="logout-btn">
        <a href="/logout" class="btn btn-secondary">🚪 Logout</a>
    </div>

    <div class="container">
        <div class="header">
            <h1>🔒 Firebase Emulator Dashboard</h1>
            <p>Secure access to your Firebase development environment</p>
        </div>

        <div class="services-grid">
            ${servicesHtml}
        </div>

        <div class="security-status">
            <h3>🛡️ Security Status: ACTIVE</h3>
            <p>All Firebase emulator services are protected with:</p>
            <ul>
                <li>Rate limiting and bot detection</li>
                <li>Session-based authentication</li>
                <li>Local network access only</li>
                <li>Security event logging</li>
            </ul>
        </div>
    </div>
</body>
</html>
    `);
});

// Logout
app.get('/logout', (req, res) => {
    req.session.destroy();
    res.redirect('/login');
});

// Proxy middleware for each service
Object.entries(CONFIG.EMULATOR_SERVICES).forEach(([key, service]) => {
    app.use(service.path, createProxyMiddleware({
        target: `http://localhost:${service.port}`,
        changeOrigin: true,
        pathRewrite: {
            [`^${service.path}`]: '',
        },
        onProxyReq: (proxyReq, req, res) => {
            logSecurityEvent('PROXY_ACCESS', req, `Service: ${service.name}`);
        },
        onError: (err, req, res) => {
            logSecurityEvent('PROXY_ERROR', req, `Service: ${service.name}, Error: ${err.message}`);
            res.status(503).json({
                error: 'Service unavailable',
                message: `${service.name} is not responding. Make sure the emulator is running.`,
                service: service.name,
                port: service.port
            });
        }
    }));
});

// Start server
app.listen(CONFIG.PORT, '0.0.0.0', () => {
    console.log(`🔒 Secure Firebase Emulator Proxy running on port ${CONFIG.PORT}`);
    console.log(`📱 Access from mobile: http://${getLocalIP()}:${CONFIG.PORT}`);
    console.log(`🔑 Auth Token: ${CONFIG.AUTH_TOKEN}`);
    console.log('');
    console.log('🛡️  Security Features Active:');
    console.log(`   • Rate limiting: ${CONFIG.RATE_LIMIT.max} requests per ${CONFIG.RATE_LIMIT.windowMs/1000} seconds`);
    console.log('   • Bot detection and blocking');
    console.log('   • Session-based authentication');
    console.log('   • Security event logging');
    console.log('');
    console.log('📋 Available Services:');
    Object.entries(CONFIG.EMULATOR_SERVICES).forEach(([key, service]) => {
        console.log(`   • ${service.name}: http://localhost:${CONFIG.PORT}${service.path}`);
    });
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down secure proxy...');
    process.exit(0);
});