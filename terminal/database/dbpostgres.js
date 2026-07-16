

const { Pool } = require('pg');

const stringConnection ={
	user: 'postgres',
	password: 'admin',
	host: '100.103.140.20',
	port: '5432',
	database: 'Autoservicio_nsx2',
};

const client = new Pool(stringConnection);


module.exports = {client,stringConnection};