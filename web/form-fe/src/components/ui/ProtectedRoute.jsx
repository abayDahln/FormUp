import { Navigate } from 'react-router-dom';
import { isAuthenticated } from '../../services/apiService';

/**
 * ProtectedRoute
 * Membungkus route yang membutuhkan autentikasi.
 * Jika user belum login (tidak ada token), redirect ke /login.
 */
export default function ProtectedRoute({ children }) {
    if (!isAuthenticated()) {
        return <Navigate to="/login" replace />;
    }
    return children;
}
