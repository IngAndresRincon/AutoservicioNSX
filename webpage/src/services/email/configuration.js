const fs = require("fs");
const yaml = require("js-yaml");
const path = require("path");


function loadConfiguration() {
    try {
        const fileContents = fs.readFileSync(path.join(__dirname,'config.yaml'), 'utf8');
        //loggerCommodo.log(`Configuración servidor: ${JSON.stringify(fileContents)}`);
        return yaml.load(fileContents);
    } catch (e) {
      process.exit(1); // Salir si no se puede cargar la configuración
    }
  }

const config = loadConfiguration();
  
module.exports = {config}