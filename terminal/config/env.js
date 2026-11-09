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
  endpoints:{
    url_payment: process.env.TERMINAL_URL_PAYMENT,
    url_status_payment: process.env.TERMINAL_URL_STATUS_PAYMENT,
    url_pledge: process.env.TERMINAL_URL_PLEDGE
  }
};

module.exports = {env};
