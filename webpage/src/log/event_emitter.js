const EventEmitter = require('events');

class LoggerApi extends EventEmitter {
    log(mensaje) {
        console.log(mensaje);
        this.emit('log', {logger:'Api', mensaje, fecha: new Date() });
    }

    error(mensaje){
        console.error(mensaje);
        this.emit('error', {logger:'Api', mensaje, fecha: new Date() });
    }
}

class LoggerCommodo extends EventEmitter {
    log(mensaje) {
        console.log(mensaje);
        this.emit('log', {logger:'Commodo', mensaje, fecha: new Date() });
    }

    error(mensaje){
        console.error(mensaje);
        this.emit('error', {logger:'Commodo', mensaje, fecha: new Date() });
    }
}

class LoggerPg extends EventEmitter {
    log(mensaje) {
        console.log(mensaje);
        this.emit('log', {logger:'Postgres', mensaje, fecha: new Date() });
    }

    error(mensaje){
        console.error(mensaje);
        this.emit('error', {logger:'Postgres', mensaje, fecha: new Date() });
    }
}



class LoggerDispenser extends EventEmitter {
    log(mensaje) {
        console.log(mensaje);
        this.emit('log', {logger:'Dispenser', mensaje, fecha: new Date() });
    }

    error(mensaje){
        console.error(mensaje);
        this.emit('error', {logger:'Dispenser', mensaje, fecha: new Date() });
    }
}


const loggerCommodo = new LoggerCommodo();
loggerCommodo.on('log', (data) => {
    console.log(`Mensaje registrado ${data.logger}: "${data.mensaje}" en ${data.fecha}`);
});


loggerCommodo.on('error', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});

const loggerApi = new LoggerApi();
loggerApi.on('log', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});


loggerApi.on('error', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});


const loggerPg = new LoggerPg();
loggerPg.on('log', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});


loggerPg.on('error', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});




const loggerdispenser = new LoggerDispenser();
loggerdispenser.on('log', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});


loggerdispenser.on('error', (data) => {
    console.log(`Mensaje registrado: ${data.logger}"${data.mensaje}" en ${data.fecha}`);
});


module.exports = {loggerCommodo,loggerApi,loggerPg,loggerdispenser};