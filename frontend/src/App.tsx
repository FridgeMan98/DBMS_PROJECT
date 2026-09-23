import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import Login from './pages/Login';
import Marketplace from './pages/Marketplace';
import SellerDashboard from './pages/SellerDashboard';

function App() {
  const role = localStorage.getItem('role');

  const logout = () => {
    localStorage.clear();
    window.location.href = '/login';
  };

  return (
    <Router>
      <div className="navbar">
        <Link to="/" className="navbar-brand">E-Commerce</Link>
        <div className="nav-links">
          {!role && <Link to="/login">Login</Link>}
          {role === 'customer' && <Link to="/">Marketplace</Link>}
          {role === 'seller' && <Link to="/seller">Dashboard</Link>}
          {role && <button className="outline" onClick={logout} style={{padding: '0.5rem 1rem'}}>Logout</button>}
        </div>
      </div>
      
      <Routes>
        <Route path="/" element={<Marketplace />} />
        <Route path="/login" element={<Login />} />
        <Route path="/seller" element={<SellerDashboard />} />
      </Routes>
    </Router>
  );
}

export default App;
