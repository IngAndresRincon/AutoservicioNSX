const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

// Seguimiento de presets que service crea y consola cierra segun el estado en NSX.
// Codigos de public.estado: 0 Registrado, 2 Confirmado, 4 Reportado, 6 Venta Zero, 8 Despachando.
// `table` es preset_vendedor o preset_cliente. Si el preset no trae turno de vendedor y `defaultToAutoTurn`,
// la venta queda en el turno del autoservicio (historico_turno).
module.exports = ({ table, defaultToAutoTurn }) => ({
  getPendingPresets: async () => {
    try {
      const result = await client.query(
        `SELECT id, id_presetnsx, sincronizado, id_turno_vendedor
         FROM public.${table}
         WHERE sincronizado IN (2, 8) AND id_venta IS NULL AND id_presetnsx IS NOT NULL
         ORDER BY id;`,
      );
      return result.rows;
    } catch (error) {
      logger.error(error);
      throw new Error(`Error consultando ${table}:` + error.message);
    }
  },

  // Libera reservas que quedaron sin completar (service cayo entre reservar y llamar al API). Los presets ya enviados
  // (estado 2 u 8) no vencen por tiempo: se cierran segun el estado del preset en NSX.
  expirePresets: async () => {
    const result = await client.query(
      `UPDATE public.${table}
       SET sincronizado = 3, mensaje = 'Reserva sin completar', fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id_venta IS NULL AND sincronizado = 0 AND fecha_registro < NOW() - INTERVAL '2 minutes'
       RETURNING id;`,
    );
    return result.rows.map((row) => row.id);
  },

  markAsDispatching: async (id) => {
    const result = await client.query(
      `UPDATE public.${table}
       SET sincronizado = 8, fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id = $1 AND sincronizado = 2;`,
      [id],
    );
    return result.rowCount > 0;
  },

  markAsVentaZero: async (id) => {
    const result = await client.query(
      `UPDATE public.${table}
       SET sincronizado = 6, fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id = $1 AND sincronizado IN (2, 8);`,
      [id],
    );
    return result.rowCount > 0;
  },

  registerSale: async (preset, sale) => {
    const db = await client.connect();
    try {
      await db.query("BEGIN");

      const update = await db.query(
        `UPDATE public.${table}
         SET id_venta = $1, sincronizado = 4, fecha_actualizacion = CURRENT_TIMESTAMP
         WHERE id = $2 AND sincronizado IN (2, 8)
         RETURNING id;`,
        [sale.idVenta, preset.id],
      );

      if (update.rowCount > 0) {
        const autoTurn =
          defaultToAutoTurn && !preset.id_turno_vendedor
            ? "(SELECT MAX(id) FROM public.historico_turno WHERE activo = true)"
            : "0";

        await db.query(
          `INSERT INTO public.venta
             (id_venta_nsx, id_preset_nsx, id_posicion, id_manguera, dinero, volumen, precio, saldo, id_turno, id_turno_vendedor)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, ${autoTurn}, $9);`,
          [
            sale.idVenta,
            preset.id_presetnsx,
            sale.idPosicion,
            sale.numeroManguera,
            sale.dinero,
            sale.volumen,
            sale.precioVenta,
            sale.vuelto,
            preset.id_turno_vendedor,
          ],
        );
      }

      await db.query("COMMIT");
      return update.rowCount > 0;
    } catch (error) {
      await db.query("ROLLBACK");
      logger.error(error);
      throw new Error(`Error registrando la venta de ${table}:` + error.message);
    } finally {
      db.release();
    }
  },
});
