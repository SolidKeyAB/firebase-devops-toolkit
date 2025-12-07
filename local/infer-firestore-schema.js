#!/usr/bin/env node
"use strict";

// infer-firestore-schema.js
// Simple helper to infer Firestore collection schemas by sampling documents.
// Usage:
//   npm install firebase-admin
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node local/infer-firestore-schema.js --project your-project-id --sample 20 --out schema.json --recurse --depth 1

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { sample: 10, out: null, project: process.env.FIREBASE_PROJECT_ID || null, recurse: false, depth: 0 };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--sample' && args[i + 1]) { opts.sample = parseInt(args[++i], 10); }
    else if (a === '--out' && args[i + 1]) { opts.out = args[++i]; }
    else if (a === '--project' && args[i + 1]) { opts.project = args[++i]; }
  else if (a === '--token' && args[i + 1]) { opts.token = args[++i]; }
    else if (a === '--recurse') { opts.recurse = true; }
    else if (a === '--depth' && args[i + 1]) { opts.depth = parseInt(args[++i], 10); }
    else if (a === '--help' || a === '-h') { opts.help = true; }
  }
  return opts;
}

function detectType(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (value && value._isAMap === true) return 'map';
  if (value && typeof value === 'object') {
    // Firestore timestamp
    if (typeof value.toDate === 'function' && typeof value.seconds === 'number') return 'timestamp';
    return 'map';
  }
  return typeof value;
}

function mergeFieldInfo(acc, fieldPath, value) {
  const type = detectType(value);
  const node = acc[fieldPath] || { count: 0, types: new Set(), samples: [] };
  node.count += 1;
  node.types.add(type);
  if (node.samples.length < 3) node.samples.push(value);
  acc[fieldPath] = node;
}

async function sampleCollection(db, collectionRef, opts, acc, prefix = '', depth = 0) {
  const snapshot = await collectionRef.limit(opts.sample).get();
  acc.totalSampled = (acc.totalSampled || 0) + snapshot.size;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    for (const [k, v] of Object.entries(data)) {
      const pathKey = prefix ? `${prefix}.${k}` : k;
      mergeFieldInfo(acc.fields, pathKey, v);
      // If object/map, record nested fields shallowly
      if (v && typeof v === 'object' && !Array.isArray(v)) {
        for (const [nk, nv] of Object.entries(v)) {
          const nestedPath = `${pathKey}.${nk}`;
          mergeFieldInfo(acc.fields, nestedPath, nv);
        }
      }
    }

    if (opts.recurse && depth < opts.depth) {
      // list subcollections on this doc
      const subcols = await doc.ref.listCollections();
      for (const sc of subcols) {
        const name = sc.id;
        acc.subcollections = acc.subcollections || {};
        acc.subcollections[name] = acc.subcollections[name] || { fields: {}, totalSampled: 0 };
        await sampleCollection(db, sc, opts, acc.subcollections[name], '', depth + 1);
      }
    }
  }
}

const { execSync } = require('child_process');
const readline = require('readline');

async function listCollectionsRest(projectId, databaseId, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents:listCollectionIds`;
  const body = { pageSize: 100, parent: `projects/${projectId}/databases/${databaseId}/documents` };
  const res = await fetch(url, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`listCollectionIds failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  return json.collectionIds || [];
}

async function listDocumentsRest(projectId, databaseId, collectionId, pageSize, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents/${encodeURIComponent(collectionId)}?pageSize=${pageSize}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`list documents failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  return json.documents || [];
}

function getGcloudAccessToken() {
  try {
    const out = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
    if (!out) throw new Error('empty token');
    return out;
  } catch (e) {
    throw new Error('Failed to get gcloud access token. Ensure gcloud is installed and you are logged in: gcloud auth login');
  }
}

function askYesNo(question) {
  return new Promise((resolve) => {
    if (!process.stdin.isTTY) return resolve(false);
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question + ' (Y/n): ', (ans) => {
      rl.close();
      const ok = ans.trim() === '' || /^[Yy]/.test(ans);
      resolve(ok);
    });
  });
}

async function ensureGcloudAccessToken(projectId) {
  try {
    return getGcloudAccessToken();
  } catch (err) {
    console.error('gcloud authentication failed:', err.message || err);
    if (!process.stdin.isTTY) {
      throw err;
    }

    const proceed = await askYesNo("Would you like to run 'gcloud auth login' now to re-authenticate?");
    if (!proceed) throw err;

    try {
      // Run interactive login
      execSync('gcloud auth login', { stdio: 'inherit' });
      if (projectId) {
        const setProj = await askYesNo(`Set gcloud project to '${projectId}' now with 'gcloud config set project ${projectId}'?`);
        if (setProj) {
          execSync(`gcloud config set project ${projectId}`, { stdio: 'inherit' });
        }
      }
      // Retry
      return getGcloudAccessToken();
    } catch (e) {
      console.error('gcloud login failed or was cancelled:', e.message || e);
      throw e;
    }
  }
}

async function infer(projectId, opts) {
  if (!projectId) throw new Error('Project ID is required (use --project or set FIREBASE_PROJECT_ID)');

  const result = { projectId, database: opts.database || '(default)', collectedAt: new Date().toISOString(), collections: {} };

  if (opts.database) {
    // Use REST API via gcloud access token
    const token = opts.token || await ensureGcloudAccessToken(projectId);
    console.error(`[debug] using token from ${opts.token ? '--token' : 'gcloud'}; token length=${token ? token.length : 0}`);
    let collectionIds;
    try {
      collectionIds = await listCollectionsRest(projectId, opts.database, token);
    } catch (e) {
      // If the REST call failed, try to surface the response body if present
      console.error('[debug] listCollectionsRest failed:', e.message || e);
      throw e;
    }
    for (const colName of collectionIds) {
      result.collections[colName] = { fields: {}, totalSampled: 0 };
      const acc = result.collections[colName];
      acc.fields = {};
      // list documents (sample)
      const docs = await listDocumentsRest(projectId, opts.database, colName, opts.sample, token);
      acc.totalSampled = docs.length;
      for (const doc of docs) {
        // doc.fields is Firestore Value format — convert to plain JS values
        const data = {}; 
        if (doc.fields) {
          for (const [k, v] of Object.entries(doc.fields)) {
            // naive conversion for common types
            if (v.stringValue !== undefined) data[k] = v.stringValue;
            else if (v.integerValue !== undefined) data[k] = Number(v.integerValue);
            else if (v.doubleValue !== undefined) data[k] = Number(v.doubleValue);
            else if (v.booleanValue !== undefined) data[k] = v.booleanValue;
            else if (v.arrayValue && v.arrayValue.values) data[k] = v.arrayValue.values.map(x => { return x.stringValue ?? x.integerValue ?? x.doubleValue ?? x.booleanValue ?? null; });
            else if (v.mapValue && v.mapValue.fields) {
              const nested = {};
              for (const [nk, nv] of Object.entries(v.mapValue.fields)) {
                nested[nk] = nv.stringValue ?? nv.integerValue ?? nv.doubleValue ?? nv.booleanValue ?? null;
              }
              data[k] = nested;
            } else if (v.timestampValue !== undefined) data[k] = v.timestampValue;
            else data[k] = null;
          }
        }

        for (const [k, v] of Object.entries(data)) {
          const pathKey = k;
          mergeFieldInfo(acc.fields, pathKey, v);
          if (v && typeof v === 'object' && !Array.isArray(v)) {
            for (const [nk, nv] of Object.entries(v)) {
              const nestedPath = `${pathKey}.${nk}`;
              mergeFieldInfo(acc.fields, nestedPath, nv);
            }
          }
        }
      }

      for (const [k, v] of Object.entries(acc.fields)) {
        acc.fields[k] = { count: v.count, types: Array.from(v.types), samples: v.samples };
      }
    }

    return result;
  }

  // Fallback: use admin SDK
  try {
    admin.initializeApp({ projectId });
  } catch (e) {
    // ignore if already initialized
  }

  const db = admin.firestore();
  const collections = await db.listCollections();

  for (const col of collections) {
    const name = col.id;
    result.collections[name] = { fields: {}, totalSampled: 0 };
    const acc = result.collections[name];
    acc.fields = {};
    await sampleCollection(db, col, opts, acc, '', 0);

    for (const [k, v] of Object.entries(acc.fields)) {
      acc.fields[k] = { count: v.count, types: Array.from(v.types), samples: v.samples };
    }
  }

  return result;
}

async function main() {
  const opts = parseArgs();
  if (opts.help) {
    console.log('Usage: node local/infer-firestore-schema.js --project <PROJECT_ID> [--sample N] [--out file.json] [--recurse] [--depth N]');
    process.exit(0);
  }

  if (!opts.project) {
    console.error('Missing project ID. Provide with --project or set FIREBASE_PROJECT_ID');
    process.exit(2);
  }

  // Attempt inference with one interactive retry for auth failures
  try {
    const res = await infer(opts.project, opts);
    const out = opts.out || `firestore-schema-${opts.project}-${Date.now()}.json`;
    fs.writeFileSync(out, JSON.stringify(res, null, 2));
    console.log(`Inferred schema written to: ${out}`);
    return;
  } catch (err) {
    const msg = (err && (err.message || err.toString())) || '';
    if (/invalid_grant|reauth|invalid_rapt/i.test(msg)) {
      console.error('Authentication error detected:', msg);
      if (process.stdin.isTTY) {
        const proceed = await askYesNo("It looks like your gcloud credentials need re-authentication. Run 'gcloud auth login' now?");
        if (proceed) {
          try {
            execSync('gcloud auth login', { stdio: 'inherit' });
            if (opts.project) {
              const setProj = await askYesNo(`Set gcloud project to '${opts.project}' now with 'gcloud config set project ${opts.project}'?`);
              if (setProj) execSync(`gcloud config set project ${opts.project}`, { stdio: 'inherit' });
            }
            // retry once
            const res = await infer(opts.project, opts);
            const out = opts.out || `firestore-schema-${opts.project}-${Date.now()}.json`;
            fs.writeFileSync(out, JSON.stringify(res, null, 2));
            console.log(`Inferred schema written to: ${out}`);
            return;
          } catch (e2) {
            console.error('Retry after gcloud auth failed:', e2.message || e2);
            process.exit(1);
          }
        }
      }
      console.error("Please run:\n  gcloud auth login\n  gcloud config set project ${opts.project}\nthen re-run this script.");
      process.exit(1);
    }

    console.error('Error inferring schema:', msg);
    process.exit(1);
  }
}

if (require.main === module) main();
