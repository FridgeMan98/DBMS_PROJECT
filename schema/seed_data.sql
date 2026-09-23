-- =============================================================
-- 03_seed_data.sql
-- Realistic seed data: states, customers, sellers, products,
-- categories, and inventory
-- =============================================================

-- -----------------------------------------------------------
-- STATES
-- -----------------------------------------------------------
INSERT INTO states (state_code, state_name, region) VALUES
('MH', 'Maharashtra',      'West'),
('DL', 'Delhi',            'North'),
('KA', 'Karnataka',        'South'),
('TN', 'Tamil Nadu',       'South'),
('WB', 'West Bengal',      'East'),
('GJ', 'Gujarat',          'West'),
('RJ', 'Rajasthan',        'North'),
('UP', 'Uttar Pradesh',    'North'),
('MP', 'Madhya Pradesh',   'Central'),
('AP', 'Andhra Pradesh',   'South');

-- -----------------------------------------------------------
-- CUSTOMERS (10)
-- -----------------------------------------------------------
INSERT INTO customers (first_name, last_name, email, phone, address_line, city, state_code, pincode) VALUES
('Arjun',   'Sharma',    'arjun.sharma@email.com',    '9876543210', '12 MG Road',         'Mumbai',    'MH', '400001'),
('Priya',   'Nair',      'priya.nair@email.com',      '9876543211', '45 Brigade Road',    'Bengaluru', 'KA', '560001'),
('Rohit',   'Verma',     'rohit.verma@email.com',     '9876543212', '7 Connaught Place',  'Delhi',     'DL', '110001'),
('Sneha',   'Pillai',    'sneha.pillai@email.com',    '9876543213', '23 Anna Salai',      'Chennai',   'TN', '600002'),
('Amit',    'Das',       'amit.das@email.com',        '9876543214', '89 Park Street',     'Kolkata',   'WB', '700016'),
('Kavya',   'Reddy',     'kavya.reddy@email.com',     '9876543215', '34 Banjara Hills',   'Hyderabad', 'AP', '500034'),
('Vikram',  'Patel',     'vikram.patel@email.com',    '9876543216', '56 CG Road',         'Ahmedabad', 'GJ', '380006'),
('Meera',   'Joshi',     'meera.joshi@email.com',     '9876543217', '78 MI Road',         'Jaipur',    'RJ', '302001'),
('Suresh',  'Kumar',     'suresh.kumar@email.com',    '9876543218', '11 Hazratganj',      'Lucknow',   'UP', '226001'),
('Divya',   'Singh',     'divya.singh@email.com',     '9876543219', '5 MP Nagar',         'Bhopal',    'MP', '462011');

-- -----------------------------------------------------------
-- SELLERS (5)
-- -----------------------------------------------------------
INSERT INTO sellers (business_name, contact_email, contact_phone, address_line, city, state_code, pincode, rating) VALUES
('TechMart India',      'contact@techmart.in',      '9000000001', 'Plot 12, MIDC',       'Pune',      'MH', '411018', 4.5),
('FashionHub',          'support@fashionhub.in',    '9000000002', '45 Garment District', 'Surat',     'GJ', '395003', 4.2),
('HomeEssentials',      'info@homeessentials.in',   '9000000003', '7 Industrial Area',   'Delhi',     'DL', '110020', 4.0),
('BookWorld',           'sales@bookworld.in',       '9000000004', '23 College Street',   'Kolkata',   'WB', '700073', 4.8),
('SportZone',           'help@sportzone.in',        '9000000005', '56 Koramangala',      'Bengaluru', 'KA', '560034', 4.3);

-- -----------------------------------------------------------
-- CATEGORIES
-- -----------------------------------------------------------
INSERT INTO categories (category_name, parent_id) VALUES
('Electronics',    NULL),   -- 1
('Mobile Phones',  1),      -- 2
('Laptops',        1),      -- 3
('Fashion',        NULL),   -- 4
('Men',            4),      -- 5
('Women',          4),      -- 6
('Home & Kitchen', NULL),   -- 7
('Books',          NULL),   -- 8
('Sports',         NULL);   -- 9

-- -----------------------------------------------------------
-- PRODUCTS (20)
-- -----------------------------------------------------------
INSERT INTO products (seller_id, category_id, product_name, unit_price, weight_kg) VALUES
-- TechMart (seller 1)
(1, 2, 'Samsung Galaxy S24',          79999.00, 0.167),
(1, 2, 'iPhone 15',                   89999.00, 0.171),
(1, 3, 'Dell Inspiron 15',            65000.00, 1.800),
(1, 3, 'HP Pavilion 14',              55000.00, 1.600),
(1, 1, 'Sony WH-1000XM5 Headphones', 28000.00, 0.250),
-- FashionHub (seller 2)
(2, 5, 'Men Slim Fit Jeans',           1299.00, 0.500),
(2, 5, 'Men Cotton Kurta',              899.00, 0.300),
(2, 6, 'Women Floral Kurta',           1099.00, 0.350),
(2, 6, 'Women Silk Saree',             3499.00, 0.800),
(2, 4, 'Unisex Casual Sneakers',       2499.00, 0.600),
-- HomeEssentials (seller 3)
(3, 7, 'Prestige Pressure Cooker 5L',  2799.00, 2.500),
(3, 7, 'Philips Air Fryer',            6499.00, 3.200),
(3, 7, 'Milton Thermosteel Bottle',     599.00, 0.450),
(3, 7, 'Cello Folding Table',          3999.00, 5.000),
(3, 7, 'Pigeon Induction Cooktop',     1999.00, 2.000),
-- BookWorld (seller 4)
(4, 8, 'The Alchemist - Paulo Coelho',  299.00, 0.200),
(4, 8, 'Atomic Habits - James Clear',   399.00, 0.250),
(4, 8, 'Wings of Fire - APJ Abdul Kalam',349.00, 0.220),
-- SportZone (seller 5)
(5, 9, 'Nivia Football Size 5',        1299.00, 0.450),
(5, 9, 'Cosco Badminton Racket Set',   1799.00, 0.350);

-- -----------------------------------------------------------
-- INVENTORY (products across warehouses)
-- -----------------------------------------------------------
INSERT INTO inventory (product_id, warehouse_state, stock_quantity, reorder_level) VALUES
-- Samsung Galaxy S24
(1, 'MH', 50,  5), (1, 'DL', 30,  5), (1, 'KA', 20,  5),
-- iPhone 15
(2, 'MH', 40,  5), (2, 'DL', 25,  5),
-- Dell Inspiron 15
(3, 'MH', 25,  3), (3, 'DL', 15,  3),
-- HP Pavilion 14
(4, 'MH', 30,  3), (4, 'KA', 20,  3),
-- Sony Headphones
(5, 'MH', 60,  5), (5, 'DL', 45,  5), (5, 'WB', 30,  5),
-- Men Jeans
(6, 'GJ',100, 10), (6, 'MH', 80, 10),
-- Men Kurta
(7, 'GJ',150, 15), (7, 'DL',100, 15),
-- Women Kurta
(8, 'GJ',120, 10), (8, 'MH', 90, 10),
-- Women Saree
(9, 'GJ', 70, 10), (9, 'TN', 50, 10),
-- Sneakers
(10,'GJ', 80, 10), (10,'MH', 60, 10),
-- Pressure Cooker
(11,'DL', 40,  5), (11,'UP', 35,  5),
-- Air Fryer
(12,'DL', 25,  5), (12,'MH', 20,  5),
-- Thermosteel Bottle
(13,'DL',200, 20), (13,'KA',150, 20),
-- Folding Table
(14,'DL', 30,  5), (14,'MH', 20,  5),
-- Induction Cooktop
(15,'DL', 50,  5), (15,'KA', 40,  5),
-- Books
(16,'WB',300, 30), (16,'DL',200, 30),
(17,'WB',250, 30), (17,'MH',150, 30),
(18,'WB',200, 30), (18,'TN',100, 30),
-- Sports
(19,'KA', 80, 10), (19,'MH', 60, 10),
(20,'KA', 70, 10), (20,'MH', 50, 10);

\echo '--> Seed data inserted successfully.'