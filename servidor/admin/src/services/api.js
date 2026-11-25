// src/services/api.js
import axios from "axios";
import { getConfig } from "../config";

const api = axios.create();

api.interceptors.request.use((configAxios) => {
  const config = getConfig();
  configAxios.baseURL = config.apiUrl;
  return configAxios;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const data = error.response?.data;
    const reason =
      (Array.isArray(data?.errors) && data.errors.filter(Boolean).join(" ")) ||
      data?.message ||
      null;

    if (reason) {
      error.message = reason;
    } else if (!error.response) {
      error.message = "No fue posible conectar con el servidor.";
    }

    return Promise.reject(error);
  }
);

export default api;