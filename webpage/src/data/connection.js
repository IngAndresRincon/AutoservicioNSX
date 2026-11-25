const { Pool } = require('pg');
const { env } = require('../config/env');

const stringConnection = {
	user: env.db.user,
	password: env.db.password,
	host: env.db.host,
	port: env.db.port,
	database: env.db.database,
	ssl: env.db.ssl,
};

const client = new Pool(stringConnection);

module.exports = { client, stringConnection };
