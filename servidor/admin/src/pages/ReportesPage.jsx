import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import api from "../services/api";
import { imprimirNodo, nodoAJpg } from "../utils/exportarVista";

const VENTAS_PATH = "/Reportes/Ventas";
const DASHBOARD_PATH = "/Reportes/Dashboard";
const PAGE_SIZE = 20;

const PRESETS = [
  { key: "hoy", label: "Hoy" },
  { key: "7d", label: "7 días" },
  { key: "30d", label: "30 días" },
  { key: "mes", label: "Este mes" },
];

const CANALES = [
  { key: "Autoservicio", label: "Autoservicio", color: "#2970ff" },
  { key: "Vendedor", label: "Vendedor de paso", color: "#e98a14" },
  { key: "Tradicional", label: "Tradicional", color: "#8c9ab1" },
];
const CANAL_COLOR = Object.fromEntries(CANALES.map((c) => [c.key, c.color]));
const CANAL_LABEL = Object.fromEntries(CANALES.map((c) => [c.key, c.label]));

const DIAS = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
const TIPOS_TRANSACCION = {
  1: "Efectivo",
  2: "Prepago local",
  3: "Crédito local",
  20: "Autoservicio",
};

const FILTROS_VACIOS = {
  canal: null,
  vendedor: null,
  producto: null,
  pago: null,
  dia: null,
  celda: null,
};

export default function ReportesPage() {
  const hoy = useMemo(() => new Date(), []);
  const [rango, setRango] = useState(() => ({
    inicio: formatDateInput(new Date(hoy.getFullYear(), hoy.getMonth(), 1)),
    fin: formatDateInput(hoy),
  }));
  const [preset, setPreset] = useState("mes");
  const [datos, setDatos] = useState({ ventas: [], truncado: false });
  const [previo, setPrevio] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState("");
  const [filtros, setFiltros] = useState(FILTROS_VACIOS);
  const [metricaMapa, setMetricaMapa] = useState("total");
  const [busqueda, setBusqueda] = useState("");
  const [orden, setOrden] = useState({ key: "fecha", dir: "desc" });
  const [pagina, setPagina] = useState(0);
  const [detalleId, setDetalleId] = useState(null);
  const [exportando, setExportando] = useState("");
  const [avisoExport, setAvisoExport] = useState("");
  const [vistaPrevia, setVistaPrevia] = useState(null);
  const capturaRef = useRef(null);
  const generadoRef = useRef(null);

  const cargar = useCallback(async () => {
    setCargando(true);
    setError("");

    try {
      // El periodo anterior solo sirve para comparar los totales; se pide el resumen, no las ventas
      const anterior = rangoAnterior(rango.inicio, rango.fin);
      const [actualRes, previoRes] = await Promise.all([
        api.get(VENTAS_PATH, { params: { fechaInicio: rango.inicio, fechaFin: rango.fin } }),
        api
          .get(DASHBOARD_PATH, { params: { fechaInicio: anterior.inicio, fechaFin: anterior.fin } })
          .catch(() => null),
      ]);

      setDatos({
        ventas: (actualRes.data?.data?.ventas ?? []).map(prepararVenta),
        truncado: Boolean(actualRes.data?.data?.truncado),
      });
      setPrevio(previoRes?.data?.data?.kpis ?? null);
    } catch (err) {
      setError(
        err?.response?.data?.message || "No fue posible cargar las ventas del rango."
      );
    } finally {
      setCargando(false);
    }
  }, [rango]);

  useEffect(() => {
    const timer = setTimeout(() => {
      cargar();
    }, 0);

    return () => clearTimeout(timer);
  }, [cargar]);

  function aplicarPreset(key) {
    const fin = new Date();
    const inicio = new Date();
    if (key === "7d") inicio.setDate(fin.getDate() - 6);
    if (key === "30d") inicio.setDate(fin.getDate() - 29);
    if (key === "mes") inicio.setDate(1);
    setPreset(key);
    setFiltros(FILTROS_VACIOS);
    setPagina(0);
    setRango({ inicio: formatDateInput(inicio), fin: formatDateInput(fin) });
  }

  function cambiarFecha(campo, valor) {
    if (!valor) return;
    setPreset("");
    setFiltros(FILTROS_VACIOS);
    setPagina(0);
    setRango((actual) => ({ ...actual, [campo]: valor }));
  }

  function alternar(clave, valor) {
    setPagina(0);
    setFiltros((actual) => ({
      ...actual,
      [clave]: sonIguales(actual[clave], valor) ? null : valor,
    }));
  }

  function limpiar() {
    setPagina(0);
    setFiltros(FILTROS_VACIOS);
  }

  const ventas = datos.ventas;

  // Cada gráfica muestra los datos filtrados por todo menos por su propia dimensión,
  // así se ven las demás opciones mientras una está seleccionada
  const vista = useCallback(
    (excluir) => ventas.filter((v) => cumple(v, filtros, excluir)),
    [ventas, filtros]
  );

  const base = useMemo(() => vista(null), [vista]);

  const hayFiltros = Object.values(filtros).some(Boolean);

  // Con filtros activos no se compara: el periodo anterior solo se conoce sin filtrar
  const kpis = useMemo(() => {
    const actual = resumen(base);
    const comparar = previo && !hayFiltros;
    return {
      ...actual,
      deltaTotal: comparar ? delta(actual.total, Number(previo.totalVentas)) : null,
      deltaVentas: comparar ? delta(actual.n, Number(previo.totalTransacciones)) : null,
      deltaTicket: comparar ? delta(actual.ticket, Number(previo.ticketPromedio)) : null,
      deltaVolumen: comparar ? delta(actual.volumen, Number(previo.totalVolumen)) : null,
    };
  }, [base, previo, hayFiltros]);

  const horas = useMemo(() => {
    let min = 24;
    let max = -1;
    for (const v of ventas) {
      if (v.hora < min) min = v.hora;
      if (v.hora > max) max = v.hora;
    }
    if (max < 0) return { desde: 6, hasta: 21 };
    return { desde: Math.max(0, min - 1), hasta: Math.min(23, max + 1) };
  }, [ventas]);

  const mapa = useMemo(() => {
    const grid = Array.from({ length: 7 }, () =>
      Array.from({ length: 24 }, () => ({ total: 0, n: 0 }))
    );
    for (const v of vista("celda")) {
      const celda = grid[v.dow][v.hora];
      celda.total += v.total;
      celda.n += 1;
    }
    let max = 0;
    for (const fila of grid)
      for (const c of fila) max = Math.max(max, metricaMapa === "total" ? c.total : c.n);
    return { grid, max };
  }, [vista, metricaMapa]);

  const porCanal = useMemo(() => {
    const filas = CANALES.map((c) => ({ ...c, total: 0, n: 0 }));
    for (const v of vista("canal")) {
      const fila = filas.find((c) => c.key === v.canal);
      if (fila) {
        fila.total += v.total;
        fila.n += 1;
      }
    }
    return filas;
  }, [vista]);

  const porVendedor = useMemo(
    () =>
      agrupar(
        vista("vendedor").filter((v) => v.canal === "Vendedor" && v.vendedor),
        (v) => v.vendedor
      ),
    [vista]
  );

  const porDia = useMemo(() => {
    const dias = new Map();
    for (const v of vista("dia")) {
      if (!dias.has(v.dia)) {
        dias.set(v.dia, { dia: v.dia, Autoservicio: 0, Vendedor: 0, Tradicional: 0 });
      }
      dias.get(v.dia)[v.canal] += v.total;
    }
    return [...dias.values()].sort((a, b) => a.dia.localeCompare(b.dia));
  }, [vista]);

  const porProducto = useMemo(
    () => agrupar(vista("producto"), (v) => v.producto || "Sin producto", true),
    [vista]
  );

  const porPago = useMemo(() => {
    const mapaPagos = new Map();
    for (const v of vista("pago")) {
      for (const f of v.formasPago) {
        const actual = mapaPagos.get(f.nombre) || { nombre: f.nombre, total: 0, n: 0 };
        actual.total += f.valor;
        actual.n += 1;
        mapaPagos.set(f.nombre, actual);
      }
    }
    return [...mapaPagos.values()].sort((a, b) => b.total - a.total);
  }, [vista]);

  const filasTabla = useMemo(() => {
    const texto = busqueda.trim().toLowerCase();
    const lista = texto
      ? base.filter((v) =>
          [v.idVenta, v.vendedor, v.cuenta, v.empresa, v.placa, v.producto, v.canal]
            .filter(Boolean)
            .join(" ")
            .toLowerCase()
            .includes(texto)
        )
      : base;
    const factor = orden.dir === "asc" ? 1 : -1;
    return [...lista].sort((a, b) => {
      const x = valorOrden(a, orden.key);
      const y = valorOrden(b, orden.key);
      if (x < y) return -1 * factor;
      if (x > y) return 1 * factor;
      return 0;
    });
  }, [base, busqueda, orden]);

  const totalPaginas = Math.max(1, Math.ceil(filasTabla.length / PAGE_SIZE));
  const paginaActual = Math.min(pagina, totalPaginas - 1);
  const filasPagina = filasTabla.slice(
    paginaActual * PAGE_SIZE,
    paginaActual * PAGE_SIZE + PAGE_SIZE
  );

  const detalle = detalleId == null ? null : ventas.find((v) => v.idVenta === detalleId) || null;

  const chips = construirChips(filtros);
  const hintComparacion = hayFiltros ? "Con filtros no se compara" : "Sin periodo anterior para comparar";

  // Deja la vista lista para exportar: pone la fecha de generacion y muestra el encabezado del reporte
  function prepararExportacion() {
    const nodo = capturaRef.current;
    if (!nodo) return null;
    if (generadoRef.current) {
      generadoRef.current.textContent = `Generado el ${new Date().toLocaleString("es-CO")}`;
    }
    nodo.classList.add("is-capture");
    setAvisoExport("");
    return nodo;
  }

  function exportarPdf() {
    const nodo = prepararExportacion();
    if (!nodo) return;
    try {
      imprimirNodo(nodo, `reporte-ventas-${rango.inicio}_${rango.fin}`);
    } catch (err) {
      setAvisoExport(err.message || "No fue posible abrir el PDF.");
    } finally {
      nodo.classList.remove("is-capture");
    }
  }

  async function exportarJpg() {
    const nodo = prepararExportacion();
    if (!nodo) return;
    setExportando("jpg");
    try {
      const blob = await nodoAJpg(nodo);
      setVistaPrevia({
        url: URL.createObjectURL(blob),
        nombre: `reporte-ventas-${rango.inicio}_${rango.fin}.jpg`,
        tamano: blob.size,
      });
    } catch (err) {
      setAvisoExport(err.message || "No fue posible exportar la imagen.");
    } finally {
      nodo.classList.remove("is-capture");
      setExportando("");
    }
  }

  function ordenarPor(key) {
    setOrden((actual) =>
      actual.key === key
        ? { key, dir: actual.dir === "asc" ? "desc" : "asc" }
        : { key, dir: key === "fecha" || key === "total" || key === "volumen" ? "desc" : "asc" }
    );
  }

  return (
    <div style={styles.wrap}>
      <section style={styles.header}>
        <div>
          <h3 style={styles.title}>Reportes</h3>
          <p style={styles.subtitle}>
            Toca cualquier barra, celda o canal para filtrar todo el tablero.
          </p>
        </div>
        <div style={styles.rangeBox}>
          <div className="rpt-presets">
            {PRESETS.map((p) => (
              <button
                key={p.key}
                type="button"
                className={`rpt-preset${preset === p.key ? " is-on" : ""}`}
                onClick={() => aplicarPreset(p.key)}
              >
                {p.label}
              </button>
            ))}
          </div>
          <div style={styles.dates}>
            <input
              type="date"
              style={styles.dateInput}
              value={rango.inicio}
              max={rango.fin}
              onChange={(event) => cambiarFecha("inicio", event.target.value)}
            />
            <span style={styles.dateSep}>a</span>
            <input
              type="date"
              style={styles.dateInput}
              value={rango.fin}
              min={rango.inicio}
              onChange={(event) => cambiarFecha("fin", event.target.value)}
            />
            <button type="button" style={styles.refreshBtn} onClick={cargar} disabled={cargando}>
              {cargando ? "Cargando..." : "Actualizar"}
            </button>
            <button type="button" style={styles.refreshBtn} onClick={exportarPdf} disabled={cargando}>
              Exportar PDF
            </button>
            <button
              type="button"
              style={styles.refreshBtn}
              onClick={exportarJpg}
              disabled={cargando || exportando === "jpg"}
            >
              {exportando === "jpg" ? "Generando..." : "Exportar imagen"}
            </button>
          </div>
        </div>
      </section>

      {error && (
        <div style={styles.errorBox}>
          <span>{error}</span>
          <button type="button" style={styles.refreshBtn} onClick={cargar}>
            Reintentar
          </button>
        </div>
      )}

      {datos.truncado && (
        <div style={styles.warnBox}>
          Hay más ventas en el rango de las que se muestran. Se cargaron las más recientes; reduce el rango para ver todo.
        </div>
      )}

      {avisoExport && <div style={styles.warnBox}>{avisoExport}</div>}

      <div ref={capturaRef} className="rpt-captura" style={styles.wrap}>
      <div className="rpt-print-head">
        <h2>Reporte de ventas · Autoservicio</h2>
        <p>
          Del {formatReadableDate(rango.inicio)} al {formatReadableDate(rango.fin)}
          {" · "}
          <span ref={generadoRef} />
        </p>
      </div>

      <section className="rpt-chipbar">
        <span style={styles.chipLead}>
          {hayFiltros ? "Filtros activos" : "Sin filtros: mostrando todo el rango"}
        </span>
        {chips.map((chip) => (
          <button
            key={chip.clave}
            type="button"
            className="rpt-chip"
            onClick={() => alternar(chip.clave, filtros[chip.clave])}
            title="Quitar este filtro"
          >
            {chip.texto}
            <span aria-hidden="true">×</span>
          </button>
        ))}
        {hayFiltros && (
          <button type="button" className="rpt-chip-clear" onClick={limpiar}>
            Limpiar todo
          </button>
        )}
      </section>

      <section className="rpt-kpis">
        <Kpi label="Ventas" value={formatCurrency(kpis.total)} delta={kpis.deltaTotal} hint={hintComparacion} tone="blue" />
        <Kpi label="Transacciones" value={formatInteger(kpis.n)} delta={kpis.deltaVentas} hint={hintComparacion} tone="slate" />
        <Kpi label="Ticket promedio" value={formatCurrency(kpis.ticket)} delta={kpis.deltaTicket} hint={hintComparacion} tone="green" />
        <Kpi label="Volumen" value={formatVolume(kpis.volumen)} delta={kpis.deltaVolumen} hint={hintComparacion} tone="amber" />
        <Kpi
          label="Peso autoservicio"
          value={formatPercent(
            kpis.total > 0
              ? (base.filter((v) => v.canal === "Autoservicio").reduce((s, v) => s + v.total, 0) /
                  kpis.total) *
                  100
              : 0
          )}
          hint="del total filtrado"
          tone="blue"
        />
      </section>

      <section className="rpt-grid-2">
        <Card
          title="¿Cuándo se vende?"
          subtitle="Día de la semana y hora. Toca una celda para ver solo esa franja."
          aside={
            <div className="rpt-seg">
              <button
                type="button"
                className={metricaMapa === "total" ? "is-on" : ""}
                onClick={() => setMetricaMapa("total")}
              >
                Ventas $
              </button>
              <button
                type="button"
                className={metricaMapa === "n" ? "is-on" : ""}
                onClick={() => setMetricaMapa("n")}
              >
                Transacciones
              </button>
            </div>
          }
        >
          <Heatmap
            mapa={mapa}
            horas={horas}
            metrica={metricaMapa}
            seleccion={filtros.celda}
            onSelect={(celda) => alternar("celda", celda)}
          />
        </Card>

        <Card title="Por canal" subtitle="Quién vendió: autoservicio, vendedor de paso o la isla.">
          <CanalPanel filas={porCanal} seleccion={filtros.canal} onSelect={(k) => alternar("canal", k)} />
          <div style={styles.subBlock}>
            <p style={styles.subTitle}>Vendedores de paso</p>
            <BarList
              filas={porVendedor.map((f) => ({
                clave: f.nombre,
                etiqueta: f.nombre,
                valor: f.total,
                detalle: textoVentas(f.n),
              }))}
              seleccion={filtros.vendedor}
              color={CANAL_COLOR.Vendedor}
              vacio="Sin ventas de vendedores en este filtro."
              onSelect={(k) => alternar("vendedor", k)}
            />
          </div>
        </Card>
      </section>

      <Card title="Ventas por día" subtitle="Cada barra es un día, repartido por canal. Toca un día para filtrar.">
        <DiarioChart dias={porDia} seleccion={filtros.dia} onSelect={(d) => alternar("dia", d)} />
      </Card>

      <section className="rpt-grid-eq">
        <Card title="Productos" subtitle="Toca para filtrar por combustible.">
          <BarList
            filas={porProducto.map((f) => ({
              clave: f.nombre,
              etiqueta: f.nombre,
              valor: f.total,
              detalle: formatVolume(f.volumen),
            }))}
            seleccion={filtros.producto}
            color="#2970ff"
            vacio="Sin ventas en este filtro."
            onSelect={(k) => alternar("producto", k)}
          />
        </Card>
        <Card title="Formas de pago" subtitle="Cómo pagaron, incluyendo efectivo y cuenta.">
          <BarList
            filas={porPago.map((f) => ({
              clave: f.nombre,
              etiqueta: f.nombre,
              valor: f.total,
              detalle: textoVentas(f.n),
            }))}
            seleccion={filtros.pago}
            color="#247656"
            vacio="Sin ventas en este filtro."
            onSelect={(k) => alternar("pago", k)}
          />
        </Card>
      </section>
      </div>

      {/* El listado de ventas queda fuera de lo exportado (PDF e imagen): seria muy largo; para todas las filas esta el CSV */}
      <Card
        title="Ventas"
        subtitle={`${formatInteger(filasTabla.length)} ${filasTabla.length === 1 ? "venta" : "ventas"} con los filtros actuales. Toca una fila para ver el detalle.`}
        aside={
          <div style={styles.tableTools} className="rpt-no-export">
            <input
              type="search"
              style={styles.search}
              placeholder="Buscar venta, vendedor, placa..."
              value={busqueda}
              onChange={(event) => {
                setBusqueda(event.target.value);
                setPagina(0);
              }}
            />
            <button
              type="button"
              style={styles.exportBtn}
              disabled={filasTabla.length === 0}
              onClick={() => exportarCsv(filasTabla, rango)}
            >
              Exportar CSV
            </button>
          </div>
        }
      >
        <VentasTable
          filas={filasPagina}
          orden={orden}
          onSort={ordenarPor}
          onOpen={(v) => setDetalleId(v.idVenta)}
          seleccionada={detalleId}
        />
        <div className="rpt-pager rpt-no-export">
          <span>
            Página {paginaActual + 1} de {totalPaginas}
          </span>
          <div>
            <button type="button" disabled={paginaActual === 0} onClick={() => setPagina(paginaActual - 1)}>
              Anterior
            </button>
            <button
              type="button"
              disabled={paginaActual >= totalPaginas - 1}
              onClick={() => setPagina(paginaActual + 1)}
            >
              Siguiente
            </button>
          </div>
        </div>
      </Card>

      {detalle && <DetalleVenta venta={detalle} onClose={() => setDetalleId(null)} />}

      {vistaPrevia && <VistaPreviaImagen imagen={vistaPrevia} onClose={() => setVistaPrevia(null)} />}
    </div>
  );
}

/* ------------------------------ Componentes ------------------------------ */

function Card({ title, subtitle, aside, children }) {
  return (
    <article className="rpt-card">
      <header className="rpt-card-head">
        <div>
          <h4 style={styles.cardTitle}>{title}</h4>
          {subtitle && <p style={styles.cardSub}>{subtitle}</p>}
        </div>
        {aside}
      </header>
      {children}
    </article>
  );
}

function Kpi({ label, value, delta: cambio, hint, tone }) {
  const colores = { blue: "#2970ff", slate: "#49576b", green: "#247656", amber: "#de8b1c" };
  return (
    <div className="rpt-kpi" style={{ "--kpi": colores[tone] || colores.blue }}>
      <p className="rpt-kpi-label">{label}</p>
      <p className="rpt-kpi-value">{value}</p>
      {cambio !== undefined && cambio !== null ? (
        <p className={`rpt-kpi-delta ${cambio >= 0 ? "up" : "down"}`}>
          {cambio >= 0 ? "▲" : "▼"} {Math.abs(cambio).toFixed(1)}% <span>vs periodo anterior</span>
        </p>
      ) : (
        <p className="rpt-kpi-delta flat">{hint || "Sin periodo anterior para comparar"}</p>
      )}
    </div>
  );
}

function Heatmap({ mapa, horas, metrica, seleccion, onSelect }) {
  const [hover, setHover] = useState(null);
  const columnas = [];
  for (let h = horas.desde; h <= horas.hasta; h += 1) columnas.push(h);

  const textoHover = hover
    ? `${DIAS[hover.dow]} ${String(hover.hora).padStart(2, "0")}:00 — ${formatCurrency(
        mapa.grid[hover.dow][hover.hora].total
      )} · ${formatInteger(mapa.grid[hover.dow][hover.hora].n)} ventas`
    : "Pasa el cursor por una celda para ver el detalle.";

  return (
    <div>
      <p className="rpt-heat-info">{textoHover}</p>
      <div className="rpt-heat" style={{ "--cols": columnas.length }}>
        <span />
        {columnas.map((h) => (
          <span key={`h${h}`} className="rpt-heat-hour">
            {h}
          </span>
        ))}
        {DIAS.map((dia, dow) => (
          <HeatRow
            key={dia}
            dia={dia}
            dow={dow}
            columnas={columnas}
            mapa={mapa}
            metrica={metrica}
            seleccion={seleccion}
            onSelect={onSelect}
            setHover={setHover}
          />
        ))}
      </div>
      <div className="rpt-heat-legend">
        <span>Menos</span>
        <i />
        <span>Más</span>
      </div>
    </div>
  );
}

function HeatRow({ dia, dow, columnas, mapa, metrica, seleccion, onSelect, setHover }) {
  return (
    <>
      <span className="rpt-heat-day">{dia}</span>
      {columnas.map((hora) => {
        const celda = mapa.grid[dow][hora];
        const valor = metrica === "total" ? celda.total : celda.n;
        const ratio = mapa.max > 0 ? valor / mapa.max : 0;
        const activa = seleccion && seleccion.dow === dow && seleccion.hora === hora;
        return (
          <button
            key={`${dow}-${hora}`}
            type="button"
            className={`rpt-heat-cell${activa ? " is-selected" : ""}${valor === 0 ? " is-empty" : ""}`}
            style={
              valor === 0
                ? undefined
                : {
                    background: `rgba(41,112,255,${(0.14 + 0.86 * ratio).toFixed(3)})`,
                    color: ratio > 0.55 ? "#fff" : "var(--text-primary)",
                  }
            }
            aria-label={`${dia} ${hora}:00, ${celda.n} ventas`}
            onMouseEnter={() => setHover({ dow, hora })}
            onMouseLeave={() => setHover(null)}
            onFocus={() => setHover({ dow, hora })}
            onBlur={() => setHover(null)}
            onClick={() => onSelect({ dow, hora })}
          >
            {celda.n > 0 ? celda.n : ""}
          </button>
        );
      })}
    </>
  );
}

function CanalPanel({ filas, seleccion, onSelect }) {
  const total = filas.reduce((suma, f) => suma + f.total, 0);

  return (
    <div>
      <div className="rpt-stack" role="group" aria-label="Reparto por canal">
        {total === 0 ? (
          <span className="rpt-stack-empty">Sin ventas</span>
        ) : (
          filas
            .filter((f) => f.total > 0)
            .map((f) => (
              <button
                key={f.key}
                type="button"
                className={`rpt-stack-seg${seleccion && seleccion !== f.key ? " is-dim" : ""}`}
                style={{ width: `${(f.total / total) * 100}%`, background: f.color }}
                title={`${f.label}: ${formatCurrency(f.total)}`}
                onClick={() => onSelect(f.key)}
              />
            ))
        )}
      </div>
      <div className="rpt-canal-list">
        {filas.map((f) => (
          <button
            key={f.key}
            type="button"
            className={`rpt-canal-row${seleccion === f.key ? " is-on" : ""}${seleccion && seleccion !== f.key ? " is-dim" : ""}`}
            onClick={() => onSelect(f.key)}
          >
            <i style={{ background: f.color }} />
            <span className="rpt-canal-name">{f.label}</span>
            <span className="rpt-canal-n">{textoVentas(f.n)}</span>
            <strong>{formatCurrency(f.total)}</strong>
            <span className="rpt-canal-pct">{formatPercent(total > 0 ? (f.total / total) * 100 : 0)}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function BarList({ filas, seleccion, color, vacio, onSelect }) {
  const max = filas.reduce((m, f) => Math.max(m, f.valor), 0);

  if (filas.length === 0) return <p className="rpt-empty">{vacio}</p>;

  return (
    <div className="rpt-bars">
      {filas.map((f) => (
        <button
          key={f.clave}
          type="button"
          className={`rpt-bar${seleccion === f.clave ? " is-on" : ""}${seleccion && seleccion !== f.clave ? " is-dim" : ""}`}
          onClick={() => onSelect(f.clave)}
        >
          <span className="rpt-bar-top">
            <span className="rpt-bar-name">{f.etiqueta}</span>
            <strong>{formatCurrency(f.valor)}</strong>
          </span>
          <span className="rpt-bar-track">
            <span style={{ width: `${max > 0 ? (f.valor / max) * 100 : 0}%`, background: color }} />
          </span>
          <span className="rpt-bar-detail">{f.detalle}</span>
        </button>
      ))}
    </div>
  );
}

function DiarioChart({ dias, seleccion, onSelect }) {
  const [hover, setHover] = useState(null);
  const max = dias.reduce((m, d) => Math.max(m, d.Autoservicio + d.Vendedor + d.Tradicional), 0);

  if (dias.length === 0) return <p className="rpt-empty">Sin ventas en este filtro.</p>;

  const info = hover
    ? `${formatDiaLargo(hover.dia)} — ${formatCurrency(hover.Autoservicio + hover.Vendedor + hover.Tradicional)}`
    : "Pasa el cursor por un día.";

  return (
    <div>
      <p className="rpt-heat-info">{info}</p>
      <div className="rpt-days">
        {dias.map((d, indice) => {
          const total = d.Autoservicio + d.Vendedor + d.Tradicional;
          const mostrarEtiqueta = indice % Math.ceil(dias.length / 10) === 0;
          return (
            <button
              key={d.dia}
              type="button"
              className={`rpt-day${seleccion === d.dia ? " is-on" : ""}${seleccion && seleccion !== d.dia ? " is-dim" : ""}`}
              onMouseEnter={() => setHover(d)}
              onMouseLeave={() => setHover(null)}
              onFocus={() => setHover(d)}
              onBlur={() => setHover(null)}
              onClick={() => onSelect(d.dia)}
              aria-label={`${formatDiaLargo(d.dia)}: ${formatCurrency(total)}`}
            >
              <span className="rpt-day-stack" style={{ height: `${max > 0 ? (total / max) * 100 : 0}%` }}>
                {CANALES.map((c) =>
                  d[c.key] > 0 ? (
                    <i key={c.key} style={{ flexGrow: d[c.key], background: c.color }} />
                  ) : null
                )}
              </span>
              <span className="rpt-day-label">{mostrarEtiqueta ? `${d.dia.slice(8)}/${d.dia.slice(5, 7)}` : ""}</span>
            </button>
          );
        })}
      </div>
      <div className="rpt-legend">
        {CANALES.map((c) => (
          <span key={c.key}>
            <i style={{ background: c.color }} />
            {c.label}
          </span>
        ))}
      </div>
    </div>
  );
}

function VentasTable({ filas, orden, onSort, onOpen, seleccionada }) {
  const columnas = [
    { key: "fecha", label: "Fecha y hora" },
    { key: "canal", label: "Canal" },
    { key: "quien", label: "Vendedor / cliente" },
    { key: "producto", label: "Producto" },
    { key: "volumen", label: "Volumen", alinear: "right" },
    { key: "total", label: "Total", alinear: "right" },
    { key: "pago", label: "Pago" },
  ];

  return (
    <div className="rpt-table-wrap">
      <table className="rpt-table">
        <thead>
          <tr>
            {columnas.map((c) => (
              <th key={c.key} style={{ textAlign: c.alinear || "left" }}>
                <button type="button" onClick={() => onSort(c.key)}>
                  {c.label}
                  {orden.key === c.key ? (orden.dir === "asc" ? " ▲" : " ▼") : ""}
                </button>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {filas.length === 0 && (
            <tr>
              <td colSpan={columnas.length} className="rpt-empty-row">
                No hay ventas con los filtros actuales.
              </td>
            </tr>
          )}
          {filas.map((v) => (
            <tr
              key={v.idVenta}
              className={seleccionada === v.idVenta ? "is-on" : ""}
              tabIndex={0}
              onClick={() => onOpen(v)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault();
                  onOpen(v);
                }
              }}
            >
              <td>
                <strong>{formatHora(v.fecha)}</strong>
                <small>{formatDiaCorto(v.dia)}</small>
              </td>
              <td>
                <span className="rpt-canal-pill" style={{ "--c": CANAL_COLOR[v.canal] }}>
                  {CANAL_LABEL[v.canal]}
                </span>
              </td>
              <td>
                <strong>{v.vendedor && v.canal === "Vendedor" ? v.vendedor : v.empresa || v.cuenta || "—"}</strong>
                <small>
                  {v.placa ? `Placa ${v.placa}` : v.canal === "Vendedor" ? "Vendedor de paso" : `Venta #${v.idVenta}`}
                </small>
              </td>
              <td>{v.producto || "—"}</td>
              <td style={{ textAlign: "right" }}>{formatVolume(v.volumen)}</td>
              <td style={{ textAlign: "right" }}>
                <strong>{formatCurrency(v.total)}</strong>
              </td>
              <td>
                {resumenPagos(v)}
                {v.fidelizada && <span className="rpt-fiel" title="Venta fidelizada">★</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function VistaPreviaImagen({ imagen, onClose }) {
  useEffect(() => {
    function alTeclear(event) {
      if (event.key === "Escape") onClose();
    }
    window.addEventListener("keydown", alTeclear);
    return () => window.removeEventListener("keydown", alTeclear);
  }, [onClose]);

  // Libera la imagen en memoria al cerrar
  useEffect(() => {
    const url = imagen.url;
    return () => URL.revokeObjectURL(url);
  }, [imagen.url]);

  // Se monta en <body> por la misma razon que el panel de detalle
  return createPortal(
    <div className="rpt-modal-wrap" role="dialog" aria-label="Vista previa de la imagen">
      <div className="rpt-overlay" onClick={onClose} />
      <div className="rpt-modal">
        <header className="rpt-modal-head">
          <div>
            <h4>Vista previa de la imagen</h4>
            <p>
              {imagen.nombre} · JPG · {formatTamano(imagen.tamano)}
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Cerrar">
            ×
          </button>
        </header>
        <div className="rpt-modal-body">
          <img src={imagen.url} alt="Vista previa del reporte exportado" />
        </div>
        <footer className="rpt-modal-foot">
          <button type="button" className="rpt-modal-cancel" onClick={onClose}>
            Cerrar
          </button>
          <a className="rpt-modal-download" href={imagen.url} download={imagen.nombre}>
            Descargar JPG
          </a>
        </footer>
      </div>
    </div>,
    document.body
  );
}

function formatTamano(bytes) {
  if (!bytes) return "--";
  return bytes > 1048576
    ? `${(bytes / 1048576).toFixed(1).replace(".", ",")} MB`
    : `${Math.round(bytes / 1024)} KB`;
}

function DetalleVenta({ venta, onClose }) {
  useEffect(() => {
    function alTeclear(event) {
      if (event.key === "Escape") onClose();
    }
    window.addEventListener("keydown", alTeclear);
    return () => window.removeEventListener("keydown", alTeclear);
  }, [onClose]);

  const pagos = venta.formasPago;
  const maxPago = pagos.reduce((m, f) => Math.max(m, f.valor), 0);

  // Se monta en <body>: dentro del marco de la pagina (que tiene desenfoque) "fixed" se calcularia respecto al marco, no a la ventana
  return createPortal(
    <>
      <div className="rpt-overlay" onClick={onClose} />
      <aside className="rpt-drawer" role="dialog" aria-label={`Detalle de la venta ${venta.idVenta}`}>
        <header className="rpt-drawer-head">
          <div>
            <p className="rpt-drawer-eyebrow">Venta #{venta.idVenta}</p>
            <h4>{formatCurrency(venta.total)}</h4>
            <p className="rpt-drawer-date">{capitalizar(formatFechaCompleta(venta.fecha))}</p>
          </div>
          <button type="button" onClick={onClose} aria-label="Cerrar">
            ×
          </button>
        </header>

        <div className="rpt-drawer-body">
          <span className="rpt-canal-pill big" style={{ "--c": CANAL_COLOR[venta.canal] }}>
            {CANAL_LABEL[venta.canal]}
          </span>

          <dl className="rpt-dl">
            <div>
              <dt>Producto</dt>
              <dd>{venta.producto || "—"}</dd>
            </div>
            <div>
              <dt>Volumen</dt>
              <dd>{formatVolume(venta.volumen)}</dd>
            </div>
            <div>
              <dt>Dispensador</dt>
              <dd>
                {venta.idDispensador} · posición {venta.idPosicion}
              </dd>
            </div>
            <div>
              <dt>Tipo de transacción</dt>
              <dd>{TIPOS_TRANSACCION[venta.tipoTransaccion] || `Tipo ${venta.tipoTransaccion}`}</dd>
            </div>
            {venta.vendedor && (
              <div>
                <dt>Turno de</dt>
                <dd>{venta.vendedor}</dd>
              </div>
            )}
          </dl>

          {(venta.cuenta || venta.placa) && (
            <section>
              <h5>Cliente</h5>
              <dl className="rpt-dl">
                {venta.empresa && (
                  <div>
                    <dt>Empresa</dt>
                    <dd>{venta.empresa}</dd>
                  </div>
                )}
                {venta.cuenta && (
                  <div>
                    <dt>Cuenta</dt>
                    <dd>{venta.cuenta}</dd>
                  </div>
                )}
                {venta.placa && (
                  <div>
                    <dt>Placa</dt>
                    <dd>{venta.placa}</dd>
                  </div>
                )}
              </dl>
            </section>
          )}

          <section>
            <h5>Cómo pagó</h5>
            {pagos.length === 0 ? (
              <p className="rpt-empty">Sin formas de pago registradas.</p>
            ) : (
              <div className="rpt-bars">
                {pagos.map((f) => (
                  <div key={f.nombre} className="rpt-bar static">
                    <span className="rpt-bar-top">
                      <span className="rpt-bar-name">{f.nombre}</span>
                      <strong>{formatCurrency(f.valor)}</strong>
                    </span>
                    <span className="rpt-bar-track">
                      <span style={{ width: `${maxPago > 0 ? (f.valor / maxPago) * 100 : 0}%`, background: "#247656" }} />
                    </span>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section>
            <h5>Fidelidad</h5>
            {venta.fidelizada ? (
              <p className="rpt-fiel-box">
                ★ Acumuló puntos{venta.programa ? ` en ${venta.programa}` : ""}.
              </p>
            ) : (
              <p className="rpt-empty">Esta venta no se fidelizó.</p>
            )}
          </section>
        </div>
      </aside>
    </>,
    document.body
  );
}

/* -------------------------------- Lógica --------------------------------- */

function prepararVenta(venta) {
  const fecha = new Date(venta.fecha);
  return {
    ...venta,
    formasPago: venta.formasPago ?? [],
    dia: formatDateInput(fecha),
    hora: fecha.getHours(),
    dow: (fecha.getDay() + 6) % 7, // lunes = 0
  };
}

function cumple(venta, filtros, excluir) {
  if (excluir !== "canal" && filtros.canal && venta.canal !== filtros.canal) return false;
  if (excluir !== "vendedor" && filtros.vendedor && venta.vendedor !== filtros.vendedor) return false;
  if (excluir !== "producto" && filtros.producto && (venta.producto || "Sin producto") !== filtros.producto)
    return false;
  if (excluir !== "pago" && filtros.pago && !venta.formasPago.some((f) => f.nombre === filtros.pago))
    return false;
  if (excluir !== "dia" && filtros.dia && venta.dia !== filtros.dia) return false;
  if (
    excluir !== "celda" &&
    filtros.celda &&
    (venta.dow !== filtros.celda.dow || venta.hora !== filtros.celda.hora)
  )
    return false;
  return true;
}

function sonIguales(a, b) {
  if (a && b && typeof a === "object" && typeof b === "object") {
    return a.dow === b.dow && a.hora === b.hora;
  }
  return a === b;
}

function resumen(ventas) {
  const total = ventas.reduce((s, v) => s + v.total, 0);
  const volumen = ventas.reduce((s, v) => s + v.volumen, 0);
  return { total, volumen, n: ventas.length, ticket: ventas.length ? total / ventas.length : 0 };
}

function delta(actual, previo) {
  if (!previo) return null;
  return ((actual - previo) / previo) * 100;
}

function agrupar(ventas, clave, conVolumen = false) {
  const grupos = new Map();
  for (const v of ventas) {
    const nombre = clave(v);
    const actual = grupos.get(nombre) || { nombre, total: 0, n: 0, volumen: 0 };
    actual.total += v.total;
    actual.n += 1;
    if (conVolumen) actual.volumen += v.volumen;
    grupos.set(nombre, actual);
  }
  return [...grupos.values()].sort((a, b) => b.total - a.total);
}

function construirChips(filtros) {
  const chips = [];
  if (filtros.canal) chips.push({ clave: "canal", texto: `Canal: ${CANAL_LABEL[filtros.canal]}` });
  if (filtros.vendedor) chips.push({ clave: "vendedor", texto: `Vendedor: ${filtros.vendedor}` });
  if (filtros.producto) chips.push({ clave: "producto", texto: `Producto: ${filtros.producto}` });
  if (filtros.pago) chips.push({ clave: "pago", texto: `Pago: ${filtros.pago}` });
  if (filtros.dia) chips.push({ clave: "dia", texto: `Día: ${formatDiaLargo(filtros.dia)}` });
  if (filtros.celda)
    chips.push({
      clave: "celda",
      texto: `${DIAS[filtros.celda.dow]} ${String(filtros.celda.hora).padStart(2, "0")}:00`,
    });
  return chips;
}

function valorOrden(venta, key) {
  switch (key) {
    case "fecha":
      return venta.fecha;
    case "canal":
      return venta.canal;
    case "quien":
      return (venta.vendedor || venta.empresa || venta.cuenta || "").toLowerCase();
    case "producto":
      return (venta.producto || "").toLowerCase();
    case "volumen":
      return venta.volumen;
    case "total":
      return venta.total;
    case "pago":
      return resumenPagos(venta).toLowerCase();
    default:
      return 0;
  }
}

function resumenPagos(venta) {
  if (venta.formasPago.length === 0) return "—";
  if (venta.formasPago.length === 1) return venta.formasPago[0].nombre;
  return `${venta.formasPago[0].nombre} +${venta.formasPago.length - 1}`;
}

function exportarCsv(ventas, rango) {
  const columnas = [
    "Venta", "Fecha", "Canal", "Vendedor", "Empresa", "Cuenta", "Placa", "Producto",
    "Volumen", "Total", "Formas de pago", "Fidelizada", "Programa", "Dispensador", "Posicion",
  ];
  const escapar = (valor) => `"${String(valor ?? "").replace(/"/g, '""')}"`;
  const filas = ventas.map((v) =>
    [
      v.idVenta,
      formatFechaCompleta(v.fecha),
      CANAL_LABEL[v.canal],
      v.vendedor,
      v.empresa,
      v.cuenta,
      v.placa,
      v.producto,
      v.volumen,
      v.total,
      v.formasPago.map((f) => `${f.nombre}: ${f.valor}`).join(" | "),
      v.fidelizada ? "Si" : "No",
      v.programa,
      v.idDispensador,
      v.idPosicion,
    ]
      .map(escapar)
      .join(";")
  );
  const bom = String.fromCharCode(0xfeff);
  const contenido = bom + [columnas.map(escapar).join(";"), ...filas].join("\r\n");
  const url = URL.createObjectURL(new Blob([contenido], { type: "text/csv;charset=utf-8" }));
  const enlace = document.createElement("a");
  enlace.href = url;
  enlace.download = `ventas-${rango.inicio}_${rango.fin}.csv`;
  enlace.click();
  URL.revokeObjectURL(url);
}

function rangoAnterior(inicio, fin) {
  const desde = new Date(`${inicio}T00:00:00`);
  const hasta = new Date(`${fin}T00:00:00`);
  const dias = Math.round((hasta - desde) / 86400000) + 1;
  const finPrevio = new Date(desde);
  finPrevio.setDate(finPrevio.getDate() - 1);
  const inicioPrevio = new Date(finPrevio);
  inicioPrevio.setDate(inicioPrevio.getDate() - (dias - 1));
  return { inicio: formatDateInput(inicioPrevio), fin: formatDateInput(finPrevio) };
}

/* ------------------------------- Formatos -------------------------------- */

function formatDateInput(date) {
  const mes = `${date.getMonth() + 1}`.padStart(2, "0");
  const dia = `${date.getDate()}`.padStart(2, "0");
  return `${date.getFullYear()}-${mes}-${dia}`;
}

function formatReadableDate(value) {
  const [anio, mes, dia] = String(value || "").split("-");
  return dia ? `${dia}/${mes}/${anio}` : "--";
}

function formatCurrency(value) {
  return new Intl.NumberFormat("es-CO", {
    style: "currency",
    currency: "COP",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));
}

function formatInteger(value) {
  return new Intl.NumberFormat("es-CO").format(Number(value || 0));
}

function formatVolume(value) {
  return `${new Intl.NumberFormat("es-CO", { maximumFractionDigits: 2 }).format(Number(value || 0))} G`;
}

function formatPercent(value) {
  return `${new Intl.NumberFormat("es-CO", { maximumFractionDigits: 1 }).format(Number(value || 0))}%`;
}

function capitalizar(texto) {
  return texto ? texto.charAt(0).toUpperCase() + texto.slice(1) : texto;
}

function textoVentas(n) {
  return `${formatInteger(n)} ${n === 1 ? "venta" : "ventas"}`;
}

function formatHora(fecha) {
  return new Date(fecha).toLocaleTimeString("es-CO", { hour: "2-digit", minute: "2-digit" });
}

function formatDiaCorto(dia) {
  return new Date(`${dia}T00:00:00`).toLocaleDateString("es-CO", { day: "2-digit", month: "short" });
}

function formatDiaLargo(dia) {
  return new Date(`${dia}T00:00:00`).toLocaleDateString("es-CO", {
    weekday: "short",
    day: "2-digit",
    month: "short",
  });
}

function formatFechaCompleta(fecha) {
  return new Date(fecha).toLocaleString("es-CO", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

const styles = {
  wrap: { display: "grid", gap: 20 },
  header: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-end",
    gap: 20,
    flexWrap: "wrap",
  },
  title: { fontSize: 28, color: "var(--text-primary)" },
  subtitle: { marginTop: 4, fontSize: 14, color: "var(--text-secondary)" },
  rangeBox: { display: "grid", gap: 10, justifyItems: "end" },
  dates: { display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" },
  dateInput: {
    padding: "10px 12px",
    borderRadius: 12,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    color: "var(--text-primary)",
    fontSize: 13,
  },
  dateSep: { fontSize: 13, color: "var(--text-muted)" },
  refreshBtn: {
    padding: "10px 16px",
    borderRadius: 12,
    border: "1px solid rgba(41,112,255,0.18)",
    background: "var(--accent-dim)",
    color: "var(--accent-strong)",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  errorBox: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    gap: 12,
    padding: "12px 16px",
    borderRadius: 14,
    background: "rgba(217,64,64,0.08)",
    border: "1px solid rgba(217,64,64,0.2)",
    color: "var(--danger)",
    fontSize: 13,
    fontWeight: 600,
  },
  warnBox: {
    padding: "12px 16px",
    borderRadius: 14,
    background: "rgba(222,139,28,0.1)",
    border: "1px solid rgba(222,139,28,0.22)",
    color: "#8a5410",
    fontSize: 13,
    fontWeight: 600,
  },
  chipLead: { fontSize: 12, fontWeight: 700, color: "var(--text-muted)" },
  cardTitle: { fontSize: 17, color: "var(--text-primary)" },
  cardSub: { marginTop: 3, fontSize: 12.5, color: "var(--text-secondary)" },
  subBlock: { marginTop: 18, paddingTop: 16, borderTop: "1px solid var(--border)" },
  subTitle: { marginBottom: 10, fontSize: 12, fontWeight: 700, color: "var(--text-secondary)" },
  tableTools: { display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" },
  search: {
    width: 280,
    maxWidth: "100%",
    padding: "10px 14px",
    borderRadius: 12,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    fontSize: 13,
    color: "var(--text-primary)",
  },
  exportBtn: {
    padding: "10px 16px",
    borderRadius: 12,
    border: "none",
    background: "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
};
