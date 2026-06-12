const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const dgram = require('dgram');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;
const allowedOrigins = (process.env.ALLOWED_ORIGIN || 'http://localhost:3000')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const enableUdpTelemetry = process.env.ENABLE_UDP_TELEMETRY
  ? process.env.ENABLE_UDP_TELEMETRY === 'true'
  : process.env.NODE_ENV !== 'production';

app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }
    callback(new Error('Origin not allowed by CORS'));
  }
}));
const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws' });

// Broadcast telemetry to all connected clients
function broadcastTelemetry(telemetry) {
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(telemetry));
    }
  });
}

// Generate demo telemetry when no GT7 data is available
let lastTelemetry = {
  speed: 100,
  rpm: 4000,
  brake: 0,
  throttle: 50,
  gear: 4
};

function generateDemoTelemetry() {
  lastTelemetry = {
    speed: Math.max(0, Math.min(300, lastTelemetry.speed + (Math.random() - 0.45) * 5)),
    rpm: Math.max(1000, Math.min(8000, lastTelemetry.rpm + (Math.random() - 0.5) * 200)),
    brake: Math.random() > 0.7 ? Math.random() * 100 : 0,
    throttle: Math.random() * 100,
    gear: Math.floor(Math.random() * 7) + 1
  };
  return lastTelemetry;
}

// Start periodic telemetry broadcast (10Hz)
setInterval(() => {
  broadcastTelemetry(generateDemoTelemetry());
}, 100);

// GT7 telemetry UDP server (for real data)
const udpServer = dgram.createSocket('udp4');

udpServer.on('message', (msg, rinfo) => {
  // TODO: Implement Salsa20 decryption for real GT7 data
  // For now, use demo data
  const telemetry = generateDemoTelemetry();
  broadcastTelemetry(telemetry);
});

udpServer.on('error', (error) => {
  console.error('UDP telemetry server error:', error.message);
});

if (enableUdpTelemetry) {
  udpServer.bind(33739);
}

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    websocketPath: '/ws',
    udpTelemetryEnabled: enableUdpTelemetry
  });
});

app.get('/tracks', (req, res) => {
  res.json([
    {
      id: 'suzuka',
      name: 'Suzuka Circuit',
      description: 'Iconic Japanese circuit',
      corners: [
        { id: 1, name: '1st Curve', brake: 80, apex: 50, throttle: 60 },
        { id: 2, name: 'S Curves', brake: 60, apex: 40, throttle: 70 }
      ],
      tune: { suspension: [5, 5, 5, 5], gearRatios: [3.5, 2.0, 1.5, 1.0, 0.8, 0.7] }
    },
    {
      id: 'monza',
      name: 'Autodromo Nazionale Monza',
      description: 'High-speed Italian circuit',
      corners: [
        { id: 1, name: 'Rettifilo', brake: 70, apex: 45, throttle: 75 }
      ],
      tune: { suspension: [4, 4, 4, 4], gearRatios: [3.8, 2.2, 1.6, 1.1, 0.9, 0.75] }
    }
  ]);
});

app.get('/subscription', (req, res) => {
  res.json({
    monthly: { price: 9.99, currency: 'EUR', name: 'Monthly' },
    yearly: { price: 99.99, currency: 'EUR', name: 'Yearly' },
    bankAccount: 'NL93REVO5011248999'
  });
});

server.listen(PORT, () => {
  console.log(`✅ Backend server running on port ${PORT}`);
  console.log(`✅ WebSocket endpoint available on /ws`);
  if (enableUdpTelemetry) {
    console.log('✅ Listening for GT7 telemetry on UDP 33739');
  } else {
    console.log('ℹ️ UDP telemetry disabled for hosted mode');
  }
  console.log('✅ Demo telemetry broadcasting at 10Hz');
});
