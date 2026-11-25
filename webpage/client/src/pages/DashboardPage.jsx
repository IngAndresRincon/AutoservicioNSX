import { useEffect, useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useTheme } from '../useTheme.js';
import { apiFetch, logout, getUsuario } from '../api.js';

const MODULES = [
  {
    key: 'autorizaciones',
    label: 'Autorizaciones',
    icon: '📋',
    description: 'Autorizaciones ya pagadas, listas para despachar en el surtidor.',
  },
  {
    key: 'programaciones',
    label: 'Programaciones',
    icon: '🕒',
    description: 'Solicitudes de tanqueo que aún esperan que el cliente complete el pago.',
  },
  {
    key: 'ventas',
    label: 'Ventas',
    icon: '⛽',
    description: 'Despachos de combustible ya completados en el surtidor.',
  },
  {
    key: 'arqueo',
    label: 'Arqueo',
    icon: '🧾',
    description: 'Ventas del turno activo, agrupadas por producto.',
  },
  {
    key: 'transferencia',
    label: 'Transferencia de saldos',
    icon: '🔁',
    description: 'Ventas que dispensaron menos de lo programado: al cliente le queda un saldo pendiente.',
  },
  {
    key: 'reportespagos',
    label: 'Reporte de pagos',
    icon: '💳',
    description: 'Todas las transacciones de pago, con su estado y a quién corresponden.',
  },
  {
    key: 'auditoria',
    label: 'Auditoría',
    icon: '🛡️',
    description: 'Quién hizo qué acción, sobre qué registro y a qué hora — para trazabilidad.',
  },
];

const SOON = [];

const COLUMNS = {
  autorizaciones: [
    { key: 'idautorizacion', label: 'Autorización' },
    { key: 'producto', label: 'Producto' },
    { key: 'programacion', label: 'Programación', money: true },
    { key: 'valorabonado', label: 'Valor abonado', money: true },
    { key: 'precio', label: 'Precio', money: true },
    { key: 'identificador', label: 'Identificador' },
    { key: 'fecharegistro', label: 'Fecha registro' },
  ],
  programaciones: [
    { key: 'idautorizacion', label: 'Programación' },
    { key: 'producto', label: 'Producto' },
    { key: 'programacion', label: 'Solicitado', money: true },
    { key: 'valorabonado', label: 'Abonado', money: true },
    { key: 'valorpendiente', label: 'Pendiente', money: true },
    { key: 'precio', label: 'Precio', money: true },
    { key: 'identificador', label: 'Identificador' },
    { key: 'fecharegistro', label: 'Fecha registro' },
  ],
  ventas: [
    { key: 'idventa', label: 'Venta' },
    { key: 'producto', label: 'Producto' },
    { key: 'programacion', label: 'Programación', money: true },
    { key: 'dinero', label: 'Dinero', money: true },
    { key: 'volumen', label: 'Volumen', suffix: ' G' },
    { key: 'precio', label: 'Precio', money: true },
    { key: 'fechainicial', label: 'Fecha inicial' },
    { key: 'fechafinal', label: 'Fecha final' },
  ],
  auditoria: [
    { key: 'fecharegistro', label: 'Fecha' },
    { key: 'usuario', label: 'Usuario' },
    { key: 'accion', label: 'Acción' },
    { key: 'entidad', label: 'Entidad' },
    { key: 'identidad', label: 'ID' },
    { key: 'detalle', label: 'Detalle' },
  ],
  arqueo: [
    { key: 'producto', label: 'Producto' },
    { key: 'totaldinero', label: 'Total dinero', money: true },
    { key: 'totalvolumen', label: 'Total volumen', suffix: ' G' },
    { key: 'ventas', label: 'Ventas' },
  ],
  transferencia: [
    { key: 'idventa', label: 'Venta' },
    { key: 'producto', label: 'Producto' },
    { key: 'identificador', label: 'Identificador' },
    { key: 'saldo', label: 'Saldo pendiente', money: true },
    { key: 'vueltoEstado', label: 'Vuelto' },
    { key: 'fecharegistro', label: 'Fecha' },
  ],
  reportespagos: [
    { key: 'idpago', label: 'Pago' },
    { key: 'identificador', label: 'Identificador' },
    { key: 'formapago', label: 'Forma de pago' },
    { key: 'estado', label: 'Estado' },
    { key: 'valor', label: 'Valor', money: true },
    { key: 'fecha', label: 'Fecha' },
  ],
};

// Módulos donde el clic en una fila abre el panel de detalle
const DETAIL_ENDPOINT = {
  autorizaciones: 'autorizaciones',
  programaciones: 'programaciones',
  ventas: 'ventas',
};

const DETAIL_TITLE = {
  autorizaciones: 'Autorización',
  programaciones: 'Programación',
  ventas: 'Venta',
};

// Campo de la fila que identifica el registro para pedir su detalle
const ROW_ID_FIELD = {
  autorizaciones: 'idautorizacion',
  programaciones: 'idautorizacion',
  ventas: 'idventa',
};

// Filtros disponibles por módulo: campo de fecha para el rango, y campos de texto para la búsqueda libre
const FILTER_CONFIG = {
  autorizaciones: {
    dateField: 'fecharegistro',
    searchFields: ['idautorizacion', 'identificador', 'producto'],
    searchPlaceholder: 'Buscar por autorización, identificador o producto...',
  },
  programaciones: {
    dateField: 'fecharegistro',
    searchFields: ['idautorizacion', 'identificador', 'producto'],
    searchPlaceholder: 'Buscar por programación, identificador o producto...',
  },
  ventas: {
    dateField: 'fechainicial',
    searchFields: ['idventa', 'idautorizacion', 'producto'],
    searchPlaceholder: 'Buscar por venta, autorización o producto...',
  },
  auditoria: {
    dateField: 'fecharegistro',
    searchFields: ['identidad', 'usuario', 'accion', 'entidad', 'detalle'],
    searchPlaceholder: 'Buscar por autorización, usuario o acción...',
  },
  reportespagos: {
    dateField: 'fecha',
    searchFields: ['idpago', 'identificador', 'formapago', 'estado'],
    searchPlaceholder: 'Buscar por pago, identificador, forma de pago o estado...',
  },
  transferencia: {
    dateField: 'fecharegistro',
    searchFields: ['idventa', 'idventasistema', 'idautorizacion', 'idpresetnsx', 'identificador', 'producto'],
    searchPlaceholder: 'Buscar por venta, preset sistema o identificador...',
  },
};

// YYYY-MM-DD del primer día del mes en curso y de hoy — rango por defecto al entrar a un módulo
function currentMonthRange() {
  const now = new Date();
  const toISO = (d) => d.toISOString().slice(0, 10);
  return {
    from: toISO(new Date(now.getFullYear(), now.getMonth(), 1)),
    to: toISO(now),
  };
}

function FilterBar({ moduleKey, value, onChange }) {
  const config = FILTER_CONFIG[moduleKey];
  if (!config) return null;

  const isDefaultRange = (() => {
    const def = currentMonthRange();
    return value.from === def.from && value.to === def.to;
  })();

  return (
    <div className="filter-bar">
      <input
        className="filter-input"
        type="text"
        placeholder={config.searchPlaceholder}
        value={value.text}
        onChange={(e) => onChange({ ...value, text: e.target.value })}
      />
      <div className="filter-dates">
        <span className="filter-date-field">
          <span className="filter-date-icon">📅</span>
          <span className="filter-date-label">Desde</span>
          <input
            type="date"
            value={value.from}
            onChange={(e) => onChange({ ...value, from: e.target.value })}
          />
        </span>
        <span className="filter-date-sep">→</span>
        <span className="filter-date-field">
          <span className="filter-date-icon">📅</span>
          <span className="filter-date-label">Hasta</span>
          <input
            type="date"
            value={value.to}
            onChange={(e) => onChange({ ...value, to: e.target.value })}
          />
        </span>
        {(value.text || !isDefaultRange) && (
          <button className="btn-ghost" onClick={() => onChange({ text: '', ...currentMonthRange() })}>
            Limpiar
          </button>
        )}
      </div>
    </div>
  );
}

function formatMoney(value) {
  const n = Number(value);
  return Number.isFinite(n) ? `$ ${n.toLocaleString('es-CO')}` : value;
}

// La "programación" puede ser en dinero (tipo_programacion = 2) o en volumen (= 3);
// mostrarla siempre como plata se ve raro cuando en realidad son galones.
function formatProgramacion(value, tipo) {
  const n = Number(value);
  if (!Number.isFinite(n)) return value;
  if (tipo === 3) return `${n.toLocaleString('es-CO', { maximumFractionDigits: 3 })} G`;
  return formatMoney(value);
}

const ACCION_LABELS = {
  anular_autorizacion: { label: 'Anuló autorización', tone: 'danger' },
};

// Columnas que son identificadores: se muestran como "chip" en vez de un número suelto
const ID_COLUMNS = new Set([
  'idautorizacion',
  'idventa',
  'idventasistema',
  'idpresetnsx',
  'idpago',
  'identidad',
]);

function AccionBadge({ accion }) {
  const info = ACCION_LABELS[accion] || { label: accion, tone: 'neutral' };
  return <span className={`badge-accion badge-${info.tone}`}>{info.label}</span>;
}

const ESTADO_PAGO_TONE = {
  Completado: 'success',
  Autorizado: 'success',
  Cancelado: 'danger',
  Anulado: 'danger',
  Pendiente: 'warning',
  Validando: 'warning',
  Leído: 'neutral',
};

function EstadoPagoBadge({ estado }) {
  const tone = ESTADO_PAGO_TONE[estado] || 'neutral';
  return <span className={`badge-accion badge-${tone}`}>{estado}</span>;
}

// Estado real del vuelto, tal como lo entrega el API NSX (Vueltos/ObtenerVueltoByIdProgramacion)
const VUELTO_TONE = {
  Creado: 'warning',
  Reservado: 'warning',
  Usado: 'success',
  Vencido: 'danger',
};

function VueltoBadge({ vuelto }) {
  if (!vuelto) {
    return <span className="badge-accion badge-neutral">Sin vuelto</span>;
  }
  const tone = VUELTO_TONE[vuelto.estado] || 'neutral';
  return <span className={`badge-accion badge-${tone}`}>{vuelto.estado}</span>;
}

function ReimprimirButton({ codigo, onNotify }) {
  const [loading, setLoading] = useState(false);

  async function handleClick(e) {
    e.stopPropagation();
    setLoading(true);
    try {
      const res = await apiFetch(`/api/nsx-autoservice/page/transferencia/${codigo}/reimprimir`, {
        method: 'POST',
      });
      const result = await res.json();
      onNotify(
        result.success ? `Vuelto ${codigo} enviado a imprimir` : result.message || 'No se pudo reimprimir',
        result.success ? 'success' : 'danger'
      );
    } catch {
      onNotify('Error de red o servidor', 'danger');
    }
    setLoading(false);
  }

  return (
    <button className="btn-success-outline" onClick={handleClick} disabled={loading}>
      {loading ? <span className="spinner spinner-brand" /> : 'Reimprimir'}
    </button>
  );
}

function Toast({ toast }) {
  return (
    <div className="toast-stack">
      <AnimatePresence>
        {toast && (
          <motion.div
            key={toast.id}
            className={`toast toast-${toast.tone}`}
            initial={{ opacity: 0, y: 20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10, scale: 0.95 }}
            transition={{ type: 'spring', stiffness: 320, damping: 26 }}
          >
            <span className="toast-icon">{toast.tone === 'success' ? '✓' : '⚠️'}</span>
            {toast.message}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// Números (aunque vengan como string desde Postgres) se comparan como número;
// todo lo demás se compara como texto.
function compareRows(a, b, key) {
  const va = a[key];
  const vb = b[key];
  if (va === null || va === undefined) return vb === null || vb === undefined ? 0 : -1;
  if (vb === null || vb === undefined) return 1;

  const na = Number(va);
  const nb = Number(vb);
  if (va !== '' && vb !== '' && !Number.isNaN(na) && !Number.isNaN(nb)) {
    return na - nb;
  }
  return String(va).localeCompare(String(vb), 'es');
}

function TableSkeleton({ moduleKey }) {
  const columns = COLUMNS[moduleKey] || [];
  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key}>{c.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: 6 }).map((_, i) => (
            <tr key={i}>
              {columns.map((c) => (
                <td key={c.key}>
                  <span className="skeleton-bar" style={{ width: `${50 + ((i * 13 + c.key.length * 7) % 40)}%` }} />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Color del acento a la izquierda de cada fila: el estado real si el módulo tiene uno,
// o el verde de marca por defecto (para que no se vea todo gris/plano).
function getRowTone(moduleKey, row) {
  if (moduleKey === 'reportespagos') return ESTADO_PAGO_TONE[row.estado] || 'neutral';
  if (moduleKey === 'transferencia') return row.vuelto ? VUELTO_TONE[row.vuelto.estado] || 'neutral' : 'neutral';
  if (moduleKey === 'auditoria') return ACCION_LABELS[row.accion]?.tone || 'neutral';
  return 'success';
}

function DataTable({ moduleKey, rows, onSelect, onNotify }) {
  const columns = COLUMNS[moduleKey];
  const clickable =
    Boolean(DETAIL_ENDPOINT[moduleKey]) || moduleKey === 'reportespagos' || moduleKey === 'transferencia';
  const [sort, setSort] = useState({ key: null, dir: 'asc' });

  const sortedRows = useMemo(() => {
    if (!sort.key) return rows;
    const dir = sort.dir === 'asc' ? 1 : -1;
    return [...rows].sort((a, b) => compareRows(a, b, sort.key) * dir);
  }, [rows, sort]);

  function toggleSort(key) {
    setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: 'asc' }));
  }

  if (!rows.length) {
    return (
      <div className="empty-state">
        <span className="empty-state-icon">🗂️</span>
        <p>No hay registros para mostrar.</p>
      </div>
    );
  }

  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            {columns.map((c) => (
              <th
                key={c.key}
                className={`sortable-th ${c.money ? 'num' : ''}`}
                onClick={() => toggleSort(c.key)}
              >
                {c.label}
                <span className="sort-arrow">{sort.key === c.key ? (sort.dir === 'asc' ? ' ▲' : ' ▼') : ''}</span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {sortedRows.map((row, i) => (
            <motion.tr
              key={row.idautorizacion ?? row.idventa ?? row.id ?? i}
              className={`row-tone-${getRowTone(moduleKey, row)} ${clickable ? 'row-clickable' : ''}`}
              onClick={clickable ? () => onSelect(row) : undefined}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: Math.min(i * 0.02, 0.3) }}
            >
              {columns.map((c) => (
                <td key={c.key} className={c.money ? 'num' : ''}>
                  {ID_COLUMNS.has(c.key) && row[c.key] != null ? (
                    <span className="id-chip">#{row[c.key]}</span>
                  ) : moduleKey === 'auditoria' && c.key === 'accion' ? (
                    <AccionBadge accion={row.accion} />
                  ) : c.key === 'programacion' ? (
                    formatProgramacion(row.programacion, row.tipoprogramacion)
                  ) : moduleKey === 'reportespagos' && c.key === 'estado' ? (
                    <EstadoPagoBadge estado={row.estado} />
                  ) : c.key === 'vueltoEstado' ? (
                    <VueltoBadge vuelto={row.vuelto} />
                  ) : moduleKey === 'programaciones' && c.key === 'valorabonado' ? (
                    <>
                      {Number(row.valorabonado) > 0 && (
                        <span className="badge-accion badge-success">Con abono</span>
                      )}{' '}
                      {formatMoney(row.valorabonado)}
                    </>
                  ) : c.money ? (
                    formatMoney(row[c.key])
                  ) : (
                    `${row[c.key] ?? ''}${c.suffix ?? ''}`
                  )}
                </td>
              ))}
            </motion.tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DetailRow({ label, value }) {
  if (value === null || value === undefined || value === '') return null;
  return (
    <div className="detail-row">
      <span className="detail-label">{label}</span>
      <span className="detail-value">{value}</span>
    </div>
  );
}

// La respuesta del datáfono viene como JSON anidado (a veces 2-3 niveles como texto
// dentro de texto). Se intenta desarmar nivel por nivel; si algo falla, se muestra
// lo que sí se pudo sacar más el texto crudo como respaldo.
function parsePagoRespuesta(raw) {
  if (!raw) return null;

  let outer;
  try {
    outer = JSON.parse(raw);
  } catch {
    return { raw };
  }

  const content = outer.content || {};
  let inner = null;
  try {
    inner = typeof content.response === 'string' ? JSON.parse(content.response) : content.response;
  } catch {
    inner = null;
  }

  let card = null;
  if (inner && typeof inner.content === 'string') {
    try {
      card = JSON.parse(inner.content).data;
    } catch {
      card = null;
    }
  }

  return {
    status: content.status,
    codePayment: content.codePayment,
    dateRequest: content.dateRequest,
    datePayment: content.datePayment,
    mensaje: inner?.message,
    franquicia: card?.franchise,
    tarjeta: card?.lastFourDigitsCard,
    codigoAutorizacion: card?.autorizationCode,
    recibo: card?.receipt,
    raw,
  };
}

function PagoModal({ pago, onClose, onApproved }) {
  const info = parsePagoRespuesta(pago.respuesta);
  const [confirming, setConfirming] = useState(false);
  const [approving, setApproving] = useState(false);
  const [approveError, setApproveError] = useState('');

  async function handleAprobar() {
    setApproving(true);
    setApproveError('');
    try {
      const res = await apiFetch(`/api/nsx-autoservice/page/reportespagos/${pago.idpago}/aprobar`, {
        method: 'POST',
      });
      const result = await res.json();
      if (result.success) {
        onApproved();
      } else {
        setApproveError(result.message || 'No se pudo aprobar el pago.');
        setConfirming(false);
      }
    } catch {
      setApproveError('Error de red o servidor.');
      setConfirming(false);
    } finally {
      setApproving(false);
    }
  }

  return (
    <div className="detail-overlay" onClick={onClose}>
      <motion.div
        className="detail-panel"
        onClick={(e) => e.stopPropagation()}
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.96 }}
        transition={{ type: 'spring', stiffness: 300, damping: 30 }}
      >
        <div className="detail-header">
          <h2>Pago #{pago.idpago}</h2>
          <button className="detail-close" onClick={onClose}>✕</button>
        </div>

        <section className="detail-section">
          <DetailRow label="Identificador" value={pago.identificador} />
          <DetailRow label="Forma de pago" value={pago.formapago} />
          <DetailRow label="Estado" value={<EstadoPagoBadge estado={pago.estado} />} />
          <DetailRow label="Valor" value={formatMoney(pago.valor)} />
          <DetailRow label="Fecha" value={pago.fecha} />
        </section>

        <section className="detail-section">
          <h3>Respuesta del datáfono</h3>
          {info ? (
            <>
              <DetailRow label="Mensaje" value={info.mensaje} />
              <DetailRow label="Estado transacción" value={info.status} />
              <DetailRow label="Código" value={info.codePayment} />
              <DetailRow label="Franquicia" value={info.franquicia} />
              <DetailRow label="Tarjeta" value={info.tarjeta ? `**** ${info.tarjeta}` : null} />
              <DetailRow label="Cód. autorización" value={info.codigoAutorizacion} />
              <DetailRow label="Recibo" value={info.recibo} />
              <DetailRow label="Fecha solicitud" value={info.dateRequest} />
              <details className="raw-details">
                <summary>Ver respuesta completa</summary>
                <pre className="raw-json">{info.raw}</pre>
              </details>
            </>
          ) : (
            <p className="empty-state">Sin respuesta registrada.</p>
          )}
        </section>

        {approveError && <p className="login-error">{approveError}</p>}

        {pago.estado !== 'Completado' && (
          <div className="detail-actions">
            {confirming ? (
              <>
                <span className="confirm-text">
                  ¿Aprobar este pago? Se marcará como completado y, si con esto queda pagado del todo, se genera la autorización de despacho.
                </span>
                <button className="btn-ghost" onClick={() => setConfirming(false)} disabled={approving}>
                  Cancelar
                </button>
                <button className="btn-success-outline" onClick={handleAprobar} disabled={approving}>
                  {approving ? <span className="spinner spinner-brand" /> : 'Sí, aprobar'}
                </button>
              </>
            ) : (
              <button className="btn-success-outline" onClick={() => setConfirming(true)}>
                Aprobar pago
              </button>
            )}
          </div>
        )}
      </motion.div>
    </div>
  );
}

function TransferenciaModal({ row, onClose, onNotify }) {
  const vuelto = row.vuelto;

  return (
    <div className="detail-overlay" onClick={onClose}>
      <motion.div
        className="detail-panel"
        onClick={(e) => e.stopPropagation()}
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.96 }}
        transition={{ type: 'spring', stiffness: 300, damping: 30 }}
      >
        <div className="detail-header">
          <h2>Venta #{row.idventa}</h2>
          <button className="detail-close" onClick={onClose}>✕</button>
        </div>

        <div className="detail-grid">
          <section className="detail-section">
            <h3>Venta</h3>
            <DetailRow label="Producto" value={row.producto} />
            <DetailRow label="Identificador" value={row.identificador} />
            <DetailRow label="Venta sistema" value={row.idventasistema} />
            <DetailRow label="Preset sistema" value={row.idpresetnsx} />
            <DetailRow label="Dinero" value={formatMoney(row.dinero)} />
            <DetailRow label="Saldo pendiente" value={formatMoney(row.saldo)} />
            <DetailRow label="Fecha" value={row.fecharegistro} />
          </section>

          <section className="detail-section">
            <h3>Vuelto</h3>
            {vuelto ? (
              <>
                <DetailRow label="Estado" value={<VueltoBadge vuelto={vuelto} />} />
                <DetailRow label="Código" value={vuelto.codigo} />
                <DetailRow label="Valor" value={formatMoney(vuelto.valor)} />
                <DetailRow label="Creado" value={vuelto.fechaCreacion} />
                <DetailRow label="Usado" value={vuelto.fechaUso} />
              </>
            ) : (
              <p className="empty-state">Sin vuelto asociado.</p>
            )}
          </section>
        </div>

        {vuelto?.codigo && (
          <div className="detail-actions">
            <span className="confirm-text">Reenvía este vuelto a la impresora del punto.</span>
            <ReimprimirButton codigo={vuelto.codigo} onNotify={onNotify} />
          </div>
        )}
      </motion.div>
    </div>
  );
}

function DetailPanel({ moduleKey, id, onClose, onCancelled }) {
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [cancelError, setCancelError] = useState('');
  const [selectedPago, setSelectedPago] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    fetch(`/api/nsx-autoservice/page/${DETAIL_ENDPOINT[moduleKey]}/${id}`)
      .then((res) => res.json())
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [moduleKey, id]);

  async function handleAnular() {
    setCancelling(true);
    setCancelError('');
    try {
      const res = await apiFetch(`/api/nsx-autoservice/page/autorizaciones/${id}/anular`, {
        method: 'POST',
      });
      const result = await res.json();
      if (result.success) {
        onCancelled();
      } else {
        setCancelError(result.message || 'No se pudo anular la autorización.');
        setConfirming(false);
      }
    } catch {
      setCancelError('Error de red o servidor.');
      setConfirming(false);
    } finally {
      setCancelling(false);
    }
  }

  return (
    <div className="detail-overlay" onClick={onClose}>
      <motion.aside
        className="detail-panel"
        onClick={(e) => e.stopPropagation()}
        initial={{ x: 360, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        exit={{ x: 360, opacity: 0 }}
        transition={{ type: 'spring', stiffness: 300, damping: 30 }}
      >
        <div className="detail-header">
          <h2>{DETAIL_TITLE[moduleKey] || 'Detalle'} #{id}</h2>
          <button className="detail-close" onClick={onClose}>✕</button>
        </div>

        {loading ? (
          <div className="loading-row">
            <span className="spinner spinner-brand" /> Cargando...
          </div>
        ) : !detail ? (
          <p className="empty-state">No se encontró información.</p>
        ) : (
          <>
            <div className="detail-grid">
              <section className="detail-section">
                <h3>Cliente</h3>
                <DetailRow label="Nombre" value={detail.nombre} />
                <DetailRow label="Documento" value={detail.identificador} />
                <DetailRow label="Tipo documento" value={detail.tipodocumento} />
                <DetailRow label="Correo" value={detail.correo} />
                <DetailRow label="Placa" value={detail.placa} />
                <DetailRow label="Km" value={detail.km} />
              </section>

              <section className="detail-section">
                <h3>Despacho</h3>
                <DetailRow label="Producto" value={detail.producto} />
                <DetailRow label="Manguera" value={detail.manguera} />
                <DetailRow label="Posición (sistema)" value={detail.posicionnsx} />
                <DetailRow label="Programación" value={formatProgramacion(detail.programacion, detail.tipoprogramacion)} />
                {moduleKey === 'ventas' ? (
                  <>
                    <DetailRow label="Dinero" value={formatMoney(detail.dinero)} />
                    <DetailRow label="Volumen" value={detail.volumen != null ? `${detail.volumen} G` : null} />
                  </>
                ) : (
                  <DetailRow label="Valor abonado" value={formatMoney(detail.valorabonado)} />
                )}
                <DetailRow label="Precio" value={formatMoney(detail.precio)} />
                <DetailRow label="Fecha registro" value={detail.fecharegistro} />
              </section>
            </div>

            <section className="detail-section">
              <h3>Pagos</h3>
              {detail.pagos?.length ? (
                <div className="table-wrap">
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Forma de pago</th>
                        <th>Valor</th>
                        <th>Estado</th>
                        <th>Fecha</th>
                      </tr>
                    </thead>
                    <tbody>
                      {detail.pagos.map((pago) => (
                        <tr key={pago.idpago} className="row-clickable" onClick={() => setSelectedPago(pago)}>
                          <td>{pago.formapago}</td>
                          <td className="num">{formatMoney(pago.valor)}</td>
                          <td><EstadoPagoBadge estado={pago.estado} /></td>
                          <td>{pago.fecha}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <p className="empty-state">Sin pagos registrados.</p>
              )}
            </section>

            {cancelError && <p className="login-error">{cancelError}</p>}

            {moduleKey === 'autorizaciones' && (
              <div className="detail-actions">
                {confirming ? (
                  <>
                    <span className="confirm-text">¿Anular esta autorización? No se podrá reimpulsar al sistema.</span>
                    <button className="btn-ghost" onClick={() => setConfirming(false)} disabled={cancelling}>
                      Cancelar
                    </button>
                    <button className="btn-danger-outline" onClick={handleAnular} disabled={cancelling}>
                      {cancelling ? <span className="spinner spinner-danger" /> : 'Sí, anular'}
                    </button>
                  </>
                ) : (
                  <button className="btn-danger-outline" onClick={() => setConfirming(true)}>
                    Anular autorización
                  </button>
                )}
              </div>
            )}
          </>
        )}
      </motion.aside>

      <AnimatePresence>
        {selectedPago && (
          <PagoModal
            pago={selectedPago}
            onClose={() => setSelectedPago(null)}
            onApproved={() => {
              setSelectedPago(null);
              onCancelled();
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

const PAGE_SIZE = 25;

export default function DashboardPage() {
  useTheme();

  const usuario = getUsuario();

  useEffect(() => {
    if (!sessionStorage.getItem('token')) {
      window.location.href = '/api/nsx-autoservice/page/index';
    }
  }, []);

  const [active, setActive] = useState('autorizaciones');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedId, setSelectedId] = useState(null);
  const [selectedPago, setSelectedPago] = useState(null);
  const [selectedTransferencia, setSelectedTransferencia] = useState(null);
  const [toast, setToast] = useState(null);

  function notify(message, tone = 'success') {
    setToast({ id: Date.now(), message, tone });
  }

  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 3500);
    return () => clearTimeout(timer);
  }, [toast]);

  function handleSelectRow(row) {
    if (active === 'reportespagos') {
      setSelectedPago(row);
    } else if (active === 'transferencia') {
      setSelectedTransferencia(row);
    } else {
      setSelectedId(row[ROW_ID_FIELD[active]]);
    }
  }
  const [refreshTick, setRefreshTick] = useState(0);
  const [filter, setFilter] = useState({ text: '', ...currentMonthRange() });
  const [page, setPage] = useState(1);
  const [reportMeta, setReportMeta] = useState({ total: 0, totalCompletado: 0, porFormaPago: [] });

  const isPaginated = active === 'reportespagos';

  // Módulos normales: se traen enteros y se filtran en el navegador
  useEffect(() => {
    if (isPaginated) return;
    let cancelled = false;
    setLoading(true);
    setError('');

    fetch(`/api/nsx-autoservice/page/${active}`)
      .then((res) => res.json())
      .then((data) => {
        if (!cancelled) setRows(Array.isArray(data) ? data : []);
      })
      .catch(() => {
        if (!cancelled) setError('No se pudo cargar la información.');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [active, refreshTick, isPaginated]);

  // Reporte de pagos: la tabla puede tener miles de filas, así que el filtro y la
  // paginación se resuelven en el servidor (con un pequeño debounce al escribir).
  useEffect(() => {
    if (!isPaginated) return;
    let cancelled = false;
    setLoading(true);
    setError('');

    const timer = setTimeout(() => {
      const params = new URLSearchParams();
      if (filter.from) params.set('from', filter.from);
      if (filter.to) params.set('to', filter.to);
      if (filter.text.trim()) params.set('q', filter.text.trim());
      params.set('page', page);
      params.set('pageSize', PAGE_SIZE);

      fetch(`/api/nsx-autoservice/page/${active}?${params.toString()}`)
        .then((res) => res.json())
        .then((data) => {
          if (cancelled) return;
          setRows(data.rows || []);
          setReportMeta({
            total: data.total || 0,
            totalCompletado: data.totalCompletado || 0,
            porFormaPago: data.porFormaPago || [],
          });
        })
        .catch(() => {
          if (!cancelled) setError('No se pudo cargar la información.');
        })
        .finally(() => {
          if (!cancelled) setLoading(false);
        });
    }, 300);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [active, refreshTick, isPaginated, page, filter.from, filter.to, filter.text]);

  useEffect(() => {
    setFilter({ text: '', ...currentMonthRange() });
    setPage(1);
  }, [active]);

  useEffect(() => {
    setPage(1);
  }, [filter.from, filter.to, filter.text]);

  const activeModule = MODULES.find((m) => m.key === active);
  const filterConfig = FILTER_CONFIG[active];

  const visibleRows = isPaginated
    ? rows
    : rows.filter((row) => {
        if (!filterConfig) return true;

        if (filter.text.trim()) {
          const needle = filter.text.trim().toLowerCase();
          const matches = filterConfig.searchFields
            .map((f) => row[f])
            .filter((v) => v !== null && v !== undefined)
            .some((v) => String(v).toLowerCase().includes(needle));
          if (!matches) return false;
        }

        const dateValue = row[filterConfig.dateField];
        if (dateValue) {
          const day = String(dateValue).slice(0, 10);
          if (filter.from && day < filter.from) return false;
          if (filter.to && day > filter.to) return false;
        }

        return true;
      });

  const totalPages = isPaginated ? Math.max(1, Math.ceil(reportMeta.total / PAGE_SIZE)) : 1;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <img src={`${import.meta.env.BASE_URL}logo-insepet-blanco.png`} alt="INSEPET" />
        </div>
        <nav className="sidebar-nav">
          {MODULES.map((m) => (
            <button
              key={m.key}
              className={`nav-item ${active === m.key ? 'active' : ''}`}
              onClick={() => setActive(m.key)}
            >
              <span className="nav-icon">{m.icon}</span>
              {m.label}
            </button>
          ))}
          {SOON.length > 0 && <div className="nav-divider" />}
          {SOON.map((m) => (
            <div key={m.key} className="nav-item disabled" title="Próximamente">
              {m.label}
              <span className="badge-soon">Pronto</span>
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-user">
            <span className="sidebar-user-name">{usuario?.nombres || usuario?.userName || 'Usuario'}</span>
          </div>
          <button className="logout-btn" onClick={() => logout()}>
            Cerrar sesión
          </button>
          <p className="sidebar-brand-footer">
            INSEPET · Grupo Empresarial
            <br />© {new Date().getFullYear()}
          </p>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div>
            <h1 className="topbar-title">{activeModule?.label}</h1>
            <p className="topbar-subtitle">{activeModule?.description}</p>
          </div>
        </header>

        <main className="content">
          <div className="content-card">
            <FilterBar moduleKey={active} value={filter} onChange={setFilter} />
            {isPaginated && (
              <div className="report-summary">
                <span className="report-total">Total completado: {formatMoney(reportMeta.totalCompletado)}</span>
                {reportMeta.porFormaPago.map((f) => (
                  <span key={f.formapago} className="report-chip">
                    {f.formapago}: {formatMoney(f.total)}
                  </span>
                ))}
              </div>
            )}
            <AnimatePresence mode="wait">
              {loading ? (
                <motion.div key="loading" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                  {active === 'transferencia' && (
                    <p className="loading-hint">Consultando vueltos en el sistema, puede tardar unos segundos...</p>
                  )}
                  <TableSkeleton moduleKey={active} />
                </motion.div>
              ) : error ? (
                <motion.p key="error" className="login-error" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                  {error}
                </motion.p>
              ) : (
                <motion.div key={active} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                  <DataTable moduleKey={active} rows={visibleRows} onSelect={handleSelectRow} onNotify={notify} />
                </motion.div>
              )}
            </AnimatePresence>
            {isPaginated && !loading && !error && (
              <div className="pager">
                <button className="btn-ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
                  ‹ Anterior
                </button>
                <span className="pager-info">
                  Página {page} de {totalPages} · {reportMeta.total} pagos
                </span>
                <button className="btn-ghost" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                  Siguiente ›
                </button>
              </div>
            )}
          </div>
        </main>
      </div>

      <AnimatePresence>
        {selectedId && (
          <DetailPanel
            moduleKey={active}
            id={selectedId}
            onClose={() => setSelectedId(null)}
            onCancelled={() => {
              setSelectedId(null);
              setRefreshTick((n) => n + 1);
            }}
          />
        )}
        {selectedPago && (
          <PagoModal
            pago={selectedPago}
            onClose={() => setSelectedPago(null)}
            onApproved={() => {
              setSelectedPago(null);
              setRefreshTick((n) => n + 1);
            }}
          />
        )}
        {selectedTransferencia && (
          <TransferenciaModal
            row={selectedTransferencia}
            onClose={() => setSelectedTransferencia(null)}
            onNotify={notify}
          />
        )}
      </AnimatePresence>
      <Toast toast={toast} />
    </div>
  );
}
