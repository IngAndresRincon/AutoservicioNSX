const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const parsePort = (value, fallback = 5000) => {
  const port = Number(value ?? fallback);
  return Number.isInteger(port) && port >= 0 && port < 65536 ? port : fallback;
};


const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parsePort(process.env.PORT),
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
