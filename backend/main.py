from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from datetime import timedelta
import json

from database import get_db_pool, close_db_pool
from auth import verify_password, get_password_hash, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
from models import CustomerRegister, SellerRegister, LoginRequest, CheckoutRequest, ProductCreate

app = FastAPI(title="E-Commerce API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    await get_db_pool()

@app.on_event("shutdown")
async def shutdown():
    await close_db_pool()


# ==========================================
# AUTHENTICATION
# ==========================================

@app.post("/auth/customer/login")
async def customer_login(req: LoginRequest):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow("SELECT customer_id, password_hash FROM customers WHERE email = $1", req.email)
        if not user or not verify_password(req.password, user['password_hash']):
            raise HTTPException(status_code=400, detail="Incorrect email or password")
        
        access_token = create_access_token(
            data={"sub": req.email, "role": "customer", "user_id": user['customer_id']},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        return {"access_token": access_token, "token_type": "bearer", "role": "customer", "user_id": user['customer_id']}

@app.post("/auth/seller/login")
async def seller_login(req: LoginRequest):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow("SELECT seller_id, password_hash FROM sellers WHERE contact_email = $1", req.email)
        if not user or not verify_password(req.password, user['password_hash']):
            raise HTTPException(status_code=400, detail="Incorrect email or password")
        
        access_token = create_access_token(
            data={"sub": req.email, "role": "seller", "user_id": user['seller_id']},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        return {"access_token": access_token, "token_type": "bearer", "role": "seller", "user_id": user['seller_id']}


# ==========================================
# PRODUCTS & CATALOG
# ==========================================

@app.get("/categories")
async def get_categories():
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        categories = await conn.fetch("SELECT category_id, category_name FROM categories ORDER BY category_name")
        return [dict(c) for c in categories]

@app.get("/products")
async def get_products():
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = """
            SELECT p.product_id, p.product_name, p.unit_price, p.seller_id, s.business_name, c.category_name,
                   COALESCE(SUM(i.stock_quantity), 0) as total_stock
            FROM products p
            JOIN sellers s ON p.seller_id = s.seller_id
            JOIN categories c ON p.category_id = c.category_id
            LEFT JOIN inventory i ON p.product_id = i.product_id
            WHERE p.is_active = TRUE
            GROUP BY p.product_id, s.business_name, c.category_name
            HAVING COALESCE(SUM(i.stock_quantity), 0) > 0
            ORDER BY p.product_id DESC;
        """
        products = await conn.fetch(query)
        return [dict(p) for p in products]

@app.post("/seller/{seller_id}/products")
async def create_product(seller_id: int, req: ProductCreate):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        # Fetch seller's state for the inventory
        seller = await conn.fetchrow("SELECT state_code FROM sellers WHERE seller_id = $1", seller_id)
        if not seller:
            raise HTTPException(status_code=404, detail="Seller not found")
        
        async with conn.transaction():
            # Insert product
            product_id = await conn.fetchval("""
                INSERT INTO products (seller_id, category_id, product_name, unit_price, weight_kg)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING product_id
            """, seller_id, req.category_id, req.product_name, req.unit_price, req.weight_kg)
            
            # Insert inventory
            await conn.execute("""
                INSERT INTO inventory (product_id, warehouse_state, stock_quantity)
                VALUES ($1, $2, $3)
            """, product_id, seller['state_code'], req.initial_stock)
            
        return {"success": True, "product_id": product_id}


# ==========================================
# CHECKOUT (Multi-Seller Split)
# ==========================================

@app.post("/customer/{customer_id}/checkout")
async def checkout(customer_id: int, req: CheckoutRequest):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        # Group cart items by seller
        seller_carts = {}
        for item in req.cart_items:
            product = await conn.fetchrow("SELECT seller_id FROM products WHERE product_id = $1", item.product_id)
            if not product:
                raise HTTPException(status_code=400, detail=f"Product {item.product_id} not found")
            seller_id = product['seller_id']
            if seller_id not in seller_carts:
                seller_carts[seller_id] = []
            seller_carts[seller_id].append((item.product_id, item.quantity))
        
        results = []
        async with conn.transaction():
            for seller_id, items in seller_carts.items():
                # Format for PostgreSQL composite type array: array['(prod_id, qty)', ...]::cart_item[]
                # In asyncpg, we can pass a list of tuples if the type is registered, but it's tricky.
                # A robust way is to build the query dynamically or use a temporary table/json.
                # Let's use json passing and a wrapper, or build the literal array string since it's safe ints.
                
                array_literals = []
                for p_id, qty in items:
                    array_literals.append(f"ROW({p_id},{qty})")
                
                array_str = "ARRAY[" + ",".join(array_literals) + "]::cart_item[]"
                
                query = f"""
                    SELECT * FROM process_order_checkout(
                        p_customer_id := $1,
                        p_cart_items := {array_str},
                        p_payment_method := $2,
                        p_transaction_ref := $3
                    );
                """
                
                try:
                    res = await conn.fetchrow(query, customer_id, req.payment_method, "SIMULATED_TXN")
                    results.append(dict(res))
                except asyncpg.exceptions.RaiseError as e:
                    raise HTTPException(status_code=400, detail=str(e))
                
        return {"success": True, "orders": results}
