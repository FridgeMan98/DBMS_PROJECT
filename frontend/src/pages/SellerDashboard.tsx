import React, { useState, useEffect } from 'react';
import api from '../api';

export default function SellerDashboard() {
  const [categories, setCategories] = useState<any[]>([]);
  const [productName, setProductName] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [unitPrice, setUnitPrice] = useState('');
  const [weightKg, setWeightKg] = useState('');
  const [initialStock, setInitialStock] = useState('');
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    try {
      const res = await api.get('/categories');
      setCategories(res.data);
      if(res.data.length > 0) {
        setCategoryId(res.data[0].category_id.toString());
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleAddProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    const sellerId = localStorage.getItem('user_id');
    
    try {
      await api.post(`/seller/${sellerId}/products`, {
        product_name: productName,
        category_id: parseInt(categoryId),
        unit_price: parseFloat(unitPrice),
        weight_kg: parseFloat(weightKg),
        initial_stock: parseInt(initialStock)
      });
      
      setMessage('Product added successfully!');
      setProductName('');
      setUnitPrice('');
      setWeightKg('');
      setInitialStock('');
    } catch (err: any) {
      setMessage(err.response?.data?.detail || 'Failed to add product');
    }
  };

  return (
    <div className="container">
      <h2>Seller Dashboard</h2>
      <p style={{color: 'var(--text-muted)', marginBottom: '2rem'}}>
        Add new products to the catalog. Inventory will automatically default to your registered state warehouse.
      </p>

      <div className="card" style={{maxWidth: '600px'}}>
        <h3 style={{color: 'var(--primary-purple)'}}>Add New Product</h3>
        
        {message && (
          <div style={{padding: '1rem', background: message.includes('success') ? '#2e7d32' : '#ff4444', marginBottom: '1rem', borderRadius: '4px'}}>
            {message}
          </div>
        )}

        <form onSubmit={handleAddProduct}>
          <div>
            <label>Product Name</label>
            <input 
              type="text" 
              required 
              value={productName}
              onChange={e => setProductName(e.target.value)}
            />
          </div>
          
          <div>
            <label>Category</label>
            <select 
              value={categoryId} 
              onChange={e => setCategoryId(e.target.value)}
              required
            >
              {categories.map(c => (
                <option key={c.category_id} value={c.category_id}>
                  {c.category_name}
                </option>
              ))}
            </select>
          </div>

          <div style={{display: 'flex', gap: '1rem'}}>
            <div style={{flex: 1}}>
              <label>Unit Price (₹)</label>
              <input 
                type="number" 
                step="0.01" 
                required 
                value={unitPrice}
                onChange={e => setUnitPrice(e.target.value)}
              />
            </div>
            <div style={{flex: 1}}>
              <label>Weight (Kg)</label>
              <input 
                type="number" 
                step="0.001" 
                required 
                value={weightKg}
                onChange={e => setWeightKg(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label>Initial Stock Quantity</label>
            <input 
              type="number" 
              required 
              value={initialStock}
              onChange={e => setInitialStock(e.target.value)}
            />
          </div>

          <button type="submit" style={{marginTop: '1rem'}}>Add Product</button>
        </form>
      </div>
    </div>
  );
}
