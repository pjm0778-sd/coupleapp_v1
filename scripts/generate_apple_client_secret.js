#!/usr/bin/env node

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }

    const key = token.slice(2);
    const value = argv[index + 1];

    if (!value || value.startsWith('--')) {
      args[key] = 'true';
      continue;
    }

    args[key] = value;
    index += 1;
  }

  return args;
}

function base64UrlEncode(value) {
  return Buffer.from(value)
      .toString('base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
}

function printUsage() {
  console.log(`Usage:
  node scripts/generate_apple_client_secret.js \
    --team-id YOUR_TEAM_ID \
    --key-id YOUR_KEY_ID \
    --client-id com.coupleduty.app.login \
    --key-file /absolute/path/to/AuthKey_XXXXXXXXXX.p8 \
    [--expires-in-days 180]

Outputs the Apple client secret JWT for Supabase Apple OAuth.`);
}

const args = parseArgs(process.argv.slice(2));

if (args.help === 'true') {
  printUsage();
  process.exit(0);
}

const requiredArgs = ['team-id', 'key-id', 'client-id', 'key-file'];
const missingArgs = requiredArgs.filter((name) => !args[name]);

if (missingArgs.length > 0) {
  console.error(`Missing required arguments: ${missingArgs.join(', ')}`);
  printUsage();
  process.exit(1);
}

const expiresInDays = Number.parseInt(args['expires-in-days'] ?? '180', 10);

if (Number.isNaN(expiresInDays) || expiresInDays < 1 || expiresInDays > 180) {
  console.error('--expires-in-days must be an integer between 1 and 180.');
  process.exit(1);
}

const keyFilePath = path.resolve(args['key-file']);
const privateKey = fs.readFileSync(keyFilePath, 'utf8');

const now = Math.floor(Date.now() / 1000);
const expiresAt = now + expiresInDays * 24 * 60 * 60;

const header = {
  alg: 'ES256',
  kid: args['key-id'],
};

const payload = {
  iss: args['team-id'],
  iat: now,
  exp: expiresAt,
  aud: 'https://appleid.apple.com',
  sub: args['client-id'],
};

const encodedHeader = base64UrlEncode(JSON.stringify(header));
const encodedPayload = base64UrlEncode(JSON.stringify(payload));
const signingInput = `${encodedHeader}.${encodedPayload}`;

const signature = crypto.sign('sha256', Buffer.from(signingInput), {
  key: privateKey,
  dsaEncoding: 'ieee-p1363',
});

const encodedSignature = base64UrlEncode(signature);
const jwt = `${signingInput}.${encodedSignature}`;

console.log(jwt);