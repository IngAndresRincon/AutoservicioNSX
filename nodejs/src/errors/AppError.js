class AppError extends Error {
  constructor(message, statusCode = 500, options = {}) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.expose = options.expose !== undefined ? options.expose : statusCode < 500;
    this.details = options.details;
  }
}

module.exports = AppError;

