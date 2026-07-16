const { Server } = require("socket.io");
const socketService = require("../services/socket/service");
const { createPostgresNotifier, POSTGRES_CHANNELS } = require("./postgres-notifier");
const env = require("../config/env");
const logger = require("../config/logger");

const activeConnections = new Map();

exports.initSocketServer = (server) => {
  const io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
  });

  const postgresNotifier = createPostgresNotifier(io);

  io.use(async (socket, next) => {
    try {
      const serial =
        socket.handshake.auth?.serial ||
        socket.handshake.query?.serial ||
        socket.handshake.headers?.serial;

      const apiKey = socket.handshake.headers["x-api-key"];

      if (!serial) {
        return next(new Error("serial requerido"));
      }

      if (!apiKey || apiKey.trim() !== env.ioApiKey) {
        return next(new Error("api key requerida"));
      }

      const isValidSerial = await socketService.validateSocketSerial(serial);
      if (!isValidSerial) {
        return next(new Error("serial no autorizado"));
      }

      socket.data.serial = serial.trim();
      return next();
    } catch (error) {
      return next(new Error(error.message || "error validando serial"));
    }
  });

  io.on("connection", (socket) => {
    const { serial } = socket.data;
    const previousSocketId = activeConnections.get(serial);

    if (previousSocketId && previousSocketId !== socket.id) {
      const previousSocket = io.sockets.sockets.get(previousSocketId);

      if (previousSocket) {
        previousSocket.emit("session_replaced", {
          message: "La sesion fue reemplazada por una nueva conexion",
          serial,
        });
        previousSocket.disconnect(true);
      }
    }

    activeConnections.set(serial, socket.id);

    socket.emit("socket_ready", {
      socketId: socket.id,
      serial,
      listeningChannels: POSTGRES_CHANNELS,
    });

    socket.on("disconnect", () => {
      const currentSocketId = activeConnections.get(serial);

      if (currentSocketId === socket.id) {
        activeConnections.delete(serial);
      }
    });
  });

  postgresNotifier.start().catch((error) => {
    logger.error("No fue posible iniciar el listener de PostgreSQL", error.message);
  });

  const shutdown = async () => {
    await postgresNotifier.stop();
  };

  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);

  return io;
};
