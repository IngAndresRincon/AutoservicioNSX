using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class DispPosProgramacionModel
    {
        /// <summary>
        /// Identificador del estado de la venta
        /// </summary>
        public int IdDispPosProgramacion { get; set; }
        /// <summary>
        /// Identificador unico de la transaccion - usado normalmente para operacion online
        /// </summary>
        public Guid Guid { get; set; }
        /// <summary>
        /// Fecha de inicio de la venta
        /// </summary>
        public DateTime FechaInicial { get; set; }
        /// <summary>
        /// Volumen inicial con el cual inicia la venta de combustible
        /// </summary>
        public double? DineroInicial { get; set; }
        /// <summary>
        /// Dinero inicial con el cual inicia la venta de combustible
        /// </summary>
        public double? VolumenInicial { get; set; }
        /// <summary>
        /// Valor programado al dispensador
        /// </summary>
        public double ValorProgramado { get; set; }
        /// <summary>
        /// Valor dispensado de combustible
        /// </summary>
        public double? ValorDispensado { get; set; }
        /// <summary>
        /// Grado verificacion
        /// </summary>
        public int? GradoVerificado { get; set; }
        /// <summary>
        /// Placa del vehiculo 
        /// </summary>
        public string Placa { get; set; }
        /// <summary>
        /// Kilometraje inicial de la venta
        /// </summary>
        public double? Kilometraje { get; set; }
        /// <summary>
        /// Identificador con el cual se valida en un sistema web
        /// </summary>
        public string IdentificadorWeb { get; set; }
        /// <summary>
        /// Posicion por la cual se realiza la venta
        /// </summary>
        public int IdPosicion { get; set; }
        /// <summary>
        /// Identificador de la isla
        /// </summary>
        public int? IdIsla { get; set; }
        /// <summary>
        /// Identificador del producto que se esta vendiendo
        /// </summary>
        public int? IdProducto { get; set; }
        /// <summary>
        /// Tipo de transaccion de la venta
        /// </summary>
        public int? IdTipoTransaccion { get; set; }
        /// <summary>
        /// Identificador del grado del dispensador en la venta
        /// </summary>
        public int? IdPosicionGrado { get; set; }
        /// <summary>
        /// Id del identificador usado para la venta
        /// </summary>
        public int? IdIdentificador { get; set; }
        /// <summary>
        /// Id de la cuenta
        /// </summary>
        public int? IdCuenta { get; set; }
        /// <summary>
        /// Tipo de programacion que se realiza al surtidor - Ver enumeracion
        /// </summary>
        public int IdTipoProgramacion { get; set; }
        /// <summary>
        /// Id del nivel al cual se autorizo la venta
        /// </summary>
        public int? IdNivel { get; set; }
        /// <summary>
        /// Id de la venta asociada a la programacion
        /// </summary>
        public int? IdVenta { get; set; }
        /// <summary>
        /// Id del turno vigente, en caso de que no este activo la opcion turnos NULL
        /// </summary>
        public int? IdTurno { get; set; }
        /// <summary>
        /// Id del precio del producto de venta
        /// </summary>
        public int? IdPrecioProducto { get; set; }
        /// <summary>
        /// Indica el estado de la programacion de la venta
        /// </summary>
        public int IdEstadoProgramacion { get; set; }
        /// <summary>
        /// Id del corte 
        /// </summary>
        public int? IdCorte { get; set; }
        /// <summary>
        /// Tipo de sistema web con el cual se opera
        /// </summary>
        public int? IdTipoSistema { get; set; }

        public double PrecioMaster { get; set; }


    }
}
