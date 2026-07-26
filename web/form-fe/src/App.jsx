// App.jsx
import { Routes, Route, Navigate } from 'react-router-dom';
import Login from '../src/features/auth/Login';
import Register from '../src/features/auth/Register';

function App() {
  return (
    <Routes>
      {/* Redirect dari "/" ke "/login" */}
      <Route path="/" element={<Navigate to="/login" replace />} />
      
      {/* Route halaman */}
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
    </Routes>
  );
}

export default App;