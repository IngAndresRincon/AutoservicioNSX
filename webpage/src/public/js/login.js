document.getElementById('loginForm').addEventListener('submit', async function (e) {
  e.preventDefault();

//   const email = document.getElementById('email').value.trim();
  const user = document.getElementById('username').value.trim();
  const password = document.getElementById('password').value.trim();
  const screenid = document.getElementById('idpantalla').innerText;


  const btn = document.getElementById('loginBtn');
  const spinner = document.getElementById('loadingSpinner');
  const labelButon = document.getElementById('loginText');

  // Mostrar loading
  spinner.classList.remove('d-none');
  labelButon.textContent = 'Validando...';
  btn.disabled = true;

  try {
    const res = await fetch('/api/nsx-autoservice/page/authentication', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user,password,screenid})
    });

    const result = await res.json();

    if (result.success) {
      window.location.href =`/api/nsx-autoservice/page/home`;
    } else {
      alert('Credenciales inválidas');
    }

  } catch (err) {
    console.error(err);
    alert('Error al conectarse con el servidor');
  } finally {
    // Restaurar botón
    spinner.classList.add('d-none');
    labelButon.textContent = 'Ingresar';
    btn.disabled = false;
  }
});