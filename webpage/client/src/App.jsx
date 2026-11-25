import LoginPage from './pages/LoginPage.jsx';
import DashboardPage from './pages/DashboardPage.jsx';

export default function App() {
  const isHome = window.location.pathname.endsWith('/home');
  return isHome ? <DashboardPage /> : <LoginPage />;
}
