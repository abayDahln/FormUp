// App.jsx
import { Routes, Route, Navigate } from 'react-router-dom';
import Login from './features/auth/Login';
import Register from './features/auth/Register';
import UserHome from './features/dashboard/userDashboard/userhome';
import MyForms from './features/dashboard/userDashboard/myForms';
import TemplatesPage from './features/dashboard/userDashboard/templateForm';
import UserHistory from './features/dashboard/userDashboard/userHistory';
import ResponsesPage from './features/dashboard/userDashboard/responsesPage';

function App() {
  return (
    <Routes>
      {/* Redirect dari "/" ke "/login" */}
      <Route path="/" element={<Navigate to="/login" replace />} />
      
      {/* Route halaman */}
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/dashboard" element={<UserHome />} />
      <Route path="/my-forms" element={<MyForms />} />
      <Route path="/templates" element={<TemplatesPage />} />
      <Route path="/responses" element={<ResponsesPage />} />
      <Route path="/history" element={<UserHistory />} />
    </Routes>
  );
}

export default App;