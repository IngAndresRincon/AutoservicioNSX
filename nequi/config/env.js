
const dotenv = require('dotenv');
dotenv.config();


const env = {
        api_key : process.env.API_KEY,
        client_id : process.env.CLIENT_ID,
        client_secret : process.env.CLIENT_SECRET,
        url_token_auth : process.env.URL_TOKEN_AUTHENTICATION,
        url_payment : process.env.URL_PAYMENT,
        url_get_status_payment : process.env.URL_GET_STATUS_PAYMENT,
        url_dispersion : process.env.URL_DISPERSION,
        code_dispersion : process.env.CODE_DISPERSION,
        code_nit : process.env.CODE_NIT,
        db:{
            pg_user: process.env.PG_USER,
            pg_password: process.env.PG_PASSWORD,
            pg_host: process.env.PG_HOST,
            pg_port: parseInt(process.env.PG_PORT),
            pg_database: process.env.PG_DATABASE,
            ssl:false

        },
        station:{
            prefix: process.env.PREFIX
        }
    }

module.exports = {env};