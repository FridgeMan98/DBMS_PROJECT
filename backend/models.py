from pydantic import BaseModel, EmailStr
from typing import List, Optional

class CustomerRegister(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    phone: str
    address_line: str
    city: str
    state_code: str
    pincode: str

class SellerRegister(BaseModel):
    business_name: str
    contact_email: EmailStr
    password: str
    contact_phone: str
    address_line: str
    city: str
    state_code: str
    pincode: str

class LoginRequest(BaseModel):
    email: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    role: str
    user_id: int

class CartItem(BaseModel):
    product_id: int
    quantity: int

class CheckoutRequest(BaseModel):
    cart_items: List[CartItem]
    payment_method: str = "credit_card"

class ProductCreate(BaseModel):
    product_name: str
    category_id: int
    unit_price: float
    weight_kg: float
    initial_stock: int
