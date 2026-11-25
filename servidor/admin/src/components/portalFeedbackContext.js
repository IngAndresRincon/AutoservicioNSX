import { createContext, useContext } from "react";

export const PortalFeedbackContext = createContext(null);

export function usePortalFeedback() {
  const context = useContext(PortalFeedbackContext);

  if (!context) {
    throw new Error("usePortalFeedback debe usarse dentro de PortalFeedbackProvider.");
  }

  return context;
}
