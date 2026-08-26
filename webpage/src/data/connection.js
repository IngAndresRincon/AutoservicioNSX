

const { Pool } = require('pg');

const stringConnection ={
	user: 'postgres',
	password: 'admin',
	host: 'localhost',
	port: '5432',
	database: 'SSTerminal',
};

const client = new Pool(stringConnection);


module.exports = {client,stringConnection};