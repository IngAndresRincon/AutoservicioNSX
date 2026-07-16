
const crypto = require('crypto');

// Configuración
const key = 'insepetModelKey';
const iv = Buffer.from([240, 3, 45, 29, 0, 76, 173, 59]);

function generateKey(key) {
  // Generar hash MD5 a partir de la clave
  const md5Key = crypto.createHash('md5').update(key, 'utf8').digest();
  // Expandir a 24 bytes concatenando los primeros 8 bytes del hash al final
  return Buffer.concat([md5Key, md5Key.slice(0, 8)]);
}

function encrypter(text) {
  try {
    const derivedKey = generateKey(key); // Generar la clave derivada
    const cipher = crypto.createCipheriv('des-ede3-cbc', derivedKey, iv); // Crear el cifrador
    cipher.setAutoPadding(true); // Padding PKCS7 (por defecto es true)

    let encrypted = cipher.update(text, 'utf8', 'base64');
    encrypted += cipher.final('base64');
    return encrypted;
  } catch (error) {
    console.error('Error encriptando:', error);
    return '';
  }
}

function desencrypter(text) {
  try {
    const derivedKey = generateKey(key); // Generar la clave derivada
    const decipher = crypto.createDecipheriv('des-ede3-cbc', derivedKey, iv); // Crear el descifrador
    decipher.setAutoPadding(true); // Padding PKCS7

    let decrypted = decipher.update(text, 'base64', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (error) {
    console.error('Error desencriptando:', error);
    return '';
  }
}
// Ejemplo de uso
// const textoOriginal = 'Texto a encriptar';
// const textoEncriptado = encrypter('Aleja080408*');
// console.log('Texto encriptado:', textoEncriptado);

// const textoDesencriptado = desencrypter("L0FNJaYiFcXIdbt/w74jCQ==");
// console.log('Texto desencriptado:', textoDesencriptado);

module.exports = {encrypter ,desencrypter}