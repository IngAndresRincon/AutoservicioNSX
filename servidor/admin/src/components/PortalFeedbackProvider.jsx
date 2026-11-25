import { useCallback, useMemo, useRef, useState } from "react";
import { PortalFeedbackContext } from "./portalFeedbackContext";

export function PortalFeedbackProvider({ children }) {
  const [loadingState, setLoadingState] = useState(null);
  const [toasts, setToasts] = useState([]);
  const toastTimersRef = useRef(new Map());
  const toastIdRef = useRef(0);

  const removeToast = useCallback((id) => {
    const timer = toastTimersRef.current.get(id);
    if (timer) {
      clearTimeout(timer);
      toastTimersRef.current.delete(id);
    }

    setToasts((current) => current.filter((toast) => toast.id !== id));
  }, []);

  const pushToast = useCallback(
    (toast) => {
      const id = ++toastIdRef.current;
      setToasts((current) => [...current, { ...toast, id }]);

      const timer = setTimeout(() => {
        removeToast(id);
      }, 3200);

      toastTimersRef.current.set(id, timer);
    },
    [removeToast]
  );

  const api = useMemo(
    () => ({
      showLoading(payload) {
        setLoadingState(payload);
      },
      hideLoading() {
        setLoadingState(null);
      },
      async runWithFeedback(task, options = {}) {
        const {
          minimumMs = 700,
          loading = {
            title: "Guardando cambios",
            message: "Espera un momento mientras actualizamos la informacion.",
          },
          successMessage,
          errorMessage,
        } = options;

        setLoadingState(loading);

        try {
          const [result] = await Promise.all([task(), delay(minimumMs)]);
          setLoadingState(null);

          if (successMessage) {
            pushToast({
              type: "success",
              title: "Cambios guardados",
              message: successMessage,
            });
          }

          return result;
        } catch (error) {
          await delay(minimumMs);
          setLoadingState(null);

          pushToast({
            type: "error",
            title: "No se pudo guardar",
            message: error?.message || errorMessage || "Ocurrio un problema inesperado.",
          });

          throw error;
        }
      },
      toastSuccess(message, title = "Cambios guardados") {
        pushToast({ type: "success", title, message });
      },
      toastError(message, title = "Error") {
        pushToast({ type: "error", title, message });
      },
    }),
    [pushToast]
  );

  return (
    <PortalFeedbackContext.Provider value={api}>
      {children}

      {loadingState && (
        <div style={styles.overlay}>
          <div style={styles.dialog}>
            <div style={styles.spinner} />
            <p style={styles.dialogTitle}>{loadingState.title}</p>
            <p style={styles.dialogText}>{loadingState.message}</p>
          </div>
        </div>
      )}

      <div style={styles.toastStack}>
        {toasts.map((toast) => (
          <div
            key={toast.id}
            style={{
              ...styles.toast,
              borderColor:
                toast.type === "success"
                  ? "rgba(36,118,86,0.16)"
                  : "rgba(217,64,64,0.16)",
            }}
          >
            <div
              style={{
                ...styles.toastAccent,
                background:
                  toast.type === "success"
                    ? "var(--success-strong)"
                    : "var(--danger)",
              }}
            />
            <div style={styles.toastBody}>
              <p style={styles.toastTitle}>{toast.title}</p>
              <p style={styles.toastText}>{toast.message}</p>
            </div>
            <button
              type="button"
              style={styles.toastClose}
              onClick={() => removeToast(toast.id)}
            >
              Cerrar
            </button>
          </div>
        ))}
      </div>
    </PortalFeedbackContext.Provider>
  );
}

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

const styles = {
  overlay: {
    position: "fixed",
    inset: 0,
    background: "rgba(8, 18, 33, 0.32)",
    backdropFilter: "blur(6px)",
    display: "grid",
    placeItems: "center",
    zIndex: 100,
    padding: 24,
  },
  dialog: {
    width: "min(420px, 100%)",
    padding: "28px 24px",
    borderRadius: 24,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.96) 0%, rgba(247,250,252,0.99) 100%)",
    border: "1px solid rgba(18,31,53,0.08)",
    boxShadow: "0 24px 44px rgba(18, 31, 53, 0.18)",
    display: "grid",
    justifyItems: "center",
    textAlign: "center",
    gap: 12,
  },
  spinner: {
    width: 30,
    height: 30,
    border: "3px solid rgba(18,31,53,0.12)",
    borderTopColor: "var(--accent-strong)",
    borderRadius: "50%",
    animation: "spin 0.8s linear infinite",
  },
  dialogTitle: {
    fontSize: 22,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  dialogText: {
    fontSize: 14,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
    maxWidth: 280,
  },
  toastStack: {
    position: "fixed",
    right: 22,
    bottom: 22,
    display: "grid",
    gap: 10,
    zIndex: 110,
    width: "min(420px, calc(100vw - 32px))",
  },
  toast: {
    position: "relative",
    overflow: "hidden",
    display: "grid",
    gridTemplateColumns: "5px minmax(0, 1fr) auto",
    alignItems: "start",
    gap: 14,
    padding: 16,
    borderRadius: 18,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.97) 0%, rgba(247,250,252,0.99) 100%)",
    border: "1px solid rgba(18,31,53,0.08)",
    boxShadow: "0 18px 32px rgba(18, 31, 53, 0.12)",
  },
  toastAccent: {
    alignSelf: "stretch",
    borderRadius: 999,
  },
  toastBody: {
    minWidth: 0,
  },
  toastTitle: {
    fontSize: 14,
    fontWeight: 700,
    color: "var(--text-primary)",
    marginBottom: 4,
  },
  toastText: {
    fontSize: 13,
    color: "var(--text-secondary)",
    lineHeight: 1.5,
  },
  toastClose: {
    border: "none",
    background: "transparent",
    color: "var(--text-muted)",
    fontSize: 12,
    fontWeight: 700,
    cursor: "pointer",
    padding: 0,
  },
};
