const { Pool } = require('pg');
const config = require("../config");

const stringConnection = config.db;

const client = new Pool(stringConnection);

module.exports = { client, stringConnection };
