import React, { useState } from 'react';
import api from '../api';

export default function Login() {
  const [isSeller, setIsSeller] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    const endpoint = isSeller ? '/auth/seller/login' : '/auth/customer/login';
    
    try {
      const res = await api.post(endpoint, { email, password });
      localStorage.setItem('token', res.data.access_token);
      localStorage.setItem('role', res.data.role);
      localStorage.setItem('user_id', res.data.user_id);
      
      window.location.href = isSeller ? '/seller' : '/';
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Login failed');
    }
  };

  return (
    <div className="auth-container">
      <h2>{isSeller ? 'Seller Login' : 'Customer Login'}</h2>
      
      <div style={{display: 'flex', gap: '1rem', marginBottom: '2rem'}}>
        <button 
          className={!isSeller ? '' : 'outline'} 
          onClick={() => setIsSeller(false)}
          style={{flex: 1}}
        >Customer</button>
        <button 
          className={isSeller ? '' : 'outline'} 
          onClick={() => setIsSeller(true)}
          style={{flex: 1}}
        >Seller</button>
      </div>

      <form onSubmit={handleLogin}>
        <input 
          type="email" 
          placeholder="Email address" 
          value={email}
          onChange={e => setEmail(e.target.value)}
          required
        />
        <input 
          type="password" 
          placeholder="Password" 
          value={password}
          onChange={e => setPassword(e.target.value)}
          required
        />
        
        {error && <div style={{color: '#ff4444', marginBottom: '1rem'}}>{error}</div>}
        
        <button type="submit" style={{width: '100%'}}>Login</button>
      </form>
      
      <p style={{marginTop: '1rem', textAlign: 'center', color: 'var(--text-muted)'}}>
        Use the seed data emails (e.g. arjun.sharma@email.com or contact@techmart.in) and 'password123'
      </p>
    </div>
  );
}
