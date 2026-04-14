#!/usr/bin/env node

/**
 * Fetches GLM/z.ai usage stats and updates the cache file.
 * Requires ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN to be set.
 * This is the case when running under z.ai backend.
 */

import https from 'https';
import fs from 'fs';
import path from 'path';
import os from 'os';

const cacheFile = path.join(os.homedir(), '.glm-plan-usage-cache.json');

const baseUrl = process.env.ANTHROPIC_BASE_URL || '';
const authToken = process.env.ANTHROPIC_AUTH_TOKEN || '';

// Exit silently if not on z.ai backend
if (!baseUrl || !authToken) {
  process.exit(0);
}

// Determine platform
let platform;
let quotaLimitUrl;

const parsedBaseUrl = new URL(baseUrl);
const baseDomain = `${parsedBaseUrl.protocol}//${parsedBaseUrl.host}`;

if (baseUrl.includes('api.z.ai')) {
  platform = 'ZAI';
  quotaLimitUrl = `${baseDomain}/api/monitor/usage/quota/limit`;
} else if (baseUrl.includes('open.bigmodel.cn') || baseUrl.includes('dev.bigmodel.cn')) {
  platform = 'ZHIPU';
  quotaLimitUrl = `${baseDomain}/api/monitor/usage/quota/limit`;
} else {
  process.exit(0);
}

const fetchQuota = () => {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(quotaLimitUrl);
    const options = {
      hostname: parsedUrl.hostname,
      port: 443,
      path: parsedUrl.pathname,
      method: 'GET',
      headers: {
        'Authorization': authToken,
        'Accept-Language': 'en-US,en',
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode}`));
        }

        try {
          const json = JSON.parse(data);
          resolve(json.data || json);
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
};

const updateCache = (quotaData) => {
  let mcpUsed = 0;
  let mcpTotal = 1000;
  let tokenPercent = 0;

  if (quotaData && quotaData.limits) {
    for (const item of quotaData.limits) {
      if (item.type === 'TOKENS_LIMIT') {
        tokenPercent = item.percentage || 0;
      }
      if (item.type === 'TIME_LIMIT') {
        mcpUsed = item.currentValue || 0;
        mcpTotal = item.usage || 1000;
      }
    }
  }

  const cache = {
    mcp_used: mcpUsed,
    mcp_total: mcpTotal,
    token_percent: tokenPercent,
    last_updated: new Date().toISOString()
  };

  fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 2));
  console.log(`Cache updated: MCP ${mcpUsed}/${mcpTotal} (${Math.round(mcpUsed * 100 / mcpTotal)}%), Tokens ${tokenPercent}%`);
};

const run = async () => {
  try {
    const quotaData = await fetchQuota();
    updateCache(quotaData);
  } catch (error) {
    console.error('Failed to update cache:', error.message);
    process.exit(1);
  }
};

run();
