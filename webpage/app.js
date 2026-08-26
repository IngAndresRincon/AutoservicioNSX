const createApp = require('./src/config/app');
const {env} = require('./src/config/env');
const http = require('http');


const app = createApp();
const httpServer = http.createServer(app);


httpServer.listen(env.port, () => {
  console.log(`Server running on http://localhost:${env.port}`);
});

  