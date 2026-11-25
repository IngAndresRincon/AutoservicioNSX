import { useEffect, useState } from "react";
import api from "../services/api";

function Badge({ children, tone = "neutral" }) {
  const tones = {
    blue: { background: "rgba(41,112,255,0.1)", color: "var(--accent-strong)" },
    green: { background: "rgba(36,118,86,0.12)", color: "var(--success-strong)" },
    amber: { background: "rgba(222,139,28,0.12)", color: "var(--amber)" },
    neutral: { background: "rgba(18,31,53,0.06)", color: "var(--text-secondary)" },
  };
  const toneStyle = tones[tone] || tones.neutral;

  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        padding: "7px 10px",
        borderRadius: 999,
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: "0.06em",
        textTransform: "uppercase",
        border: "1px solid rgba(18,31,53,0.08)",
        ...toneStyle,
      }}
    >
      {children}
    </span>
  );
}

function Card({ children, style = {} }) {
  return (
    <div
      style={{
        background:
          "linear-gradient(180deg, rgba(255,255,255,0.95) 0%, rgba(247,250,252,0.98) 100%)",
        border: "1px solid rgba(18,31,53,0.08)",
        borderRadius: 24,
        overflow: "hidden",
        boxShadow: "0 20px 34px rgba(26, 44, 73, 0.08)",
        ...style,
      }}
    >
      {children}
    </div>
  );
}

export default function MapeoPage() {
  const [mapeo, setMapeo] = useState(null);
  const [dispositivos, setDispositivos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filtro, setFiltro] = useState("todos");

  async function cargarMapeo() {
    setLoading(true);
    setError(null);

    try {
      const [mapeoRes, dispositivosRes] = await Promise.all([
        api.get("/Admin/ObtenerMapeoConfiguracion"),
        api.get("/Admin/ObtenerDispositivos"),
      ]);
      setMapeo(mapeoRes.data.data);
      setDispositivos(dispositivosRes.data?.data ?? []);
    } catch {
      setError("No se pudo cargar el mapeo. Verifica la conexión.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const timer = setTimeout(() => {
      cargarMapeo();
    }, 0);

    return () => clearTimeout(timer);
  }, []);

  if (loading) {
    return (
      <div style={page.loadingWrap}>
        <div style={page.spinner} />
        <p style={page.loadingText}>Cargando información del mapeo...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={page.loadingWrap}>
        <p style={page.errorText}>{error}</p>
        <button style={page.retryBtn} onClick={cargarMapeo}>
          Reintentar
        </button>
      </div>
    );
  }

  if (!mapeo) return null;

  const totalDisp = mapeo.dispensadores?.length ?? 0;
  const totalCaras =
    mapeo.dispensadores?.reduce((acc, disp) => acc + (disp.caras?.length ?? 0), 0) ?? 0;
  const totalMang =
    mapeo.dispensadores?.reduce(
      (acc, disp) =>
        acc +
        (disp.caras?.reduce(
          (carasAcc, cara) =>
            carasAcc +
            (cara.posiciones?.reduce(
              (posAcc, pos) => posAcc + (pos.mangueras?.length ?? 0),
              0
            ) ?? 0),
          0
        ) ?? 0),
      0
    ) ?? 0;
  const totalProductos = new Set(
    mapeo.dispensadores?.flatMap((disp) =>
      disp.caras?.flatMap((cara) =>
        cara.posiciones?.flatMap((pos) =>
          pos.mangueras?.map((mang) => mang.producto?.nombreProducto).filter(Boolean) ?? []
        ) ?? []
      ) ?? []
    ) ?? []
  ).size;

  const dispositivosPorDispensador = new Map(
    dispositivos.map((item) => [item.idDispensador, item])
  );

  function esAutoservicio(idDispensador) {
    const dispositivo = dispositivosPorDispensador.get(idDispensador);
    return Boolean(dispositivo?.activo && dispositivo?.identificador);
  }

  const dispensadoresOrdenados = [...(mapeo.dispensadores ?? [])].sort((a, b) => {
    const aConfigurado = esAutoservicio(a.idDispensador) ? 0 : 1;
    const bConfigurado = esAutoservicio(b.idDispensador) ? 0 : 1;
    return aConfigurado - bConfigurado;
  });

  const totalConfigurados = dispensadoresOrdenados.filter((disp) =>
    esAutoservicio(disp.idDispensador)
  ).length;

  const visibles = dispensadoresOrdenados.filter((disp) => {
    if (filtro === "auto") return esAutoservicio(disp.idDispensador);
    if (filtro === "sin") return !esAutoservicio(disp.idDispensador);
    return true;
  });
  const estacion = mapeo.estacion ?? {};
  const coloresEstacion = (estacion.bandera?.colores ?? []).map(colorCss);

  return (
    <div style={page.wrap}>
      <section style={page.overview}>
        <div>
          <div style={page.overviewTop}>
            <Badge tone="blue">Mapeo activo</Badge>
            <span style={page.stationCode}>
              {estacion.bandera?.petrolera || estacion.identificador || "EDS"}
            </span>
          </div>

          <h3 style={page.title}>Mapa operativo de surtidores</h3>
          <p style={page.subtitle}>
            {estacion.nombreEDS || "Configuración general de autoservicio"}
          </p>
        </div>

        <button style={page.refreshBtn} onClick={cargarMapeo} title="Recargar">
          <RefreshIcon />
          <span>Actualizar</span>
        </button>
      </section>

      <section style={page.kpiGrid}>
        <KpiCard label="Dispensadores" value={totalDisp} nota="en la estacion" tone="blue" />
        <KpiCard label="Autoservicio configurado" value={totalConfigurados} nota="con equipo activo" tone="green" />
        <KpiCard label="Caras activas" value={totalCaras} nota="con posiciones" tone="amber" />
        <KpiCard label="Mangueras" value={totalMang} nota="mapeadas" tone="green" />
        <KpiCard label="Productos" value={totalProductos} nota="distintos" tone="slate" />
      </section>

      <section style={page.stationStrip}>
        <StationItem titulo="Colores">
          <div style={{ display: "flex", gap: 6 }}>
            {coloresEstacion.length === 0 && <span style={page.stationValue}>Sin colores</span>}
            {coloresEstacion.map((color, index) => (
              <span key={index} style={{ ...page.swatch, background: color }} title={color} />
            ))}
          </div>
        </StationItem>
        <StationItem titulo="Turnos">
          <div style={page.chipRow}>
            {(estacion.turnos ?? []).length === 0 && <span style={page.stationValue}>Sin turnos</span>}
            {(estacion.turnos ?? []).map((turno, index) => (
              <span key={index} style={page.chip}>
                {turno.horaInicio} - {turno.horaFin}
              </span>
            ))}
          </div>
        </StationItem>
        <StationItem titulo="Marcaciones de dinero">
          <div style={page.chipRow}>
            {(estacion.marcacionesRapidas?.dinero ?? []).map((valor) => (
              <span key={valor} style={page.chip}>${formatoNumero(valor)}</span>
            ))}
          </div>
        </StationItem>
        <StationItem titulo="Marcaciones de volumen">
          <div style={page.chipRow}>
            {(estacion.marcacionesRapidas?.volumen ?? []).map((valor) => (
              <span key={valor} style={page.chip}>{valor} gal</span>
            ))}
          </div>
        </StationItem>
        <StationItem titulo="Maximo de vueltos">
          <span style={page.stationValue}>${formatoNumero(estacion.maximoVueltos ?? 0)}</span>
        </StationItem>
      </section>

      <div style={page.filterRow}>
        {[
          ["todos", "Todos", totalDisp],
          ["auto", "Con autoservicio", totalConfigurados],
          ["sin", "Sin autoservicio", totalDisp - totalConfigurados],
        ].map(([clave, texto, cantidad]) => (
          <button
            key={clave}
            type="button"
            style={{ ...page.filterBtn, ...(filtro === clave ? page.filterBtnOn : {}) }}
            onClick={() => setFiltro(clave)}
          >
            {texto} <span style={page.filterCount}>{cantidad}</span>
          </button>
        ))}
      </div>

      <section style={page.dispGrid}>
        {visibles.map((disp) => {
          const configurado = esAutoservicio(disp.idDispensador);
          const dispositivo = dispositivosPorDispensador.get(disp.idDispensador);
          const caras = disp.caras ?? [];
          const mangueras = caras.reduce(
            (acc, cara) =>
              acc + (cara.posiciones ?? []).reduce((n, pos) => n + (pos.mangueras?.length ?? 0), 0),
            0
          );

          return (
            <Card
              key={disp.idDispensador}
              style={configurado ? { border: "1px solid rgba(36,118,86,0.3)" } : {}}
            >
              <div style={page.dispHeader}>
                <div style={page.dispLead}>
                  <div style={{ ...page.dispIndex, ...(configurado ? page.dispIndexActive : {}) }}>
                    {disp.idDispensador}
                  </div>
                  <div>
                    <p style={page.dispTitle}>Dispensador {disp.idDispensador}</p>
                    <p style={page.dispMeta}>
                      {caras.length} {caras.length === 1 ? "cara" : "caras"} · {mangueras}{" "}
                      {mangueras === 1 ? "manguera" : "mangueras"}
                    </p>
                  </div>
                </div>
                <div style={page.dispStats}>
                  {disp.hibrido && <Badge tone="blue">Hibrido</Badge>}
                  {configurado ? (
                    <Badge tone="green">Autoservicio</Badge>
                  ) : (
                    <Badge tone="amber">Sin autoservicio</Badge>
                  )}
                </div>
              </div>

              {configurado && dispositivo && (
                <p style={page.deviceLine}>
                  <span style={page.deviceKey}>Equipo</span> {dispositivo.identificador}
                  {dispositivo.ip ? <> · <span style={page.deviceKey}>IP</span> {dispositivo.ip}</> : null}
                  {dispositivo.modoHibrido ? " · modo hibrido" : ""}
                </p>
              )}

              {caras.length === 0 ? (
                <p style={page.emptyDisp}>Este dispensador no tiene caras configuradas.</p>
              ) : (
                <div style={page.carasGrid}>
                  {caras.map((cara) => (
                    <div key={cara.numeroCara} style={page.caraCard}>
                      <div style={page.caraHeader}>
                        <div style={page.caraTitleRow}>
                          <div style={page.caraIcon}>
                            <ScreenIcon />
                          </div>
                          <p style={page.caraTitle}>Cara {cara.numeroCara}</p>
                        </div>
                        <span style={page.serial} title={cara.serialPantalla || ""}>
                          {cara.serialPantalla || "Sin serial"}
                        </span>
                      </div>

                      {(cara.posiciones ?? []).map((pos) => (
                        <div key={pos.idPosicion} style={page.posBlock}>
                          <div style={page.posHeader}>
                            <span style={page.posLabel}>Posición {pos.idPosicion}</span>
                            {pos.codigoTankio ? (
                              <span style={page.tankio}>Tankio {pos.codigoTankio}</span>
                            ) : null}
                          </div>

                          {(pos.mangueras ?? []).map((mang) => (
                            <div key={mang.numero} style={page.mangRow}>
                              <span style={{ ...page.mangBar, background: colorCss(mang.color) }} />
                              <div style={{ flex: 1, minWidth: 0 }}>
                                <p style={page.mangProd} title={mang.producto?.nombreProducto}>
                                  {mang.producto?.nombreProducto || "Producto"}
                                </p>
                                <p style={page.mangMeta}>
                                  Manguera {mang.numero} · {mang.lado ? `Lado ${mang.lado}` : "Sin lado"}
                                </p>
                              </div>
                              <div style={page.mangNums}>
                                <span style={page.mangPrice}>${formatoNumero(mang.producto?.precio)}</span>
                                <span style={page.mangMeta}>
                                  max ${formatoNumero(mang.producto?.maximoPreset)}
                                </span>
                              </div>
                            </div>
                          ))}
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              )}
            </Card>
          );
        })}
        {visibles.length === 0 && <p style={page.emptyDisp}>No hay dispensadores en este filtro.</p>}
      </section>
    </div>
  );
}

function StationItem({ titulo, children }) {
  return (
    <div style={page.stationItem}>
      <p style={page.stationLabel}>{titulo}</p>
      {children}
    </div>
  );
}

// Los colores llegan como #AARRGGBB; el CSS los lee como #RRGGBBAA
function colorCss(color) {
  if (!color) return "#d2d8e1";
  return color.length === 9 ? `#${color.slice(3)}` : color;
}

function formatoNumero(valor) {
  const numero = Number(valor);
  return Number.isFinite(numero) ? numero.toLocaleString("es-CO") : "0";
}

function KpiCard({ label, value, nota, tone }) {
  return (
    <div className={`cfg-stat cfg-stat-${tone}`}>
      <p className="cfg-stat-label">{label}</p>
      <p className="cfg-stat-value">{value}</p>
      <p className="cfg-stat-note">{nota}</p>
    </div>
  );
}

function ScreenIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
      <rect x="1.5" y="2.5" width="13" height="9" rx="2" stroke="var(--text-secondary)" strokeWidth="1.2" />
      <path d="M5 13.5h6M8 11.5v2" stroke="var(--text-secondary)" strokeWidth="1.2" strokeLinecap="round" />
    </svg>
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

const page = {
  wrap: {
    display: "flex",
    flexDirection: "column",
    gap: 18,
  },
  loadingWrap: {
    minHeight: 360,
    display: "grid",
    placeItems: "center",
    gap: 14,
    alignContent: "center",
  },
  spinner: {
    width: 30,
    height: 30,
    border: "3px solid rgba(18,31,53,0.12)",
    borderTopColor: "var(--accent-strong)",
    borderRadius: "50%",
    animation: "spin 0.8s linear infinite",
  },
  loadingText: {
    fontSize: 14,
    color: "var(--text-secondary)",
  },
  errorText: {
    fontSize: 14,
    color: "var(--danger)",
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
  overview: {
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
  overviewTop: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    marginBottom: 12,
    flexWrap: "wrap",
  },
  stationCode: {
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
  kpiGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(170px, 1fr))",
    gap: 14,
  },
  section: {
    display: "flex",
    flexDirection: "column",
    gap: 16,
  },
  stationStrip: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(190px, 1fr))",
    gap: 16,
    padding: "18px 22px",
    borderRadius: 22,
    background: "rgba(255,255,255,0.9)",
    border: "1px solid rgba(18,31,53,0.08)",
  },
  stationItem: { display: "grid", gap: 8, alignContent: "start" },
  stationLabel: {
    margin: 0,
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.1em",
    color: "var(--text-muted)",
  },
  stationValue: { fontSize: 15, fontWeight: 700, color: "var(--text-primary)" },
  swatch: {
    width: 30,
    height: 30,
    borderRadius: 10,
    border: "2px solid #fff",
    boxShadow: "0 4px 10px rgba(18,31,53,0.16)",
  },
  chipRow: { display: "flex", gap: 6, flexWrap: "wrap" },
  chip: {
    padding: "5px 10px",
    borderRadius: 999,
    background: "rgba(18,31,53,0.06)",
    color: "var(--text-primary)",
    fontSize: 12,
    fontWeight: 600,
  },
  filterRow: { display: "flex", gap: 8, flexWrap: "wrap" },
  filterBtn: {
    padding: "9px 14px",
    borderRadius: 999,
    border: "1px solid rgba(18,31,53,0.1)",
    background: "#fff",
    color: "var(--text-secondary)",
    fontSize: 13,
    fontWeight: 600,
    cursor: "pointer",
  },
  filterBtnOn: {
    background: "rgba(41,112,255,0.1)",
    borderColor: "rgba(41,112,255,0.3)",
    color: "var(--accent-strong)",
  },
  filterCount: { marginLeft: 6, fontWeight: 700 },
  dispGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 460px), 1fr))",
    gap: 16,
    alignItems: "start",
  },
  deviceLine: {
    margin: 0,
    padding: "10px 20px",
    fontSize: 12,
    color: "var(--text-secondary)",
    background: "rgba(36,118,86,0.06)",
    borderBottom: "1px solid rgba(18,31,53,0.06)",
  },
  deviceKey: {
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.06em",
    fontSize: 10,
    color: "var(--text-muted)",
  },
  emptyDisp: {
    margin: 0,
    padding: "18px 20px",
    fontSize: 13,
    color: "var(--text-muted)",
  },
  tankio: {
    padding: "3px 9px",
    borderRadius: 999,
    background: "rgba(41,112,255,0.1)",
    color: "var(--accent-strong)",
    fontSize: 11,
    fontWeight: 700,
  },
  mangBar: { width: 5, alignSelf: "stretch", borderRadius: 4, flexShrink: 0 },
  mangNums: { display: "grid", justifyItems: "end", gap: 2, flexShrink: 0 },
  mangPrice: { fontSize: 13, fontWeight: 700, color: "var(--text-primary)" },
  dispHeader: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    alignItems: "center",
    flexWrap: "wrap",
    padding: "16px 20px",
    background:
      "linear-gradient(180deg, rgba(13, 28, 54, 0.03) 0%, rgba(13, 28, 54, 0.01) 100%)",
    borderBottom: "1px solid rgba(18,31,53,0.08)",
  },
  dispLead: { display: "flex", alignItems: "center", gap: 12 },
  dispIndex: {
    width: 42,
    height: 42,
    borderRadius: 14,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "linear-gradient(135deg, rgba(120,132,152,1) 0%, rgba(90,102,122,1) 100%)",
    color: "#fff",
    fontSize: 16,
    fontWeight: 700,
  },
  dispIndexActive: {
    background: "linear-gradient(135deg, rgba(36,118,86,1) 0%, rgba(24,90,64,1) 100%)",
    boxShadow: "0 12px 20px rgba(36,118,86,0.22)",
  },
  dispTitle: { fontSize: 17, color: "var(--text-primary)", fontWeight: 700, margin: 0 },
  dispMeta: { fontSize: 12, color: "var(--text-secondary)", margin: "3px 0 0" },
  dispStats: { display: "flex", gap: 6, flexWrap: "wrap" },
  carasGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 280px), 1fr))",
    gap: 12,
    padding: 14,
  },
  caraCard: {
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(246,249,252,0.9)",
    padding: 12,
    display: "grid",
    gap: 10,
    alignContent: "start",
  },
  caraHeader: { display: "flex", justifyContent: "space-between", gap: 10, alignItems: "center" },
  caraTitleRow: { display: "flex", alignItems: "center", gap: 8 },
  caraIcon: {
    width: 30,
    height: 30,
    borderRadius: 10,
    background: "rgba(41,112,255,0.08)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  caraTitle: { fontSize: 14, fontWeight: 700, color: "var(--text-primary)", margin: 0 },
  serial: {
    maxWidth: 130,
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
    padding: "5px 9px",
    borderRadius: 999,
    background: "rgba(18,31,53,0.06)",
    color: "var(--text-secondary)",
    fontSize: 11,
    fontWeight: 600,
  },
  posBlock: { display: "grid", gap: 6 },
  posHeader: { display: "flex", justifyContent: "space-between", gap: 8, alignItems: "center" },
  posLabel: {
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    color: "var(--text-muted)",
  },
  mangRow: {
    display: "flex",
    gap: 10,
    alignItems: "center",
    padding: "9px 12px 9px 9px",
    borderRadius: 14,
    background: "#fff",
    border: "1px solid rgba(18,31,53,0.07)",
  },
  mangProd: {
    fontSize: 13,
    fontWeight: 700,
    color: "var(--text-primary)",
    margin: "0 0 2px",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
  },
  mangMeta: {
    fontSize: 12,
    color: "var(--text-secondary)",
  },
};
