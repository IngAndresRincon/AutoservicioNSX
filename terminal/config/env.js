const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const env = {
  db: {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    host:  process.env.DB_HOST,
    port: process.env.DB_PORT,
    database:  process.env.DB_DATABASE,
    ssl: String(process.env.DB_SSL || 'false').toLowerCase() === 'true'
  }, 
};

module.exports = {env};
