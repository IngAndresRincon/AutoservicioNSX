import { useCallback, useEffect, useState } from "react";
import { usePortalFeedback } from "../components/portalFeedbackContext";
import PreviewColoresApp from "../components/PreviewColoresApp";
import api from "../services/api";

const COLOR_LABELS = [
  { key: 0, name: "Principal", tone: "primary" },
  { key: 1, name: "Secundario", tone: "secondary" },
  { key: 2, name: "Tercero", tone: "tertiary" },
];

function Pill({ children, tone = "blue" }) {
  const tones = {
    blue: {
      background: "rgba(41,112,255,0.1)",
      color: "var(--accent-strong)",
      border: "1px solid rgba(41,112,255,0.12)",
    },
    green: {
      background: "rgba(36,118,86,0.12)",
      color: "var(--success-strong)",
      border: "1px solid rgba(36,118,86,0.12)",
    },
    amber: {
      background: "rgba(222,139,28,0.12)",
      color: "var(--amber)",
      border: "1px solid rgba(222,139,28,0.14)",
    },
  };

  return <span style={{ ...styles.pill, ...tones[tone] }}>{children}</span>;
}

export default function ColoresPage() {
  const portalFeedback = usePortalFeedback();
  const [colors, setColors] = useState(["", "", ""]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const cargarColores = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const response = await api.get("/Admin/ObtenerCatalogos");
      const colorList = response.data?.data?.colores ?? ["", "", ""];
      setColors([
        normalizeStoredHex(colorList[0] || ""),
        normalizeStoredHex(colorList[1] || ""),
        normalizeStoredHex(colorList[2] || ""),
      ]);
    } catch {
      setError("No fue posible cargar los colores configurados.");
    } finally {
      setLoading(false);
    }
  }, []);

  async function guardarColores() {
    const payload = colors.map((color) => color.trim());

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarColores", payload);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar los colores."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando colores",
            message: "Estamos actualizando la paleta principal del autoservicio.",
          },
          successMessage: "Los colores quedaron actualizados.",
          errorMessage: "No fue posible guardar los colores.",
        }
      );

      await cargarColores();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  useEffect(() => {
    const timer = setTimeout(() => {
      cargarColores();
    }, 0);

    return () => clearTimeout(timer);
  }, [cargarColores]);

  if (loading) {
    return (
      <div style={styles.stateWrap}>
        <div style={styles.spinner} />
        <p style={styles.stateText}>Cargando paleta de colores...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={styles.stateWrap}>
        <p style={styles.errorText}>{error}</p>
        <button style={styles.retryBtn} onClick={cargarColores}>
          Reintentar
        </button>
      </div>
    );
  }

  return (
    <div style={styles.wrap}>
      <section style={styles.header}>
        <div>
          <div style={styles.headerTop}>
            <Pill tone="blue">Colores Interfaz</Pill>
            <span style={styles.headerCaption}>Paleta principal del autoservicio</span>
          </div>
          <h3 style={styles.title}>Configurar identidad cromatica</h3>
          <p style={styles.subtitle}>
            El catalogo siempre trae tres colores. Aqui puedes editar el principal,
            secundario y tercero usando picker o HEX manual.
          </p>
        </div>

        <button style={styles.refreshBtn} onClick={cargarColores}>
          <RefreshIcon />
          <span>Actualizar</span>
        </button>
      </section>

      <section style={styles.previewBand}>
        {COLOR_LABELS.map((item, index) => (
          <div
            key={item.key}
            style={{
              ...styles.previewSlice,
              background: getColorPreview(colors[index]) || "#e9eef5",
            }}
          >
            <span style={styles.previewLabel}>{item.name}</span>
          </div>
        ))}
      </section>

      <PreviewColoresApp colors={colors} />

      <section style={styles.grid}>
        {COLOR_LABELS.map((item, index) => {
          const preview = getColorPreview(colors[index]);
          return (
            <article key={item.key} style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>{item.name}</h4>
                    <Pill tone={index === 0 ? "blue" : index === 1 ? "green" : "amber"}>
                      Orden {index + 1}
                    </Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    {index === 0 && "Es el color principal que lidera la interfaz."}
                    {index === 1 && "Complementa la interfaz como color secundario."}
                    {index === 2 && "Sirve como tercer acento dentro del portal."}
                  </p>
                </div>
                <div
                  style={{
                    ...styles.swatch,
                    background: preview || "#e9eef5",
                  }}
                />
              </div>

              <div style={styles.field}>
                <span style={styles.fieldLabel}>Color</span>
                <div style={styles.colorField}>
                  <input
                    type="color"
                    style={styles.colorInput}
                    value={normalizeHexForPicker(colors[index])}
                    onChange={(event) =>
                      setColors((current) => {
                        const next = [...current];
                        next[index] = pickerToStoredHex(event.target.value, current[index]);
                        return next;
                      })
                    }
                  />
                  <input
                    style={styles.input}
                    value={colors[index]}
                    placeholder="#FFF52727"
                    onChange={(event) =>
                      setColors((current) => {
                        const next = [...current];
                        next[index] = event.target.value;
                        return next;
                      })
                    }
                  />
                </div>
              </div>
            </article>
          );
        })}
      </section>

      <div style={styles.actions}>
        <button type="button" style={styles.primaryBtn} onClick={guardarColores}>
          Guardar colores
        </button>
      </div>
    </div>
  );
}

function RefreshIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" fill="none">
      <path d="M13.5 8A5.5 5.5 0 1 1 8 2.5c1.8 0 3.4.87 4.4 2.2" stroke="currentColor" strokeWidth="1.35" strokeLinecap="round" />
      <path d="M12 2v3h-3" stroke="currentColor" strokeWidth="1.35" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function getColorPreview(value) {
  const normalized = normalizeStoredHex(value);
  if (!normalized) return "";
  if (/^#[0-9A-F]{6}$/.test(normalized)) return normalized;
  if (/^#[0-9A-F]{8}$/.test(normalized)) return `#${normalized.slice(3)}`;
  return "";
}

function normalizeHexForPicker(value) {
  return getColorPreview(value) || "#d9dee7";
}

function pickerToStoredHex(pickerHex) {
  return `#FF${pickerHex.slice(1).toUpperCase()}`;
}

function normalizeStoredHex(value) {
  const raw = String(value || "").trim().toUpperCase();
  if (!raw) return "";
  if (/^#[0-9A-F]{8}$/.test(raw)) return raw;
  if (/^#[0-9A-F]{6}$/.test(raw)) return raw;
  if (/^[0-9A-F]{8}$/.test(raw)) return `#${raw}`;
  if (/^[0-9A-F]{6}$/.test(raw)) return `#${raw}`;
  return raw.startsWith("#") ? raw : `#${raw}`;
}

const styles = {
  wrap: {
    display: "flex",
    flexDirection: "column",
    gap: 18,
  },
  stateWrap: {
    minHeight: 320,
    display: "grid",
    placeItems: "center",
    alignContent: "center",
    gap: 14,
  },
  spinner: {
    width: 30,
    height: 30,
    border: "3px solid rgba(18,31,53,0.12)",
    borderTopColor: "var(--accent-strong)",
    borderRadius: "50%",
    animation: "spin 0.8s linear infinite",
  },
  stateText: {
    fontSize: 14,
    color: "var(--text-secondary)",
  },
  errorText: {
    color: "var(--danger)",
    fontSize: 14,
  },
  retryBtn: {
    padding: "12px 18px",
    fontSize: 13,
    fontWeight: 700,
    color: "#fff",
    border: "none",
    borderRadius: 14,
    cursor: "pointer",
    background:
      "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    gap: 18,
    alignItems: "center",
    padding: "26px 28px",
    borderRadius: 26,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.88) 0%, rgba(246,249,252,0.96) 100%)",
    border: "1px solid rgba(18,31,53,0.08)",
    boxShadow: "0 18px 30px rgba(26, 44, 73, 0.06)",
  },
  headerTop: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    flexWrap: "wrap",
    marginBottom: 12,
  },
  headerCaption: {
    fontSize: 11,
    fontWeight: 700,
    letterSpacing: "0.1em",
    textTransform: "uppercase",
    color: "var(--text-muted)",
  },
  title: {
    fontSize: 30,
    lineHeight: 1.05,
    color: "var(--text-primary)",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
    maxWidth: 720,
  },
  refreshBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 10,
    padding: "12px 16px",
    borderRadius: 16,
    border: "1px solid rgba(41,112,255,0.12)",
    background: "rgba(41,112,255,0.08)",
    color: "var(--accent-strong)",
    fontWeight: 700,
    cursor: "pointer",
    flexShrink: 0,
  },
  previewBand: {
    overflow: "hidden",
    borderRadius: 24,
    border: "1px solid rgba(18,31,53,0.08)",
    boxShadow: "0 16px 26px rgba(26, 44, 73, 0.06)",
    display: "grid",
    gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
  },
  previewSlice: {
    minHeight: 108,
    padding: 18,
    display: "flex",
    alignItems: "flex-end",
  },
  previewLabel: {
    display: "inline-flex",
    padding: "8px 10px",
    borderRadius: 999,
    background: "rgba(255,255,255,0.22)",
    backdropFilter: "blur(8px)",
    color: "#fff",
    fontSize: 12,
    fontWeight: 700,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
  },
  grid: {
    display: "grid",
    gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
    gap: 14,
  },
  card: {
    padding: 20,
    borderRadius: 24,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.95) 0%, rgba(247,250,252,0.98) 100%)",
    boxShadow: "0 16px 26px rgba(26, 44, 73, 0.06)",
    display: "grid",
    gap: 16,
  },
  cardTop: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    alignItems: "center",
  },
  cardTitleWrap: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    flexWrap: "wrap",
    marginBottom: 6,
  },
  cardTitle: {
    fontSize: 18,
    color: "var(--text-primary)",
  },
  cardMeta: {
    fontSize: 13,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
  },
  swatch: {
    width: 54,
    height: 54,
    borderRadius: 16,
    border: "1px solid rgba(18,31,53,0.08)",
    flexShrink: 0,
  },
  field: {
    display: "grid",
    gap: 7,
  },
  fieldLabel: {
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    color: "var(--text-muted)",
  },
  colorField: {
    display: "grid",
    gridTemplateColumns: "56px minmax(0, 1fr)",
    gap: 10,
    alignItems: "center",
  },
  colorInput: {
    width: 56,
    height: 44,
    borderRadius: 12,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    padding: 4,
    cursor: "pointer",
  },
  input: {
    width: "100%",
    padding: "14px 15px",
    borderRadius: 14,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    color: "var(--text-primary)",
    fontSize: 14,
    outline: "none",
  },
  actions: {
    display: "flex",
    justifyContent: "flex-end",
  },
  primaryBtn: {
    padding: "14px 18px",
    border: "none",
    borderRadius: 14,
    background:
      "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  pill: {
    display: "inline-flex",
    alignItems: "center",
    padding: "7px 10px",
    borderRadius: 999,
    fontSize: 11,
    fontWeight: 700,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
  },
};
