

exports.isAlive = async (req, res, next) => {
  try {
    return res.status(200).json({
      message: "Server is alive",
    });
  } catch (error) {
    return next(error);
  }
};


exports.index = async (req, res, next) => {
    res.render("index", { estilo: "login", titulo: "Index", idpantalla: 10 });
};

exports.authentication = async (req, res, next) => {
    const { user, password, screenid } = req.body;

    console.log("Datos recibidos:", { user, password, screenid });
    // Simulación de validación (puedes consultar base de datos aquí)
    // const validatedUser = await querypg.ValidUserLogin(user, password, screenid);
    // const validateScreen = await querypg.GetAvailableScreenId(screenid);

    const validatedUser = true;
    const validateScreen = true;

    console.log("Validación:", { validatedUser, validateScreen });
    if (validatedUser && validateScreen) {
        res.json({ success: true });
    } else {
        res.json({ success: false });
    }
};

exports.home = async (req, res, next) => {
  
 res.render("home", {
    estilo: "dashboard",
    titulo: "Dashboard",
    usuario: "Administrador",
    idposicion: 0,
  });
};



