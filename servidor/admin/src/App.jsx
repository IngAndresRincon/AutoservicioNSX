import { useEffect, useState } from "react";
import ColoresPage from "./pages/ColoresPage";
import Login from "./pages/Login";
import ConfiguracionPage from "./pages/ConfiguracionPage";
import MapeoPage from "./pages/MapeoPage";
import PublicidadPage from "./pages/PublicidadPage";
import ReportesPage from "./pages/ReportesPage";
import TurnosPage from "./pages/TurnosPage";
import api from "./services/api";
import "./styles/theme.css";

const NAV_ITEMS = [
  { id: "mapeo", label: "Visualizacion Mapeo", icon: MapIcon, tone: "blue" },
  { id: "configuracion", label: "Configuracion", icon: DeviceIcon, tone: "amber" },
  { id: "colores", label: "Colores Interfaz", icon: PaletteIcon, tone: "green" },
  { id: "turnos", label: "Turnos", icon: ClockIcon, tone: "slate" },
  { id: "videos", label: "Publicidad", icon: VideoIcon, tone: "red" },
  { id: "reportes", label: "Reportes", icon: ChartIcon, tone: "slate" },
];

const TITULO_BASE = "NSX Autoservicio · Administración";
const CLAVE_ACTIVIDAD = "lastActivity";
const LIMITE_INACTIVIDAD_MS = 30 * 60 * 1000;
const AVISO_INACTIVIDAD_MS = 60 * 1000;

export default function App() {
  const auth = localStorage.getItem("auth");
  const [active, setActive] = useState("mapeo");
  const [sistema, setSistema] = useState("NSX");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const [avisoInactividad, setAvisoInactividad] = useState(false);
  const activeItem = NAV_ITEMS.find((item) => item.id === active) ?? NAV_ITEMS[0];
  const sidebarVisible = isMobile ? sidebarOpen : !sidebarCollapsed;

  useEffect(() => {
    const modulo = NAV_ITEMS.find((item) => item.id === active)?.label;
    document.title = modulo ? `${modulo} · NSX Autoservicio` : TITULO_BASE;
  }, [active]);

  useEffect(() => {
    const mq = window.matchMedia("(max-width: 900px)");
    const update = () => setIsMobile(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);

  function closeSidebar() {
    if (isMobile) {
      setSidebarOpen(false);
    } else {
      setSidebarCollapsed(true);
    }
  }

  function toggleSidebar() {
    if (isMobile) {
      setSidebarOpen((current) => !current);
    } else {
      setSidebarCollapsed((current) => !current);
    }
  }

  useEffect(() => {
    if (!auth) return;

    let cancelado = false;

    api
      .get("/Admin/ObtenerMapeoConfiguracion")
      .then((res) => {
        const petrolera = res.data?.data?.estacion?.bandera?.petrolera;
        if (!cancelado && petrolera) {
          setSistema(petrolera);
        }
      })
      .catch(() => {});

    return () => {
      cancelado = true;
    };
  }, [auth]);

  // La sesion se cierra tras 30 minutos sin actividad (se avisa el ultimo minuto). La marca de actividad
  // vive en localStorage, asi que tambien cuenta si se cierra el navegador y se vuelve a abrir mas tarde.
  useEffect(() => {
    if (!auth) return undefined;

    let ultimaEscritura = 0;
    const leerActividad = () => Number(localStorage.getItem(CLAVE_ACTIVIDAD) || 0);

    function marcarActividad() {
      const ahora = Date.now();
      if (ahora - ultimaEscritura > 5000) {
        ultimaEscritura = ahora;
        localStorage.setItem(CLAVE_ACTIVIDAD, String(ahora));
      }
      setAvisoInactividad(false);
    }

    function revisar() {
      const ultima = leerActividad();
      if (!ultima) {
        localStorage.setItem(CLAVE_ACTIVIDAD, String(Date.now()));
        return;
      }
      const inactivo = Date.now() - ultima;
      if (inactivo >= LIMITE_INACTIVIDAD_MS) {
        localStorage.clear();
        window.location.href = "/";
        return;
      }
      setAvisoInactividad(inactivo >= LIMITE_INACTIVIDAD_MS - AVISO_INACTIVIDAD_MS);
    }

    const eventos = ["mousedown", "keydown", "touchstart", "wheel", "mousemove"];
    eventos.forEach((evento) => window.addEventListener(evento, marcarActividad, { passive: true }));
    const primera = setTimeout(revisar, 0);
    const intervalo = setInterval(revisar, 15000);

    return () => {
      eventos.forEach((evento) => window.removeEventListener(evento, marcarActividad));
      clearTimeout(primera);
      clearInterval(intervalo);
    };
  }, [auth]);

  if (!auth) return <Login />;

  const user = JSON.parse(localStorage.getItem("user") || "{}");

  return (
    <div className="app-viewport" style={styles.viewport}>
      <div style={styles.bgGlowTop} aria-hidden />
      <div style={styles.bgGlowBottom} aria-hidden />

      {avisoInactividad && (
        <div role="alertdialog" aria-label="Sesion por vencer" style={styles.avisoSesion}>
          <div>
            <strong style={styles.avisoTitulo}>Tu sesion esta por cerrarse</strong>
            <p style={styles.avisoTexto}>Llevas casi 30 minutos sin actividad.</p>
          </div>
          <button
            type="button"
            style={styles.avisoBtn}
            onClick={() => {
              localStorage.setItem(CLAVE_ACTIVIDAD, String(Date.now()));
              setAvisoInactividad(false);
            }}
          >
            Seguir conectado
          </button>
        </div>
      )}

      {!sidebarVisible && (
        <button
          type="button"
          className="app-menu-btn"
          style={styles.menuBtn}
          onClick={toggleSidebar}
          aria-label="Abrir menu"
        >
          <MenuIcon />
        </button>
      )}

      <div
        className={`app-sidebar-backdrop${sidebarOpen ? " app-sidebar-backdrop-visible" : ""}`}
        onClick={closeSidebar}
        aria-hidden
      />

      <div
        className={`app-shell${sidebarCollapsed ? " app-shell-collapsed" : ""}`}
        style={styles.shell}
      >
        <aside
          className={`app-sidebar${sidebarOpen ? " app-sidebar-open" : ""}`}
          style={styles.sidebar}
        >
          <div className="app-sidebar-inner" style={styles.sidebarInner}>
            <div style={styles.brandPanel}>
              <button
                type="button"
                className="app-sidebar-close"
                style={styles.sidebarCloseBtn}
                onClick={closeSidebar}
                aria-label="Cerrar menu"
              >
                <CloseIcon />
              </button>

              <div style={styles.brandMarkRow}>
                <div style={styles.brandMark}>
                  <img src="/logo-nsx.png" alt="Logo NSX" style={styles.brandMarkImg} />
                </div>
                <div style={styles.brandMarkWide}>
                  <img
                    src="/logo-insepet.png"
                    alt="Logo Insepet"
                    style={styles.brandMarkImgWide}
                  />
                </div>
              </div>
              <div>
                <p style={styles.brandEyebrow}>Portal operativo</p>
                <h1 style={styles.brandTitle}>Autoservicio {sistema}</h1>
                <p style={styles.brandText}>
                  Monitorea la configuracion de isla, colores, contenidos y
                  despliegue desde un solo lugar.
                </p>
              </div>
            </div>

            <div style={styles.userCard}>
              <div style={styles.avatar}>
                {(user?.nombres?.[0] || "U").toUpperCase()}
              </div>
              <div style={{ minWidth: 0 }}>
                <p style={styles.userName}>{user?.nombres || "Usuario"}</p>
                <p style={styles.userRole}>Administrador del portal</p>
              </div>
            </div>

            <div style={styles.statusStrip}>
              <StatusPill label="Portal activo" tone="green" />
              <StatusPill label="Tiempo real" tone="blue" />
            </div>

            <nav className="app-nav" style={styles.nav}>
              <p style={styles.navSection}>Modulos</p>
              {NAV_ITEMS.map(({ id, label, icon: Icon, tone }) => {
                const isActive = active === id;
                return (
                  <button
                    key={id}
                    className="app-nav-item"
                    style={{
                      ...styles.navItem,
                      ...(isActive ? styles.navItemActive : {}),
                    }}
                    onClick={() => {
                      setActive(id);
                      setSidebarOpen(false);
                    }}
                  >
                    <span
                      style={{
                        ...styles.navIconWrap,
                        ...(isActive ? styles.navIconWrapActive : {}),
                      }}
                    >
                      <Icon size={16} active={isActive} />
                    </span>
                    <span style={styles.navLabel}>{label}</span>
                    <span
                      style={{
                        ...styles.navTone,
                        background: toneToColor(tone),
                        opacity: isActive ? 1 : 0.45,
                      }}
                    />
                  </button>
                );
              })}
            </nav>
          </div>

          <div style={styles.sidebarFooter}>
            <button
              style={styles.logoutBtn}
              onClick={() => {
                localStorage.clear();
                window.location.href = "/";
              }}
            >
              Cerrar sesion
            </button>
          </div>
        </aside>

        <main style={styles.main}>
          <section className="app-hero" style={styles.hero}>
            <div>
              <p style={styles.heroEyebrow}>Centro de control</p>
              <h2 style={styles.heroTitle}>
                {active === "mapeo" && "Vista central de configuracion de pista"}
                {active === "configuracion" && "Asignacion de dispositivos por dispensador"}
                {active === "colores" && "Colores Interfaz para el autoservicio"}
                {active === "turnos" && "Horario operativo en formato 24 horas"}
                {active === "videos" && "Carga de publicidad por dispensador"}
                {active === "reportes" && "Dashboard ejecutivo de reporteria"}
                {active !== "mapeo" &&
                  active !== "configuracion" &&
                  active !== "colores" &&
                  active !== "turnos" &&
                  active !== "videos" &&
                  active !== "reportes" &&
                  `${activeItem.label} en evolucion`}
              </h2>
              <p style={styles.heroText}>
                Un panel mas claro para operar estaciones, revisar estructura y
                detectar cambios rapidamente.
              </p>
            </div>

            <div className="app-hero-metrics" style={styles.heroMetrics}>
              <HeroMetric value="24/7" label="Portal disponible" />
              <HeroMetric value="5" label="Modulos listos" />
            </div>
          </section>

          <div style={styles.contentWrap}>
            {active === "mapeo" && <MapeoPage />}
            {active === "configuracion" && <ConfiguracionPage />}
            {active === "colores" && <ColoresPage />}
            {active === "turnos" && <TurnosPage />}
            {active === "videos" && <PublicidadPage />}
            {active === "reportes" && <ReportesPage />}
            {active !== "mapeo" && active !== "configuracion" && active !== "colores" && active !== "turnos" && active !== "videos" && active !== "reportes" && (
              <div style={styles.placeholder}>
                <div style={styles.placeholderCard}>
                  <span style={styles.placeholderBadge}>Proxima vista</span>
                  <h3 style={styles.placeholderTitle}>{activeItem.label}</h3>
                  <p style={styles.placeholderText}>
                    Dejamos esta seccion preparada con la nueva identidad del
                    portal para que luego podamos sumar su logica sin rehacer el
                    layout.
                  </p>
                </div>
              </div>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}

function HeroMetric({ value, label }) {
  return (
    <div style={styles.heroMetric}>
      <p style={styles.heroMetricValue}>{value}</p>
      <p style={styles.heroMetricLabel}>{label}</p>
    </div>
  );
}

function StatusPill({ label, tone }) {
  return (
    <span
      style={{
        ...styles.statusPill,
        color: tone === "green" ? "var(--success-strong)" : "var(--accent-strong)",
        background:
          tone === "green" ? "rgba(36, 118, 86, 0.12)" : "rgba(41, 112, 255, 0.12)",
      }}
    >
      <span
        style={{
          ...styles.statusDot,
          background:
            tone === "green" ? "var(--success-strong)" : "var(--accent-strong)",
        }}
      />
      {label}
    </span>
  );
}

function toneToColor(tone) {
  switch (tone) {
    case "amber":
      return "var(--amber)";
    case "green":
      return "var(--success-strong)";
    case "red":
      return "var(--danger)";
    case "slate":
      return "var(--slate)";
    default:
      return "var(--accent)";
  }
}

const styles = {
  viewport: {
    minHeight: "100vh",
    background:
      "radial-gradient(circle at top left, rgba(41,112,255,0.16), transparent 28%), radial-gradient(circle at bottom right, rgba(244,138,31,0.12), transparent 24%), linear-gradient(180deg, #f4f7fb 0%, #eef2f7 100%)",
    position: "relative",
    overflow: "hidden",
  },
  bgGlowTop: {
    position: "absolute",
    width: 420,
    height: 420,
    borderRadius: "50%",
    background: "rgba(41,112,255,0.08)",
    filter: "blur(18px)",
    top: -140,
    right: -110,
  },
  bgGlowBottom: {
    position: "absolute",
    width: 320,
    height: 320,
    borderRadius: "50%",
    background: "rgba(255,165,76,0.1)",
    filter: "blur(24px)",
    bottom: -120,
    left: -90,
  },
  shell: {
    position: "relative",
    zIndex: 1,
    minHeight: "calc(100vh - 36px)",
    border: "1px solid rgba(255,255,255,0.75)",
    background: "rgba(248, 250, 252, 0.76)",
    backdropFilter: "blur(18px)",
    boxShadow: "0 28px 80px rgba(21, 38, 63, 0.14)",
    borderRadius: 28,
    overflow: "hidden",
  },
  sidebar: {
    background:
      "linear-gradient(180deg, rgba(11, 24, 48, 0.97) 0%, rgba(15, 29, 56, 0.97) 100%)",
    color: "#fff",
    padding: 18,
  },
  sidebarInner: {},
  brandPanel: {
    position: "relative",
    borderRadius: 22,
    padding: 18,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.04) 100%)",
    border: "1px solid rgba(255,255,255,0.08)",
    display: "grid",
    gap: 14,
  },
  menuBtn: {
    position: "fixed",
    top: 16,
    left: 16,
    zIndex: 70,
    width: 42,
    height: 42,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 14,
    border: "1px solid rgba(255,255,255,0.14)",
    background:
      "linear-gradient(135deg, rgba(15,32,61,0.96) 0%, rgba(27,74,138,0.96) 100%)",
    boxShadow: "0 12px 24px rgba(8,16,32,0.3)",
    cursor: "pointer",
  },
  sidebarCloseBtn: {
    position: "absolute",
    top: 12,
    right: 12,
    width: 30,
    height: 30,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 10,
    border: "1px solid rgba(255,255,255,0.14)",
    background: "rgba(255,255,255,0.06)",
    cursor: "pointer",
  },
  brandMarkRow: {
    display: "flex",
    gap: 10,
  },
  brandMark: {
    width: 58,
    height: 58,
    borderRadius: 18,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "rgba(255,255,255,0.07)",
    border: "1px solid rgba(255,255,255,0.1)",
    boxShadow: "0 18px 35px rgba(8,16,32,0.35)",
    flexShrink: 0,
  },
  brandMarkImg: {
    width: "72%",
    height: "72%",
    objectFit: "contain",
  },
  brandMarkWide: {
    width: 112,
    height: 58,
    borderRadius: 18,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "rgba(255,255,255,0.07)",
    border: "1px solid rgba(255,255,255,0.1)",
    boxShadow: "0 18px 35px rgba(8,16,32,0.35)",
    flexShrink: 0,
    padding: "0 10px",
  },
  brandMarkImgWide: {
    width: "100%",
    height: "82%",
    objectFit: "contain",
  },
  brandEyebrow: {
    fontSize: 11,
    textTransform: "uppercase",
    letterSpacing: "0.12em",
    color: "rgba(224,232,255,0.72)",
    marginBottom: 8,
  },
  brandTitle: {
    fontSize: 28,
    lineHeight: 1,
    color: "#fff",
    marginBottom: 10,
  },
  brandText: {
    fontSize: 13,
    lineHeight: 1.6,
    color: "rgba(224,232,255,0.78)",
  },
  statusStrip: {
    display: "flex",
    gap: 8,
    flexWrap: "wrap",
  },
  statusPill: {
    display: "inline-flex",
    alignItems: "center",
    gap: 8,
    padding: "8px 10px",
    borderRadius: 999,
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: "0.02em",
  },
  statusDot: {
    width: 7,
    height: 7,
    borderRadius: "50%",
  },
  nav: {},
  navSection: {
    fontSize: 11,
    color: "rgba(224,232,255,0.64)",
    textTransform: "uppercase",
    letterSpacing: "0.12em",
    padding: "4px 4px 0",
  },
  navItem: {
    padding: "12px 14px",
    borderRadius: 18,
    border: "1px solid rgba(255,255,255,0.06)",
    background: "rgba(255,255,255,0.03)",
    display: "flex",
    alignItems: "center",
    gap: 12,
    color: "rgba(239,244,255,0.78)",
    cursor: "pointer",
    textAlign: "left",
    transition: "transform 0.18s ease, background 0.18s ease, border-color 0.18s ease",
  },
  navItemActive: {
    background:
      "linear-gradient(135deg, rgba(41,112,255,0.26) 0%, rgba(41,112,255,0.14) 100%)",
    border: "1px solid rgba(115,170,255,0.3)",
    color: "#fff",
    transform: "translateX(4px)",
  },
  navIconWrap: {
    width: 34,
    height: 34,
    borderRadius: 12,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "rgba(255,255,255,0.05)",
    flexShrink: 0,
  },
  navIconWrapActive: {
    background: "rgba(255,255,255,0.1)",
  },
  navLabel: {
    fontSize: 14,
    fontWeight: 500,
    flex: 1,
  },
  navTone: {
    width: 8,
    height: 8,
    borderRadius: "50%",
    flexShrink: 0,
  },
  sidebarFooter: {
    display: "grid",
    gap: 12,
    marginTop: 4,
  },
  userCard: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    padding: 14,
    borderRadius: 18,
    background: "rgba(255,255,255,0.04)",
    border: "1px solid rgba(255,255,255,0.07)",
  },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 14,
    background:
      "linear-gradient(135deg, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0.06) 100%)",
    border: "1px solid rgba(255,255,255,0.12)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: 15,
    fontWeight: 700,
    flexShrink: 0,
  },
  userName: {
    fontSize: 14,
    fontWeight: 600,
    color: "#fff",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
  },
  userRole: {
    fontSize: 12,
    color: "rgba(224,232,255,0.68)",
    marginTop: 3,
  },
  logoutBtn: {
    border: "1px solid rgba(255,255,255,0.1)",
    background: "transparent",
    color: "#eef4ff",
    fontSize: 13,
    fontWeight: 500,
    borderRadius: 16,
    padding: "12px 14px",
    cursor: "pointer",
  },
  avisoSesion: {
    position: "fixed",
    right: 24,
    bottom: 24,
    zIndex: 60,
    display: "flex",
    alignItems: "center",
    gap: 18,
    maxWidth: "calc(100vw - 48px)",
    padding: "16px 18px",
    borderRadius: 18,
    background: "#fff",
    border: "1px solid rgba(222,139,28,0.35)",
    boxShadow: "0 18px 40px rgba(24,44,78,0.22)",
  },
  avisoTitulo: {
    display: "block",
    fontSize: 14,
    color: "var(--text-primary)",
  },
  avisoTexto: {
    marginTop: 3,
    fontSize: 12.5,
    color: "var(--text-secondary)",
  },
  avisoBtn: {
    flex: "none",
    padding: "10px 16px",
    border: "none",
    borderRadius: 12,
    background: "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  main: {
    padding: 22,
    display: "flex",
    flexDirection: "column",
    gap: 18,
    overflow: "auto",
  },
  hero: {
    minHeight: 180,
    borderRadius: 26,
    padding: "28px 28px 24px",
    background:
      "linear-gradient(125deg, rgba(12,26,50,0.96) 0%, rgba(26,60,111,0.93) 54%, rgba(41,112,255,0.82) 100%)",
    color: "#fff",
    gap: 18,
    boxShadow: "0 22px 44px rgba(17, 45, 83, 0.22)",
  },
  heroEyebrow: {
    fontSize: 11,
    textTransform: "uppercase",
    letterSpacing: "0.14em",
    color: "rgba(219,232,255,0.72)",
    marginBottom: 10,
  },
  heroTitle: {
    fontSize: 34,
    lineHeight: 1.02,
    maxWidth: 640,
    marginBottom: 12,
    color: "#fff",
  },
  heroText: {
    maxWidth: 640,
    fontSize: 14,
    lineHeight: 1.65,
    color: "rgba(232,240,255,0.82)",
  },
  heroMetrics: {
    gap: 12,
  },
  heroMetric: {
    minWidth: 120,
    padding: "16px 18px",
    borderRadius: 18,
    background: "rgba(255,255,255,0.09)",
    border: "1px solid rgba(255,255,255,0.12)",
    backdropFilter: "blur(8px)",
  },
  heroMetricValue: {
    fontSize: 26,
    fontWeight: 700,
    color: "#fff",
    lineHeight: 1,
    marginBottom: 8,
  },
  heroMetricLabel: {
    fontSize: 12,
    color: "rgba(232,240,255,0.78)",
  },
  contentWrap: {
    minHeight: 0,
  },
  placeholder: {
    minHeight: 320,
    display: "grid",
    placeItems: "center",
  },
  placeholderCard: {
    maxWidth: 520,
    padding: 30,
    borderRadius: 24,
    border: "1px solid rgba(35, 57, 94, 0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.88) 0%, rgba(245,248,252,0.92) 100%)",
    boxShadow: "0 18px 34px rgba(32, 54, 90, 0.08)",
  },
  placeholderBadge: {
    display: "inline-flex",
    padding: "7px 10px",
    borderRadius: 999,
    background: "rgba(41,112,255,0.08)",
    color: "var(--accent-strong)",
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    marginBottom: 14,
  },
  placeholderTitle: {
    fontSize: 28,
    color: "var(--text-primary)",
    marginBottom: 10,
  },
  placeholderText: {
    fontSize: 14,
    color: "var(--text-secondary)",
    lineHeight: 1.7,
  },
};

function MapIcon({ size = 16, active }) {
  const c = active ? "#fff" : "rgba(239,244,255,0.75)";
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M8 1.5C5.79 1.5 4 3.29 4 5.5c0 3.25 4 9 4 9s4-5.75 4-9c0-2.21-1.79-4-4-4z" stroke={c} strokeWidth="1.25" strokeLinejoin="round" />
      <circle cx="8" cy="5.5" r="1.5" stroke={c} strokeWidth="1.25" />
    </svg>
  );
}

function DeviceIcon({ size = 16, active }) {
  const c = active ? "#fff" : "rgba(239,244,255,0.75)";
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="3" width="12" height="8" rx="1.5" stroke={c} strokeWidth="1.25" />
      <path d="M5 13h6" stroke={c} strokeWidth="1.25" strokeLinecap="round" />
    </svg>
  );
}

function PaletteIcon({ size = 16, active }) {
  const c = active ? "#fff" : "rgba(239,244,255,0.75)";
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="5.5" stroke={c} strokeWidth="1.25" />
      <circle cx="5.5" cy="6.5" r="1" fill={c} />
      <circle cx="8" cy="5" r="1" fill={c} />
      <circle cx="10.5" cy="6.5" r="1" fill={c} />
    </svg>
  );
}

function VideoIcon({ size = 16, active }) {
  const c = active ? "#fff" : "rgba(239,244,255,0.75)";
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="1.5" y="3.5" width="10" height="9" rx="1.5" stroke={c} strokeWidth="1.25" />
      <path d="M11.5 6.5l3-2v7l-3-2" stroke={c} strokeWidth="1.25" strokeLinejoin="round" />
    </svg>
  );
}

function ChartIcon({ size = 16, active }) {
  const c = active ? "#fff" : "rgba(239,244,255,0.75)";
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M2 12l3.5-4 3 2.5L12 5" stroke={c} strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M10.8 5H12v1.3" stroke={c} strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function ClockIcon({ size = 16, active }) {
  const c = active ? "#fff" : "rgba(239,244,255,0.75)";
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="5.5" stroke={c} strokeWidth="1.25" />
      <path d="M8 4.8V8l2.3 1.6" stroke={c} strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function MenuIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M2.5 5h13M2.5 9h13M2.5 13h13" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

function CloseIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M3.5 3.5l9 9M12.5 3.5l-9 9" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}
