// App.jsx
import { Routes, Route, Navigate } from 'react-router-dom';
import Login from './features/auth/Login';
import Register from './features/auth/Register';
import UserHome from './features/dashboard/userDashboard/userhome';
import MyForms from './features/dashboard/userDashboard/myForms';

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
    </Routes>
  );
}

export default App;