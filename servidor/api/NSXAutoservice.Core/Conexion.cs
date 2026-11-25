using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace NSXAutoservice.Core
{
    public class Conexion
    {
        private readonly string _connectionString;

        public Conexion(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection");
        }

        public SqlConnection CrearConexion()
        {
            return new SqlConnection(_connectionString);
        }
    }
}
