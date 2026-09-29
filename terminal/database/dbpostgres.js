const { Pool } = require('pg');
const {env} = require('../config/env');

const pool = new Pool({
  user: env.db.user,
  password: env.db.password,
  host: env.db.host,
  port: env.db.port,
  database: env.db.database,
  ssl: env.db.ssl ? { rejectUnauthorized: false } : false
});

module.exports = pool;