const nodemailer = require("nodemailer");
const email = require("../../services/email/configuration").config;
const fs = require("fs");
const path = require("path");
const encrypter = require("../../../utils/encrypter");

const handlebars = require("handlebars");

function renderTemplate(templateName, data) {
  const templatePath = path.join(
    __dirname,
    "templates",
    `${templateName}.html`,
  );

  const html = fs.readFileSync(templatePath, "utf8");
  const template = handlebars.compile(html);

  return template(data);
}

const transporter = nodemailer.createTransport({
  host: encrypter.desencrypter(email.SMTP_HOST), //process.env.SMTP_HOST,
  port: email.SMTP_PORT, // Number(process.env.SMTP_PORT),
  secure: false, // 👈 MUY IMPORTANTE para STARTTLS
  auth: {
    user: encrypter.desencrypter(email.SMTP_USER), // process.env.SMTP_USER,
    pass: encrypter.desencrypter(email.SMTP_PASS), // process.env.SMTP_PASS
  },
  tls: {
    rejectUnauthorized: false, // 👈 útil si el certificado es interno
  },
});

async function emailNotification(email, code) {
  try {
    const bodyHtml = renderTemplate("notificacion", {
      codigo: code,
      nombre: "EDS Petromil",
    });

    const info = await transporter.sendMail({
      from: `"Petromil autoatendido" <autoatendido@insepet.com>`,
      to: email,
      subject: "Código de acceso",
      text: `Este es un email de prueba con tu código de acceso: ${code}`,
      html: bodyHtml,
      attachments: [
        {
          filename: "logo_insepet_white.png",
          path: "./ws_server/services/email/assets/logo_insepet_white.png",
          cid: "logoInsepet", // 👈 coincide con el src
        },
      ],
    });

    console.log("Email enviado:", info.messageId);
  } catch (error) {
    console.error("Error enviando email:", error);
  }
}

module.exports = { emailNotification };
