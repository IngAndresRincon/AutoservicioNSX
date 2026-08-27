const AppError = require("../../errors/AppError");
const serviceSystem = require("../../services/system/services");
const fs = require("fs");
const fsPromises = require("fs/promises");
const path = require("path");
const multer = require("multer");
const { randomUUID } = require("crypto");

let bodyPrint = [
  {Align: "center",text: "----------------------------------------",Bold: true,Style: "0x00",},
  {Align: "center",text: "Conserve su codigo",Bold: true,Style: "0x00",},
  {Align: "center",text: "hasta que",Bold: true,Style: "0x00",},
  {Align: "center",text: "finalice la transaccion",Bold: true,Style: "0x00",},
  {Align: "center",text: "----------------------------------------",Bold: true,Style: "0x00",},
  {Align: "center",text: "",Bold: true,Style: "0x00",},
  {Align: "center", text: "Codigo", Bold: true, Style: "0x00" },
  {Align: "center", text: "", Bold: true, Style: "0x00" },
  {Align: "center", text: "2025/6/9 16:2:57", Bold: true, Style: "0x00" },
  {Align: "center",text: "",Bold: true,Style: "0x00",},
  {Align: "center",text: "",Bold: true,Style: "0x00",},
  {Align: "center",text: "",Bold: true,Style: "0x00",},
  {Align: "center",text: "",Bold: true,Style: "0x00",},
];

const VIDEO_DIR = path.join(__dirname, "../../../public/video");
const MEDIA_VIDEO_PREFIX = "/mediav";
const MIME_EXTENSION_MAP = {
  "video/mp4": ".mp4",
  "video/quicktime": ".mov",
  "video/webm": ".webm",
  "video/x-matroska": ".mkv",
  "video/x-msvideo": ".avi",
  "video/x-flv": ".flv",
  "video/ogg": ".ogv",
};

const sanitizeFileName = (value) =>
  path
    .basename(String(value || "").trim())
    .replace(/[<>:"/\\|?*\x00-\x1F]/g, "_")
    .replace(/\s+/g, " ")
    .trim();

const getExtension = (filename, mimeType) => {
  const fileExt = path.extname(filename || "");
  if (fileExt) {
    return fileExt.toLowerCase();
  }

  return MIME_EXTENSION_MAP[(mimeType || "").toLowerCase()] || ".mp4";
};

const buildStoredFileName = ({ requestedName, originalName, mimeType }) => {
  const safeRequestedName = sanitizeFileName(requestedName || "");
  const safeOriginalName = sanitizeFileName(originalName || "video");
  const baseName = safeRequestedName || safeOriginalName;
  const parsedName = path.parse(baseName).name || "video";
  const extension =
    path.extname(baseName) ||
    getExtension(baseName, mimeType || safeOriginalName);

  return `${parsedName}${extension}`;
};

const ensureVideoDirectory = async () => {
  await fsPromises.mkdir(VIDEO_DIR, { recursive: true });
};

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    try {
      fs.mkdirSync(VIDEO_DIR, { recursive: true });
      cb(null, VIDEO_DIR);
    } catch (error) {
      cb(error);
    }
  },
  filename: (_req, file, cb) => {
    try {
      const safeOriginalName = sanitizeFileName(file.originalname || "video");
      const tempName = `${Date.now()}-${randomUUID()}${getExtension(
        safeOriginalName,
        file.mimetype,
      )}`;
      cb(null, tempName);
    } catch (error) {
      cb(error);
    }
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 500 * 1024 * 1024,
  },
});

const saveVideoFromRequest = async (req) => {
  await ensureVideoDirectory();

  if (!req.file) {
    throw new AppError("No se recibio ningun archivo de video", 400);
  }

  const requestedName =
    req.headers?.["x-video-name"] ||
    req.body?.videoName ||
    req.body?.filename ||
    req.body?.name ||
    "";
  const safeOriginalName = sanitizeFileName(req.file.originalname || "video");
  const mimeType = String(req.file.mimetype || "").toLowerCase();
  const storedName = buildStoredFileName({
    requestedName,
    originalName: safeOriginalName,
    mimeType,
  });

  const tempPath = req.file.path;
  const filePath = path.join(VIDEO_DIR, storedName);

  if (tempPath !== filePath) {
    try {
      await fsPromises.unlink(filePath);
    } catch (error) {
      if (error.code !== "ENOENT") {
        throw error;
      }
    }

    await fsPromises.rename(tempPath, filePath);
  }

  const stats = await fsPromises.stat(filePath);

  return {
    filename: storedName,
    originalName: safeOriginalName,
    requestedName: requestedName ? sanitizeFileName(requestedName) : null,
    filePath,
    publicUrl: `${MEDIA_VIDEO_PREFIX}/${storedName}`,
    size: stats.size,
    mimeType: mimeType || null,
    fieldName: req.file.fieldname,
  };
};

exports.uploadVideoMiddleware = upload.single("video");

exports.root = async (req, res, next) => {
  try {
    return res.status(200).json({ msg: "API Integracion NSX - Autoservicio" });
  } catch (error) {
    return next(error);
  }
};

exports.uploadVideo = async (req, res, next) => {
  try {
    const file = await saveVideoFromRequest(req);
    if (file) {
      const route = req.body.route;
      const bodyRoute =
        route == "standby"
          ? {
              standby_video: "prueba.mp4",
            }
          : route == "dispensing"
            ? {
                dispensing_video: "video.mp4",
              }
            : {
                standby_video: "prueba.mp4",
                dispensing_video: "video.mp4",
              };
      serviceSystem.updateVideoRoute(bodyRoute);
    }

    return res.status(201).json({
      isError: false,
      message: "Video cargado correctamente",
      content: file,
    });
  } catch (error) {
    return next(error);
  }
};

exports.synchronizeModule = async (req, res, next) => {
  try {
    const response = await serviceSystem.synchronizeModule();
    if (!response) {
      throw new AppError("No se pudo sincronizar el modulo", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Modulo sincronizado correctamente",
    });
  } catch (error) {
    return next(error);
  }
};

exports.synchronizeScreen = async (req, res, next) => {
  try {
    const body = req.body;

    if (!body.serial || !body.ip) {
      throw new AppError("Los campos serial e ip son obligatorios", 400);
    }

    const response = await serviceSystem.synchronizeScreen(body);
    if (!response) {
      throw new AppError("No se pudo sincronizar la pantalla", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Pantalla sincronizada correctamente",
      content: { screenId: response },
    });
  } catch (error) {
    return next(error);
  }
};

exports.printcode = async (req, res, next) => {
  try {
    const { positionId,code } = req.body;

    const  currentDate = getFechaHoraColombia();
    bodyPrint[7].text = `------ ${code} ------`;
    bodyPrint[8].text = currentDate;

    const posId = parseInt(positionId??0);

    const response = await serviceSystem.printcode(posId,bodyPrint);

    return res.status(response?200:404).json({
      isError: response?false:true,
      message: "Impresión enviada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};


function getFechaHoraColombia() {
    const fecha = new Date();

    const partes = new Intl.DateTimeFormat("sv-SE", {
        timeZone: "America/Bogota",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false
    }).format(fecha);

    return partes.replace(" ", " ");
}