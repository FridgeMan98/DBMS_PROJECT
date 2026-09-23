import React, { useState } from 'react';
import api from '../api';
import { X } from 'lucide-react';

interface CartProps {
  isOpen: boolean;
  onClose: () => void;
  items: any[];
  setItems: (items: any[]) => void;
}

export default function Cart({ isOpen, onClose, items, setItems }: CartProps) {
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const total = items.reduce((acc, item) => acc + (item.unit_price * item.quantity), 0);

  const handleCheckout = async () => {
    const userId = localStorage.getItem('user_id');
    if (!userId) {
      window.location.href = '/login';
      return;
    }

    setLoading(true);
    setMessage('');
    
    try {
      const cartItems = items.map(item => ({
        product_id: item.product_id,
        quantity: item.quantity
      }));
      
      const res = await api.post(`/customer/${userId}/checkout`, {
        cart_items: cartItems,
        payment_method: 'credit_card'
      });
      
      setMessage('Order placed successfully! Your items will be shipped soon.');
      setItems([]);
    } catch (err: any) {
      setMessage(err.response?.data?.detail || 'Checkout failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      {isOpen && <div className="cart-overlay" onClick={onClose} />}
      <div className={`cart-panel ${isOpen ? 'open' : ''}`}>
        <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem'}}>
          <h2>Your Cart</h2>
          <X onClick={onClose} style={{cursor: 'pointer'}} />
        </div>
        
        {message && (
          <div style={{padding: '1rem', background: message.includes('success') ? '#2e7d32' : '#ff4444', marginBottom: '1rem', borderRadius: '4px'}}>
            {message}
          </div>
        )}

        <div style={{flex: 1, overflowY: 'auto'}}>
          {items.length === 0 ? (
            <p style={{color: 'var(--text-muted)'}}>Cart is empty</p>
          ) : (
            items.map(item => (
              <div key={item.product_id} className="cart-item">
                <div>
                  <div style={{fontWeight: 'bold'}}>{item.product_name}</div>
                  <div style={{color: 'var(--text-muted)', fontSize: '0.9rem'}}>
                    Qty: {item.quantity} × ₹{item.unit_price}
                  </div>
                </div>
                <div style={{fontWeight: 'bold', color: 'var(--primary-purple)'}}>
                  ₹{item.quantity * item.unit_price}
                </div>
              </div>
            ))
          )}
        </div>

        <div className="cart-total">
          <div style={{display: 'flex', justifyContent: 'space-between', marginBottom: '1rem'}}>
            <span>Total:</span>
            <span>₹{total}</span>
          </div>
          <button 
            style={{width: '100%'}} 
            onClick={handleCheckout}
            disabled={items.length === 0 || loading}
          >
            {loading ? 'Processing...' : 'Checkout Now'}
          </button>
        </div>
      </div>
    </>
  );
}
