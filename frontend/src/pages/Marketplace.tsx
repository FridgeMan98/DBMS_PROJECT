import React, { useState, useEffect } from 'react';
import api from '../api';
import Cart from '../components/Cart';

interface Product {
  product_id: int;
  product_name: string;
  unit_price: number;
  seller_id: number;
  business_name: string;
  category_name: string;
  total_stock: number;
}

export default function Marketplace() {
  const [products, setProducts] = useState<Product[]>([]);
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [cartItems, setCartItems] = useState<any[]>([]);

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      const res = await api.get('/products');
      setProducts(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const addToCart = (product: Product) => {
    setCartItems(prev => {
      const existing = prev.find(item => item.product_id === product.product_id);
      if (existing) {
        return prev.map(item => 
          item.product_id === product.product_id 
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }
      return [...prev, { ...product, quantity: 1 }];
    });
    setIsCartOpen(true);
  };

  return (
    <div className="container">
      <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center'}}>
        <h2>Marketplace</h2>
        <button onClick={() => setIsCartOpen(true)}>
          Cart ({cartItems.reduce((acc, item) => acc + item.quantity, 0)})
        </button>
      </div>
      
      <div className="grid" style={{marginTop: '2rem'}}>
        {products.map(p => (
          <div key={p.product_id} className="card">
            <div style={{color: 'var(--text-muted)', fontSize: '0.8rem', marginBottom: '0.5rem'}}>{p.category_name} • {p.business_name}</div>
            <div className="card-title">{p.product_name}</div>
            <div className="card-price">₹{p.unit_price}</div>
            <div style={{marginBottom: '1rem', color: p.total_stock < 10 ? '#ff8800' : 'var(--text-muted)'}}>
              Stock: {p.total_stock} left
            </div>
            <button onClick={() => addToCart(p)} style={{marginTop: 'auto'}}>Add to Cart</button>
          </div>
        ))}
      </div>

      <Cart 
        isOpen={isCartOpen} 
        onClose={() => setIsCartOpen(false)} 
        items={cartItems} 
        setItems={setCartItems}
      />
    </div>
  );
}
