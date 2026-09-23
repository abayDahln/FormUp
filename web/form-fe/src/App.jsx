import { Routes, Route, Navigate } from 'react-router-dom';
import Login from './features/auth/Login';
import Register from './features/auth/Register';
import Verify from '../src/features/auth/VerifyRegister';
import UserHome from './features/dashboard/userDashboard/userhome';
import MyForms from './features/dashboard/userDashboard/myForms';
import TemplatesPage from './features/dashboard/userDashboard/templateForm';
import UserHistory from './features/dashboard/userDashboard/userHistory';
import CreateForm from './features/form-builder/CreateForm';
import FormBuilder from './features/form-builder/FormBuilder';

// 1. PASTIKAN FormResponsesPage DIIMPOR DENGAN BENAR
import FormResponsesPage from './features/form-responses/FormResponsesPage'; 

import FormRunnerPage from './features/form-runner/FormRunnerPage';
import FormResultPage from './features/form-runner/FormResultPage';
import AdminDashboardPage from './features/admin/AdminDashboardPage';
import ProfilePage from './features/profile/ProfilePage';
import ForgotPasswordPage from './features/auth/ForgotPasswordPage';
import LandingPage from './features/landing/LandingPage';
import AiChatPage from './features/ai-chat/AiChatPage';
import ProtectedRoute from './components/ui/ProtectedRoute';
import ErrorBoundary from './components/ui/ErrorBoundary';
import OfflineBanner from './components/ui/OfflineBanner';
import { isAuthenticated } from './services/apiService';

function App() {
  return (
    <ErrorBoundary>
      <OfflineBanner />
      <Routes>
        <Route path="/" element={isAuthenticated() ? <Navigate to="/dashboard" replace /> : <LandingPage />} />

        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/verify" element={<Verify />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
        <Route path="/f/:formLink" element={<FormRunnerPage />} />
        <Route path="/f/:formLink/result/:responseId" element={<FormResultPage />} />

        <Route path="/dashboard" element={<ProtectedRoute><UserHome /></ProtectedRoute>} />
        <Route path="/my-forms" element={<ProtectedRoute><MyForms /></ProtectedRoute>} />
        <Route path="/templates" element={<ProtectedRoute><TemplatesPage /></ProtectedRoute>} />

        {/* 2. UBAH DUA RUTE INI AGAR MEMANGGIL FormResponsesPage */}
        <Route path="/responses" element={<ProtectedRoute><FormResponsesPage /></ProtectedRoute>} />
        <Route path="/forms/:id/responses" element={<ProtectedRoute><FormResponsesPage /></ProtectedRoute>} />

        <Route path="/history" element={<ProtectedRoute><UserHistory /></ProtectedRoute>} />

        <Route path="/create-form" element={<ProtectedRoute><CreateForm /></ProtectedRoute>} />
        <Route path="/forms/:id/edit" element={<ProtectedRoute><FormBuilder /></ProtectedRoute>} />

        <Route path="/admin" element={<ProtectedRoute><AdminDashboardPage /></ProtectedRoute>} />
        <Route path="/ai-chat" element={<ProtectedRoute><AiChatPage /></ProtectedRoute>} />
        <Route path="/profile" element={<ProtectedRoute><ProfilePage /></ProtectedRoute>} />
      </Routes>
    </ErrorBoundary>
  );
}

export default App;