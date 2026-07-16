
const { Pool } = require('pg');
const {env} = require('../config/env');

const pool = new Pool({
  user: env.db.pg_user,
  password: env.db.pg_password,
  host: env.db.pg_host,
  port: env.db.pg_port,
  database: env.db.pg_database,
  ssl: env.db.ssl ? { rejectUnauthorized: false } : false
});

module.exports = pool;




// const { Pool } = require('pg');

// const stringConnection ={
// 	user: 'postgres',
// 	password: 'admin',
// 	host: '100.103.140.20',
// 	port: '5432',
// 	database: 'Autoservicio_nsx2',
// };

// const client = new Pool(stringConnection);


// module.exports = {client,stringConnection};