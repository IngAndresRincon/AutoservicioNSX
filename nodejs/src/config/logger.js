const serializeMeta = (meta) => {
  if (meta === undefined) {
    return "";
  }

  if (meta instanceof Error) {
    return ` ${JSON.stringify({ message: meta.message, stack: meta.stack })}`;
  }

  if (typeof meta === "object") {
    return ` ${JSON.stringify(meta)}`;
  }

  return ` ${String(meta)}`;
};

const write = (stream, line) => {
  stream.write(`${line}\n`);
};

const format = (level, message, meta) => {
  const timestamp = new Date().toISOString();
  return `[${timestamp}] ${level.toUpperCase()}: ${message}${serializeMeta(meta)}`;
};

const logger = {
  info: (message, meta) => write(process.stdout, format("info", message, meta)),
  warn: (message, meta) => write(process.stdout, format("warn", message, meta)),
  error: (message, meta) => write(process.stderr, format("error", message, meta)),
  debug: (message, meta) => write(process.stdout, format("debug", message, meta)),
  stream: {
    write: (message) => write(process.stdout, format("http", message.trim())),
  },
};

module.exports = logger;

