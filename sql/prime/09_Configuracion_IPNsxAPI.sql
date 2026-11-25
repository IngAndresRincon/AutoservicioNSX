/* ============================================================================
   09 - dbo.Configuracion 'IPNsxAPI' (idempotente)
   Formato 'ip|puerto': direccion del puerto de comandos de NSX Prime (8010) que usa el API del autoservicio.
   Por defecto 127.0.0.1|8010 (API y NSX en el mismo equipo). Si ya existe no se toca su valor.
   ============================================================================ */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Configuracion] WHERE [Nombre] = 'IPNsxAPI')
    INSERT INTO [dbo].[Configuracion] ([Pk_IdConfiguracion], [Nombre], [Descripcion], [Valor], [TipoDato])
    SELECT ISNULL(MAX([Pk_IdConfiguracion]), 0) + 1, 'IPNsxAPI', 'IP y puerto de NSX Prime para el API del autoservicio (ip|puerto)', '127.0.0.1|8010', 'string'
    FROM [dbo].[Configuracion];
GO
