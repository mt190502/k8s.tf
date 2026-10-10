// Mints a GitHub App installation access token for a single Renovate run.
// Uses only Node.js built-ins: crypto (RS256 JWT signing) and fetch.
//
// Required environment:
//   APP_ID               GitHub App ID (the JWT "iss" claim)
//   APP_INSTALLATION_ID  Installation ID of the App on the target account
//   PRIVATE_KEY_PATH     Path to the App private key (PEM)
// Optional environment:
//   TOKEN_PATH           Where to write the token (default: /shared/token)
//   GITHUB_API_URL       GitHub API base URL (default: https://api.github.com)

const fs = require('node:fs');
const crypto = require('node:crypto');

const APP_ID = process.env.APP_ID;
const APP_INSTALLATION_ID = process.env.APP_INSTALLATION_ID;
const PRIVATE_KEY_PATH = process.env.PRIVATE_KEY_PATH;
const TOKEN_PATH = process.env.TOKEN_PATH || '/shared/token';
const GITHUB_API_URL = process.env.GITHUB_API_URL || 'https://api.github.com';

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function createJwt() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64url(JSON.stringify({ iat: now - 60, exp: now + 540, iss: Number(APP_ID) }));
  const signingInput = header + '.' + payload;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signingInput);
  signer.end();
  const signature = signer.sign(fs.readFileSync(PRIVATE_KEY_PATH, 'utf8')).toString('base64url');
  return signingInput + '.' + signature;
}

async function main() {
  const missing = ['APP_ID', 'APP_INSTALLATION_ID', 'PRIVATE_KEY_PATH'].filter((name) => !process.env[name]);
  if (missing.length > 0) {
    throw new Error('missing required environment: ' + missing.join(', '));
  }

  const response = await fetch(
    GITHUB_API_URL + '/app/installations/' + APP_INSTALLATION_ID + '/access_tokens',
    {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + createJwt(),
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    }
  );

  const body = await response.text();
  if (!response.ok) {
    throw new Error('GitHub API responded ' + response.status + ': ' + body);
  }

  const token = JSON.parse(body).token;
  if (!token) {
    throw new Error('GitHub API response contained no token: ' + body);
  }

  fs.writeFileSync(TOKEN_PATH, token, { mode: 0o600 });
  console.log('Wrote GitHub App installation token to ' + TOKEN_PATH);
}

main().catch((error) => {
  console.error('Failed to mint a GitHub App installation token: ' + error.message);
  process.exit(1);
});
