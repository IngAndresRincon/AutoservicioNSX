import { useCallback, useEffect, useState } from "react";
import { usePortalFeedback } from "../components/portalFeedbackContext";
import api from "../services/api";

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

export default function TurnosPage() {
  const portalFeedback = usePortalFeedback();
  const [turnos, setTurnos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const cargarTurnos = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const response = await api.get("/Admin/ObtenerCatalogos");
      const turnosData = response.data?.data?.turnos ?? [];
      setTurnos(
        turnosData.map((turno) => ({
          horaInicio: turno.horaInicio || "",
          horaFin: turno.horaFin || "",
        }))
      );
    } catch {
      setError("No fue posible cargar la configuracion de turnos.");
    } finally {
      setLoading(false);
    }
  }, []);

  async function guardarTurnos() {
    const payload = turnos
      .map((turno) => ({
        horaInicio: (turno.horaInicio || "").trim(),
        horaFin: (turno.horaFin || "").trim(),
      }))
      .filter((turno) => turno.horaInicio && turno.horaFin);

    if (payload.length === 0) {
      portalFeedback.toastError(
        "Agrega al menos un turno completo antes de guardar."
      );
      return;
    }

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarTurnos", payload);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar los turnos."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando turnos",
            message: "Estamos actualizando la programacion horaria del autoservicio.",
          },
          successMessage: "Los turnos quedaron actualizados.",
          errorMessage: "No fue posible guardar los turnos.",
        }
      );

      await cargarTurnos();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  useEffect(() => {
    const timer = setTimeout(() => {
      cargarTurnos();
    }, 0);

    return () => clearTimeout(timer);
  }, [cargarTurnos]);

  if (loading) {
    return (
      <div style={styles.stateWrap}>
        <div style={styles.spinner} />
        <p style={styles.stateText}>Cargando turnos configurados...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={styles.stateWrap}>
        <p style={styles.errorText}>{error}</p>
        <button style={styles.retryBtn} onClick={cargarTurnos}>
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
            <Pill tone="blue">Turnos</Pill>
            <span style={styles.headerCaption}>Horario operativo 24 horas</span>
          </div>
          <h3 style={styles.title}>Configurar turnos</h3>
          <p style={styles.subtitle}>
            Agrega libremente los turnos que necesites. No hay cantidad fija ni
            horarios obligatorios.
          </p>
        </div>

        <button style={styles.refreshBtn} onClick={cargarTurnos}>
          <RefreshIcon />
          <span>Actualizar</span>
        </button>
      </section>

      <section style={styles.timeline}>
        {turnos.length === 0 && (
          <div style={styles.emptyTimeline}>
            <p style={styles.emptyTitle}>No hay turnos configurados</p>
            <p style={styles.emptyText}>
              Agrega los bloques horarios que necesite la estacion. El esquema es
              completamente configurable.
            </p>
          </div>
        )}

        {turnos.map((turno, index) => (
          <div key={`timeline-${index}`} style={styles.timelineItem}>
            <span style={styles.timelineLabel}>{`Turno ${index + 1}`}</span>
            <span style={styles.timelineHours}>
              {(turno.horaInicio || "--:--")} - {(turno.horaFin || "--:--")}
            </span>
          </div>
        ))}
      </section>

      <section style={styles.grid}>
        {turnos.map((turno, index) => (
          <article key={`turno-${index}`} style={styles.card}>
            <div style={styles.cardTop}>
              <div>
                <div style={styles.cardTitleWrap}>
                  <h4 style={styles.cardTitle}>{`Turno ${index + 1}`}</h4>
                  <Pill tone={index === 0 ? "blue" : index % 2 === 1 ? "green" : "amber"}>
                    Orden {index + 1}
                  </Pill>
                </div>
                <p style={styles.cardMeta}>
                  Ajusta la hora de inicio y fin en formato de 24 horas.
                </p>
              </div>

              <button
                type="button"
                style={styles.removeBtn}
                onClick={() =>
                  setTurnos((current) => current.filter((_, turnIndex) => turnIndex !== index))
                }
              >
                Quitar
              </button>
            </div>

            <div style={styles.formGrid}>
              <label style={styles.field}>
                <span style={styles.fieldLabel}>Hora inicio</span>
                <input
                  type="time"
                  style={styles.input}
                  value={turno.horaInicio}
                  onChange={(event) =>
                    setTurnos((current) => {
                      const next = [...current];
                      next[index] = {
                        ...next[index],
                        horaInicio: event.target.value,
                      };
                      return next;
                    })
                  }
                />
              </label>

              <label style={styles.field}>
                <span style={styles.fieldLabel}>Hora fin</span>
                <input
                  type="time"
                  style={styles.input}
                  value={turno.horaFin}
                  onChange={(event) =>
                    setTurnos((current) => {
                      const next = [...current];
                      next[index] = {
                        ...next[index],
                        horaFin: event.target.value,
                      };
                      return next;
                    })
                  }
                />
              </label>
            </div>
          </article>
        ))}
      </section>

      <div style={styles.actions}>
        <button
          type="button"
          style={styles.secondaryBtn}
          onClick={() =>
            setTurnos((current) => [
              ...current,
              { horaInicio: "", horaFin: "" },
            ])
          }
        >
          Agregar turno
        </button>
        <button type="button" style={styles.primaryBtn} onClick={guardarTurnos}>
          Guardar turnos
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
  timeline: {
    display: "grid",
    gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
    gap: 12,
  },
  timelineItem: {
    padding: "16px 18px",
    borderRadius: 20,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.94) 0%, rgba(246,249,252,0.98) 100%)",
    boxShadow: "0 14px 24px rgba(26, 44, 73, 0.05)",
    display: "grid",
    gap: 8,
  },
  timelineLabel: {
    fontSize: 12,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    color: "var(--text-muted)",
  },
  timelineHours: {
    fontSize: 24,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  emptyTimeline: {
    gridColumn: "1 / -1",
    padding: 22,
    borderRadius: 20,
    border: "1px dashed rgba(18,31,53,0.14)",
    background: "rgba(243,247,251,0.72)",
    display: "grid",
    gap: 6,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  emptyText: {
    fontSize: 13,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
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
    alignItems: "start",
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
  removeBtn: {
    border: "1px solid rgba(220,38,38,0.2)",
    background: "rgba(220,38,38,0.06)",
    color: "var(--danger)",
    fontSize: 12,
    fontWeight: 700,
    cursor: "pointer",
    padding: "6px 12px",
    borderRadius: 999,
  },
  formGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
    gap: 14,
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
    gap: 12,
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
  secondaryBtn: {
    padding: "14px 18px",
    borderRadius: 14,
    border: "1px solid rgba(41,112,255,0.14)",
    background: "#fff",
    color: "var(--accent-strong)",
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
