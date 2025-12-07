#!/usr/bin/env node
"use strict";

// infer-firestore-schema-rest.js
// Enhanced REST-only schema inference for Firestore.
// Usage:
//   export FIRESTORE_API_TOKEN="$(gcloud auth print-access-token)"
//   node local/infer-firestore-schema-rest.js --project your-project-id --database your-database-id --sample 20 --out schema.json --token "$FIRESTORE_API_TOKEN" --recurse --depth 2

const fs = require('fs');

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { sample: 10, out: null, project: null, database: null, token: process.env.FIRESTORE_API_TOKEN || null, recurse: false, depth: 0, path: null };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--sample' && args[i + 1]) { opts.sample = parseInt(args[++i], 10); }
    else if (a === '--out' && args[i + 1]) { opts.out = args[++i]; }
    else if (a === '--project' && args[i + 1]) { opts.project = args[++i]; }
    else if (a === '--database' && args[i + 1]) { opts.database = args[++i]; }
    else if (a === '--token' && args[i + 1]) { opts.token = args[++i]; }
    else if (a === '--recurse') { opts.recurse = true; }
    else if (a === '--depth' && args[i + 1]) { opts.depth = parseInt(args[++i], 10); }
    else if (a === '--path' && args[i + 1]) { opts.path = args[++i]; }
    else if (a === '--help' || a === '-h') { opts.help = true; }
  }
  return opts;
}

function detectType(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (value && typeof value === 'object') return 'map';
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

async function fetchJson(url, token, method = 'GET', body = null) {
  const headers = { Authorization: `Bearer ${token}` };
  if (body) headers['Content-Type'] = 'application/json';
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch (e) { /* ignore */ }
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  return json;
}

async function listCollectionIdsForParent(projectId, databaseId, parentPath, token) {
  const parentSuffix = parentPath ? `/${parentPath}` : '';
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents:listCollectionIds`;
  const body = { pageSize: 100, parent: `projects/${projectId}/databases/${databaseId}/documents${parentSuffix}` };
  const json = await fetchJson(url, token, 'POST', body);
  return json.collectionIds || [];
}

async function listDocuments(projectId, databaseId, collectionId, pageSize, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents/${encodeURIComponent(collectionId)}?pageSize=${pageSize}`;
  const json = await fetchJson(url, token, 'GET', null);
  return json.documents || [];
}

function convertValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.doubleValue !== undefined) return Number(v.doubleValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.arrayValue && v.arrayValue.values) return v.arrayValue.values.map(convertValue);
  if (v.mapValue && v.mapValue.fields) {
    const obj = {};
    for (const [k, nv] of Object.entries(v.mapValue.fields)) obj[k] = convertValue(nv);
    return obj;
  }
  return null;
}

async function inferRest(opts) {
  if (!opts.project) throw new Error('Missing --project');
  if (!opts.database) throw new Error('Missing --database');
  if (!opts.token) throw new Error('Missing token (pass --token or set FIRESTORE_API_TOKEN)');

  const result = { projectId: opts.project, database: opts.database, collectedAt: new Date().toISOString(), collections: {} };
  const token = opts.token;

  const startCollections = [];
  if (opts.path) {
    startCollections.push(opts.path);
  } else {
    const rootCols = await listCollectionIdsForParent(opts.project, opts.database, null, token);
    for (const rc of rootCols) startCollections.push(rc);
  }

  const seen = new Set();
  async function processCollection(collectionPath, depth) {
    if (seen.has(collectionPath)) return;
    seen.add(collectionPath);
    const acc = { fields: {}, totalSampled: 0 };
    const docs = await listDocuments(opts.project, opts.database, collectionPath, opts.sample, token);
    acc.totalSampled = docs.length;
    for (const doc of docs) {
      if (!doc.fields) continue;
      const data = {};
      for (const [k, v] of Object.entries(doc.fields)) data[k] = convertValue(v);
      for (const [k, v] of Object.entries(data)) {
        mergeFieldInfo(acc.fields, k, v);
        if (v && typeof v === 'object' && !Array.isArray(v)) {
          for (const [nk, nv] of Object.entries(v)) mergeFieldInfo(acc.fields, `${k}.${nk}`, nv);
        }
      }

      if (opts.recurse && depth < opts.depth) {
        const docId = doc.name.split('/').pop();
        const parentDocPath = `${collectionPath}/${docId}`;
        const subcols = await listCollectionIdsForParent(opts.project, opts.database, parentDocPath, token);
        for (const sc of subcols) {
          const subcolPath = `${parentDocPath}/${sc}`;
          await processCollection(subcolPath, depth + 1);
        }
      }
    }

    for (const [k, v] of Object.entries(acc.fields)) acc.fields[k] = { count: v.count, types: Array.from(v.types), samples: v.samples };
    result.collections[collectionPath] = acc;
  }

  for (const sc of startCollections) {
    await processCollection(sc, 0);
  }

  return result;
}

async function main() {
  const opts = parseArgs();
  if (opts.help) { console.log('Usage: node infer-firestore-schema-rest.js --project <PROJECT> --database <DB> --token <TOKEN> [--recurse] [--depth N] [--path collectionPath]'); process.exit(0); }
  try {
    const res = await inferRest(opts);
    const out = opts.out || `firestore-schema-${opts.project}-${opts.database}-${Date.now()}.json`;
    fs.writeFileSync(out, JSON.stringify(res, null, 2));
    console.log(`Wrote schema to ${out}`);
  } catch (e) {
    console.error('Failed:', e.message || e);
    process.exit(1);
  }
}

if (require.main === module) main();
