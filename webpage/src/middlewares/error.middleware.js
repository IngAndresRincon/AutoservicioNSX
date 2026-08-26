function notFoundHandler(req, res) {
  res.status(404).json({
    message: 'Route not found',
    path: req.originalUrl
  });
}

function errorHandler(err, req, res, next) {
  void next;

  const statusCode = err.statusCode || 500;
  const payload = {
    message: err.message || 'Internal Server Error'
  };

  if (err.code) {
    payload.code = err.code;
  }

  if (err.details) {
    payload.details = err.details;
  }

  if (process.env.NODE_ENV !== 'production') {
    payload.stack = err.stack;
  }

  res.status(statusCode).json(payload);
}

module.exports = {
  notFoundHandler,
  errorHandler
};
