class Logger {
  constructor() {
    this.originalConsole = {
      log: console.log.bind(console),
      info: console.info.bind(console),
      warn: console.warn.bind(console),
      error: console.error.bind(console),
    };

    this.hookProcessEvents();
  }

  serialize(value) {
    if (value instanceof Error) {
      return value.stack || `${value.name}: ${value.message}`;
    }

    if (typeof value === "string") {
      return value;
    }

    try {
      return JSON.stringify(value);
    } catch (error) {
      return String(value);
    }
  }

  format(level, message) {
    const timestamp = new Date().toISOString();
    return `[${timestamp}] [${level.toUpperCase()}] ${this.serialize(message)}`;
  }

  log(level, message) {
    const formatted = this.format(level, message);

    if (level === "error") {
      this.originalConsole.error(formatted);
      return;
    }

    if (level === "warn") {
      this.originalConsole.warn(formatted);
      return;
    }

    if (level === "info") {
      this.originalConsole.info(formatted);
      return;
    }

    this.originalConsole.log(formatted);
  }

  info(message) {
    this.log("info", message);
  }

  error(message) {
    this.log("error", message);
  }

  warn(message) {
    this.log("warn", message);
  }

  debug(message) {
    this.log("debug", message);
  }

  hookProcessEvents() {
    process.on("uncaughtException", (error) => {
      this.error(error);
      process.exitCode = 1;
    });

    process.on("unhandledRejection", (reason) => {
      this.error(
        reason instanceof Error
          ? reason
          : new Error(`Unhandled rejection: ${this.serialize(reason)}`),
      );
      process.exitCode = 1;
    });

    process.on("warning", (warning) => {
      this.warn(warning);
    });
  }
}

module.exports = new Logger();
