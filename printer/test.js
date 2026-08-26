
const net = require("net");

const ESC = "\x1B";
const GS = "\x1D";
// Funciones helper para formatear
const reboot = () => [0x1b, 0x40];
const alignLeft = () => [0x1b, 0x61, 0x0];
const alignRight = () => [0x1b, 0x61, 0x02];
const maxSize = () => [0x1b, 0x21, 0x12];
const alignCenter = () => [0x1b, 0x61, 0x01];
const newline = () => 0x0a;
const boldOn = () => [0x1b, 0x45, 0x01];
const boldOff = () => [0x1b, 0x45, 0x00];
const cutPaper = () => [0x1d, 0x56, 0x01];

const printerIP = "192.168.120.119";
const printerPORT = "9100";

async function generatePrint() {
  

  let arrayRows = [];
  const arraysplit = [
    { Align: "center", text: "2025/6/9 16:2:57", Bold: true, Style: "0x09" },
    { Align: "center", text: "\n", Bold: true, Style: "0x00" },
    { Align: "center", text: "CODIGO GENERADO", Bold: true, Style: "0x09" },
    { Align: "center", text: "\n", Bold: true, Style: "0x00" },
    { Align: "center", text: "67995653", Bold: true, Style: "0x09" },
    { Align: "center", text: "\n", Bold: true, Style: "0x00" },
    {
      Align: "left",
      text: "Conserve su codigo hasta que finalice la transaccion",
      Bold: false,
      Style: "0x01",
    },
    {
      Align: "left",
      text: "En caso de algun problema con su compra, puede ingresar su codigo seleccionando la opcion MI CODIDO en el ingreso.",
      Bold: true,
      Style: "0x01",
    },
    { Align: "center", text: "\n", Bold: true, Style: "0x00" },
    { Align: "center", text: "Id: 34", Bold: true, Style: "0x00" },
    {
      Align: "center",
      text: "Pantalla: 5ba3a8885793bcf4",
      Bold: true,
      Style: "0x00",
    },
  ];

  for (let i = 0; i < arraysplit.length; i++) {
    // arrayRows.push(Buffer.from(alignRight()));
    //arrayRows.push(Buffer.from(doubleWidth()));
    //arrayRows.push(Buffer.from(doubleHeight()));
    //arrayRows.push(Buffer.from(size_12_cpp()));

    boldOff().forEach((element) => {
      arrayRows.push(element);
    });

    if (arraysplit[i].Align == "center") {
      alignCenter().forEach((element) => {
        arrayRows.push(element);
      });
    }
    if (arraysplit[i].Align == "left") {
      alignLeft().forEach((element) => {
        arrayRows.push(element);
      });
    }
    if (arraysplit[i].Align == "right") {
      alignRight().forEach((element) => {
        arrayRows.push(element);
      });
    }

    const style = [
      0x1d,
      0x21,
      arraysplit[i].Style == "0x01"
        ? 0x01
        : arraysplit[i].Style == "0x02"
          ? 0x02
          : arraysplit[i].Style == "0x06"
            ? 0x06
            : arraysplit[i].Style == "0x08"
              ? 0x08
              : arraysplit[i].Style == "0x09"
                ? 0x09
                : arraysplit[i].Style == "0x10"
                  ? 0x10
                  : arraysplit[i].Style == "0x11"
                    ? 0x11
                    : arraysplit[i].Style == "0x12"
                      ? 0x12
                      : arraysplit[i].Style == "0x13"
                        ? 0x13
                        : arraysplit[i].Style == "0x14"
                          ? 0x14
                          : arraysplit[i].Style == "0x15"
                            ? 0x0f
                            : 0x00,
    ];

    style.forEach((element) => {
      arrayRows.push(element);
    });

    arrayRows.push(...Buffer.from(arraysplit[i].text));
    arrayRows.push(newline());
  }

    arrayRows.push(newline());
    arrayRows.push(newline());
    arrayRows.push(newline());
    arrayRows.push(newline());

  const client = new net.Socket();
  client.connect(printerPORT,printerIP, () => {
    //console.log("Conectado a la impresora.");
    client.write(Buffer.from(arrayRows));
    client.write(Buffer.from(cutPaper()));
    client.end();
  });

  client.on("error", async (err) => {
    logger.error("Error:", err.message + item["id"]);
    await queryPg.StatusPrint(item["id"], err.message);
  });
}

generatePrint();
