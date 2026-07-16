module.exports = (req, res) => {
  return res.status(404).json({
    isError: true,
    message: `Ruta no encontrada: ${req.method} ${req.originalUrl}`,
  });
};

