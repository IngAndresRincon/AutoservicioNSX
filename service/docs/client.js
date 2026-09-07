const { io } = require("socket.io-client");

const socket = io("http://200.118.226.75:5007", {
  extraHeaders: {
    "x-api-key": "3994168ec27e1de34954218921e538c0f17e96dc87326d0d4726ad9b84f00f42",
  },
  auth: {
    serial: "666666",
  },
});

socket.on("socket_ready", console.log);
socket.on("notify_event_transaction_payment", console.log);
socket.on("notify_event_authorization", console.log);
socket.on("event_sale", console.log);
socket.on("session_replaced", console.log);
socket.on("connect_error", console.error);
