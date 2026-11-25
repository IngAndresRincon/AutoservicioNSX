import { useCallback, useEffect, useMemo, useState } from "react";
import { usePortalFeedback } from "../components/portalFeedbackContext";
import api from "../services/api";

const MAX_VIDEO_BYTES = 25 * 1024 * 1024;

export default function PublicidadPage() {
  const portalFeedback = usePortalFeedback();
  const [mapeo, setMapeo] = useState(null);
  const [dispositivos, setDispositivos] = useState([]);
  const [selectedDispensador, setSelectedDispensador] = useState("");
  const [route, setRoute] = useState("standby");
  const [videoFile, setVideoFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState("");
  const [videoName, setVideoName] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadData = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const [mapeoRes, dispositivosRes] = await Promise.all([
        api.get("/Admin/ObtenerMapeoConfiguracion"),
        api.get("/Admin/ObtenerDispositivos"),
      ]);

      const mapeoData = mapeoRes.data?.data ?? null;
      const dispositivosData = dispositivosRes.data?.data ?? [];

      setMapeo(mapeoData);
      setDispositivos(dispositivosData);

      const first = dispositivosData.find(
        (item) => item.activo && item.identificador && item.ip
      );
      if (first && !selectedDispensador) {
        setSelectedDispensador(String(first.idDispensador));
      }
    } catch {
      setError("No fue posible cargar la información de publicidad.");
    } finally {
      setLoading(false);
    }
  }, [selectedDispensador]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadData();
    }, 0);

    return () => clearTimeout(timer);
  }, [loadData]);

  const dispensadores = useMemo(() => {
    return (mapeo?.dispensadores ?? [])
      .map((dispensador) => {
        const dispositivo =
          dispositivos.find(
            (item) => String(item.idDispensador) === String(dispensador.idDispensador)
          ) || null;

        return {
          ...dispensador,
          dispositivo,
        };
      })
      .filter((dispensador) => dispensador.dispositivo?.activo && dispensador.dispositivo?.identificador);
  }, [dispositivos, mapeo]);

  const selectedDispensadorData = dispensadores.find(
    (item) => String(item.idDispensador) === String(selectedDispensador)
  );

  async function subirVideo() {
    if (!selectedDispensadorData?.dispositivo?.ip) {
      portalFeedback.toastError("Selecciona un dispensador con IP configurada.");
      return;
    }

    if (!videoFile) {
      portalFeedback.toastError("Selecciona un video antes de subirlo.");
      return;
    }

    if (videoFile.size > MAX_VIDEO_BYTES) {
      portalFeedback.toastError("El video no puede superar 25 MB.");
      return;
    }

    const targetName = (videoName || videoFile.name || "").trim();
    if (!targetName) {
      portalFeedback.toastError("Debes indicar un nombre para el video.");
      return;
    }

    const formData = new FormData();
    formData.append("video", videoFile);
    formData.append("videoName", targetName);
    formData.append("route", route);

    const url = buildUploadUrl(selectedDispensadorData.dispositivo.ip);

    await portalFeedback.runWithFeedback(
      async () => {
        const response = await fetch(url, {
          method: "POST",
          body: formData,
        });

        if (!response.ok) {
          const text = await safeReadResponse(response);
          throw new Error(
            text ||
              `La API de publicidad respondió con estado ${response.status}.`
          );
        }
      },
      {
        minimumMs: 900,
        loading: {
          title: "Subiendo publicidad",
          message: `Enviamos el video a la IP ${selectedDispensadorData.dispositivo.ip} en ${route}.`,
        },
        successMessage: `El video quedó cargado en el dispensador ${selectedDispensadorData.idDispensador} para ${route}.`,
        errorMessage: "No fue posible subir el video de publicidad.",
      }
    );
  }

  if (loading) {
    return (
      <div style={styles.stateWrap}>
        <div style={styles.spinner} />
        <p style={styles.stateText}>Cargando publicidades y dispositivos...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={styles.stateWrap}>
        <p style={styles.errorText}>{error}</p>
        <button style={styles.retryBtn} onClick={loadData}>
          Reintentar
        </button>
      </div>
    );
  }

  return (
    <div style={styles.wrap}>
      <section style={styles.hero}>
        <div>
          <p style={styles.heroEyebrow}>Publicidad</p>
          <h3 style={styles.heroTitle}>Carga de videos por dispensador</h3>
          <p style={styles.heroText}>
            Sube un video de hasta 25 MB y envíalo a la IP del dispositivo
            seleccionado para actualizar la publicidad del autoservicio.
          </p>
        </div>
        <div style={styles.heroAside}>
          <StatCard
            label="Dispensadores"
            value={dispensadores.length}
            tone="blue"
          />
          <StatCard
            label="Dispositivos activos"
            value={dispositivos.filter((item) => item.activo).length}
            tone="green"
          />
        </div>
      </section>

      <section style={styles.panel}>
        <div style={styles.panelHeader}>
          <div>
            <p style={styles.panelEyebrow}>Destino</p>
            <h4 style={styles.panelTitle}>Selecciona el dispensador</h4>
          </div>
          <Pill tone={selectedDispensadorData?.dispositivo ? "green" : "amber"}>
            {selectedDispensadorData?.dispositivo ? "Con IP" : "Sin IP"}
          </Pill>
        </div>

        <div style={styles.dispensadorGrid}>
          {dispensadores.map((dispensador) => {
            const active = String(dispensador.idDispensador) === String(selectedDispensador);
            return (
              <button
                key={dispensador.idDispensador}
                type="button"
                style={{
                  ...styles.dispensadorCard,
                  ...(active ? styles.dispensadorCardActive : {}),
                }}
                onClick={() => setSelectedDispensador(String(dispensador.idDispensador))}
              >
                <div style={styles.cardTopline}>
                  <span style={styles.cardIndex}>{dispensador.idDispensador}</span>
                  <Pill tone={dispensador.dispositivo?.activo ? "green" : "amber"}>
                    {dispensador.dispositivo?.activo ? "Activo" : "Inactivo"}
                  </Pill>
                </div>
                <p style={styles.cardTitle}>Dispensador {dispensador.idDispensador}</p>
                <p style={styles.cardMeta}>
                  {dispensador.dispositivo?.ip || "Sin IP configurada"}
                </p>
                <p style={styles.cardSubmeta}>
                  {dispensador.dispositivo?.identificador || "Sin identificador"}
                </p>
              </button>
            );
          })}
        </div>
      </section>

      <section style={styles.uploadGrid}>
        <article style={styles.uploadCard}>
          <div style={styles.panelHeader}>
            <div>
              <p style={styles.panelEyebrow}>Archivo</p>
              <h4 style={styles.panelTitle}>Video a publicar</h4>
            </div>
            <Pill tone="blue">Max 25 MB</Pill>
          </div>

          <div style={styles.routePicker}>
            <div>
              <p style={styles.fieldLabel}>Destino del video</p>
              <p style={styles.routeHelp}>
                Elige si vas a actualizar la pantalla de espera o la de despacho.
              </p>
            </div>
            <div style={styles.routePills}>
              <button
                type="button"
                style={{
                  ...styles.routeButton,
                  ...(route === "standby" ? styles.routeButtonActive : {}),
                }}
                onClick={() => setRoute("standby")}
              >
                standby
              </button>
              <button
                type="button"
                style={{
                  ...styles.routeButton,
                  ...(route === "dispensing" ? styles.routeButtonActive : {}),
                }}
                onClick={() => setRoute("dispensing")}
              >
                dispensing
              </button>
            </div>
          </div>

          <div style={styles.formGrid}>
            <label style={styles.field}>
              <span style={styles.fieldLabel}>Nombre del video</span>
              <input
                style={styles.input}
                value={videoName}
                onChange={(event) => setVideoName(event.target.value)}
                placeholder="Ej. Promocion_Enero.mp4"
              />
            </label>

            <label style={styles.field}>
              <span style={styles.fieldLabel}>Seleccionar archivo</span>
              <input
                type="file"
                accept="video/*"
                style={styles.fileInput}
                onChange={(event) => {
                  const file = event.target.files?.[0] || null;
                  if (previewUrl) {
                    URL.revokeObjectURL(previewUrl);
                  }
                  setVideoFile(file);
                  setPreviewUrl(file ? URL.createObjectURL(file) : "");
                  if (file && !videoName) {
                    setVideoName(file.name);
                  }
                }}
              />
            </label>
          </div>

          {previewUrl ? (
            <div style={styles.previewBox}>
              <div style={styles.previewHeader}>
                <div>
                  <p style={styles.infoLabel}>Previsualizacion</p>
                  <p style={styles.infoValue}>
                    {videoFile?.name || "Video seleccionado"}
                  </p>
                </div>
                <Pill tone={videoFile?.size > MAX_VIDEO_BYTES ? "amber" : "green"}>
                  {videoFile?.size > MAX_VIDEO_BYTES ? "Excede 25 MB" : "Listo"}
                </Pill>
              </div>
              <video
                key={previewUrl}
                style={styles.videoPreview}
                controls
                preload="metadata"
                src={previewUrl}
              />
            </div>
          ) : null}

          <div style={styles.fileSummary}>
            <div>
              <p style={styles.infoLabel}>Archivo seleccionado</p>
              <p style={styles.infoValue}>{videoFile?.name || "Ninguno"}</p>
            </div>
            <div>
              <p style={styles.infoLabel}>Peso</p>
              <p style={styles.infoValue}>
                {videoFile ? formatFileSize(videoFile.size) : "0 MB"}
              </p>
            </div>
            <div>
              <p style={styles.infoLabel}>Destino</p>
              <p style={styles.infoValue}>
                {selectedDispensadorData?.dispositivo?.ip || "Sin IP"}
              </p>
            </div>
            <div>
              <p style={styles.infoLabel}>Route</p>
              <p style={styles.infoValue}>{route}</p>
            </div>
          </div>

          <div style={styles.actions}>
            <button type="button" style={styles.primaryBtn} onClick={subirVideo}>
              Subir video
            </button>
          </div>
        </article>

        <article style={styles.uploadCard}>
          <div style={styles.panelHeader}>
            <div>
              <p style={styles.panelEyebrow}>Guia</p>
              <h4 style={styles.panelTitle}>Como se envia</h4>
            </div>
          </div>

          <div style={styles.helperList}>
            <HelperStep
              title="1. Elige un dispensador"
              text="Selecciona el equipo al que quieres reemplazar la publicidad."
            />
            <HelperStep
              title="2. Carga el video"
              text="El archivo debe ser de video y pesar como maximo 25 MB."
            />
            <HelperStep
              title="3. Envia a la IP"
              text="Se publica contra /nsx-autoservice-api/V1/system/upload-video usando la IP del dispositivo."
            />
          </div>
        </article>
      </section>
    </div>
  );
}

function buildUploadUrl(ip) {
  const base = normalizeDeviceBaseUrl(ip);
  return `${base}/nsx-autoservice-api/V1/system/upload-video`;
}

function normalizeDeviceBaseUrl(ip) {
  const raw = String(ip || "").trim();
  if (!raw) return "";
  if (/^https?:\/\//i.test(raw)) return raw.replace(/\/$/, "");
  return `http://${raw}`.replace(/\/$/, "");
}

async function safeReadResponse(response) {
  try {
    return await response.text();
  } catch {
    return "";
  }
}

function formatFileSize(bytes) {
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(mb >= 10 ? 1 : 2)} MB`;
}

function Pill({ children, tone = "blue" }) {
  const tones = {
    blue: {
      background: "rgba(41,112,255,0.12)",
      color: "var(--accent-strong)",
      border: "1px solid rgba(41,112,255,0.16)",
    },
    green: {
      background: "rgba(36,118,86,0.12)",
      color: "var(--success-strong)",
      border: "1px solid rgba(36,118,86,0.16)",
    },
    amber: {
      background: "rgba(222,139,28,0.12)",
      color: "var(--amber)",
      border: "1px solid rgba(222,139,28,0.16)",
    },
  };

  return <span style={{ ...styles.pill, ...tones[tone] }}>{children}</span>;
}

function StatCard({ label, value, tone }) {
  const colors = {
    blue: "rgba(41,112,255,1)",
    green: "rgba(36,118,86,1)",
    amber: "rgba(222,139,28,1)",
  };

  return (
    <div style={styles.statCard}>
      <span style={{ ...styles.statGlow, background: colors[tone] }} />
      <p style={styles.statLabel}>{label}</p>
      <p style={styles.statValue}>{value}</p>
    </div>
  );
}

function HelperStep({ title, text }) {
  return (
    <div style={styles.helperStep}>
      <p style={styles.helperTitle}>{title}</p>
      <p style={styles.helperText}>{text}</p>
    </div>
  );
}

const styles = {
  wrap: {
    display: "grid",
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
    background: "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
  },
  hero: {
    display: "grid",
    gridTemplateColumns: "minmax(0, 1fr) auto",
    gap: 16,
    padding: 22,
    borderRadius: 28,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(135deg, rgba(10,25,49,0.98) 0%, rgba(26,59,107,0.96) 58%, rgba(41,112,255,0.9) 100%)",
    boxShadow: "0 24px 44px rgba(20, 42, 77, 0.18)",
    color: "#fff",
  },
  heroEyebrow: {
    fontSize: 11,
    textTransform: "uppercase",
    letterSpacing: "0.1em",
    color: "rgba(220,232,255,0.68)",
    marginBottom: 10,
  },
  heroTitle: {
    fontSize: 32,
    lineHeight: 1.04,
    marginBottom: 10,
    color: "#fff",
  },
  heroText: {
    maxWidth: 680,
    fontSize: 14,
    lineHeight: 1.7,
    color: "rgba(231,240,255,0.84)",
  },
  heroAside: {
    display: "grid",
    gap: 12,
    alignContent: "center",
  },
  statCard: {
    position: "relative",
    overflow: "hidden",
    minWidth: 180,
    padding: "18px 18px",
    borderRadius: 20,
    background: "rgba(255,255,255,0.09)",
    border: "1px solid rgba(255,255,255,0.12)",
    backdropFilter: "blur(8px)",
  },
  statGlow: {
    position: "absolute",
    width: 90,
    height: 90,
    borderRadius: "50%",
    top: -36,
    right: -24,
    opacity: 0.18,
  },
  statLabel: {
    position: "relative",
    zIndex: 1,
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.1em",
    color: "rgba(224,232,255,0.72)",
    marginBottom: 10,
  },
  statValue: {
    position: "relative",
    zIndex: 1,
    fontSize: 28,
    color: "#fff",
    lineHeight: 1,
    fontWeight: 700,
  },
  panel: {
    display: "grid",
    gap: 16,
    padding: 20,
    borderRadius: 24,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.96) 0%, rgba(246,249,252,0.98) 100%)",
    boxShadow: "0 16px 28px rgba(26, 44, 73, 0.06)",
  },
  panelHeader: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    alignItems: "center",
    flexWrap: "wrap",
  },
  panelEyebrow: {
    fontSize: 11,
    textTransform: "uppercase",
    letterSpacing: "0.1em",
    color: "var(--text-muted)",
    marginBottom: 6,
  },
  panelTitle: {
    fontSize: 20,
    color: "var(--text-primary)",
  },
  dispensadorGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
    gap: 12,
  },
  dispensadorCard: {
    padding: 16,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.95) 0%, rgba(247,250,252,0.98) 100%)",
    boxShadow: "0 14px 24px rgba(26, 44, 73, 0.05)",
    display: "grid",
    gap: 8,
    textAlign: "left",
    cursor: "pointer",
  },
  dispensadorCardActive: {
    border: "1px solid rgba(41,112,255,0.26)",
    boxShadow: "0 18px 30px rgba(41,112,255,0.12)",
    transform: "translateY(-1px)",
  },
  cardTopline: {
    display: "flex",
    justifyContent: "space-between",
    gap: 10,
    alignItems: "center",
  },
  cardIndex: {
    width: 38,
    height: 38,
    borderRadius: 14,
    display: "grid",
    placeItems: "center",
    background: "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 14,
    fontWeight: 700,
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  cardMeta: {
    fontSize: 13,
    color: "var(--text-secondary)",
  },
  cardSubmeta: {
    fontSize: 12,
    color: "var(--text-muted)",
  },
  uploadGrid: {
    display: "grid",
    gridTemplateColumns: "minmax(0, 1.2fr) minmax(0, 0.8fr)",
    gap: 14,
  },
  uploadCard: {
    display: "grid",
    alignContent: "start",
    gap: 16,
    padding: 20,
    borderRadius: 24,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.96) 0%, rgba(246,249,252,0.98) 100%)",
    boxShadow: "0 16px 28px rgba(26, 44, 73, 0.06)",
  },
  routePicker: {
    display: "grid",
    gap: 10,
    padding: 14,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(243,247,251,0.88)",
  },
  routeHelp: {
    fontSize: 13,
    color: "var(--text-secondary)",
    lineHeight: 1.5,
    marginTop: 4,
  },
  routePills: {
    display: "flex",
    flexWrap: "wrap",
    gap: 10,
  },
  routeButton: {
    padding: "10px 14px",
    borderRadius: 14,
    border: "1px solid rgba(18,31,53,0.12)",
    background: "#fff",
    color: "var(--text-secondary)",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
    textTransform: "lowercase",
  },
  routeButtonActive: {
    border: "1px solid rgba(41,112,255,0.24)",
    background: "rgba(41,112,255,0.1)",
    color: "var(--accent-strong)",
    boxShadow: "0 10px 18px rgba(41,112,255,0.08)",
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
  fileInput: {
    width: "100%",
    padding: "12px 15px",
    borderRadius: 14,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    color: "var(--text-primary)",
    fontSize: 14,
    outline: "none",
  },
  fileSummary: {
    display: "grid",
    gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
    gap: 12,
    padding: 14,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(243,247,251,0.88)",
  },
  previewBox: {
    display: "grid",
    gap: 12,
    padding: 14,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(243,247,251,0.88)",
  },
  previewHeader: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    alignItems: "center",
    flexWrap: "wrap",
  },
  videoPreview: {
    width: "100%",
    maxHeight: 340,
    borderRadius: 16,
    background: "#08111f",
    objectFit: "contain",
    border: "1px solid rgba(18,31,53,0.08)",
  },
  infoLabel: {
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    color: "var(--text-muted)",
    marginBottom: 6,
  },
  infoValue: {
    fontSize: 13,
    color: "var(--text-primary)",
    fontWeight: 600,
    wordBreak: "break-word",
  },
  actions: {
    display: "flex",
    justifyContent: "flex-end",
  },
  primaryBtn: {
    padding: "14px 18px",
    border: "none",
    borderRadius: 14,
    background: "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  helperList: {
    display: "grid",
    gap: 12,
  },
  helperStep: {
    padding: 14,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(243,247,251,0.88)",
    display: "grid",
    gap: 6,
  },
  helperTitle: {
    fontSize: 14,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  helperText: {
    fontSize: 13,
    lineHeight: 1.6,
    color: "var(--text-secondary)",
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
