import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";
import { PortalFeedbackProvider } from "./components/PortalFeedbackProvider";
import { loadConfig } from "./config";
import "./index.css";

loadConfig().then(() => {
  ReactDOM.createRoot(document.getElementById("root")).render(
    <React.StrictMode>
      <PortalFeedbackProvider>
        <App />
      </PortalFeedbackProvider>
    </React.StrictMode>
  );
});
