--Amazon Database--
--Category Table--
CREATE TABLE category(
category_id INT PRIMARY KEY,
category_name VARCHAR(25)
);

--Customer Table--
CREATE TABLE customer(
customer_id INT PRIMARY KEY,
first_name VARCHAR(25),
last_name VARCHAR(25),
state VARCHAR(25),
address VARCHAR(15) DEFAULT ('unknown')
);

--Seller Table--
CREATE TABLE seller(
seller_id INT PRIMARY KEY,
seller_name VARCHAR(25),
origin VARCHAR(5)
);

--Alter seller table--
ALTER TABLE seller
ALTER COLUMN origin TYPE VARCHAR(20);

--Product Table--
CREATE TABLE products(
product_id INT PRIMARY KEY,
product_name VARCHAR(50),
price FLOAT,
COGS FLOAT,
category_id INT,  --FOREIGN KEY
CONSTRAINT product_fk_category FOREIGN KEY(category_id) REFERENCES category(category_id)
);

--Order Table--
CREATE TABLE orders(
order_id INT PRIMARY KEY,
order_date DATE,
order_status VARCHAR(20),
seller_id INT, --FOREIGN KEY
customer_id INT,  --FOREIGN KEY
CONSTRAINT order_fk_customer FOREIGN KEY(customer_id) REFERENCES customer(customer_id), 
CONSTRAINT order_fk_seller FOREIGN KEY(seller_id) REFERENCES seller(seller_id)
);

--Order Items Table--
CREATE TABLE order_items(
order_item_id INT PRIMARY KEY,
order_id INT, --FOREIGN KEY
product_id INT, --FOREIGN KEY
quantity INT,
price_per_unit FLOAT,
CONSTRAINT orderitems_fk_order FOREIGN KEY(order_id) REFERENCES orders(order_id),
CONSTRAINT orderitems_fk_product FOREIGN KEY(product_id) REFERENCES products(product_id)
);

--Payment Table--
CREATE TABLE payment(
payment_id INT PRIMARY KEY,
order_id INT, --FOREIGN KEY
payment_date DATE,
paymnet_status VARCHAR(20),
CONSTRAINT payment_fk_order FOREIGN KEY(order_id) REFERENCES orders(order_id)
);

--Shipping Table--
CREATE TABLE shipping(
shipping_id INT PRIMARY KEY,
order_id INT, --FOREIGN KEY
shipping_date DATE,
return_date DATE,
shipping_provder VARCHAR(15),
delivery_status VARCHAR(15),
CONSTRAINT shipping_fk_order FOREIGN KEY(order_id) REFERENCES orders(order_id)
);

--Inventory Table--
CREATE TABLE inventory(
inventory_id INT PRIMARY KEY,
warehouse_id INT,
product_id INT, --FOREIGN KEY
stock INT,
last_stock_date DATE,
CONSTRAINT inventory_fk_product FOREIGN KEY(product_id) REFERENCES products(product_id)
);