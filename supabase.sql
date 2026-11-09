-- MARY IMPORTS 2.0. Execute UMA vez no SQL Editor do Supabase.
create extension if not exists pgcrypto;
create table if not exists public.store_settings (id int primary key default 1 check (id=1), store_name text not null default 'MARY IMPORTS', whatsapp text not null default '556296548587', delivery_fee numeric(10,2) not null default 1 check(delivery_fee>=0));
insert into public.store_settings(id,store_name,whatsapp,delivery_fee) values(1,'MARY IMPORTS','556296548587',1) on conflict(id) do nothing;
create table if not exists public.staff (user_id uuid primary key references auth.users(id) on delete cascade, role text not null check(role in ('admin','courier')), display_name text not null, active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.products (id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120), category text not null, price numeric(10,2) not null check(price>=0), stock int not null check(stock>=0), emoji text not null default '📦', active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.orders (id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(), customer_name text not null, phone text not null, address text not null, district text not null, payment text not null check(payment in ('PIX','Dinheiro','Cartão na entrega')), notes text not null default '', subtotal numeric(10,2) not null, delivery_fee numeric(10,2) not null, total numeric(10,2) generated always as (subtotal+delivery_fee) stored, status text not null default 'Recebido' check(status in ('Recebido','Preparando','Saiu para entrega','Entregue','Cancelado')), courier_id uuid references public.staff(user_id) on delete set null);
create table if not exists public.order_items (id bigint generated always as identity primary key, order_id uuid not null references public.orders(id) on delete cascade, product_id uuid references public.products(id) on delete set null, product_name text not null, qty int not null check(qty>0), unit_price numeric(10,2) not null check(unit_price>=0));
create index if not exists idx_orders_created on public.orders(created_at desc);
create index if not exists idx_orders_courier on public.orders(courier_id);
create index if not exists idx_order_items_order on public.order_items(order_id);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.staff where user_id=(select auth.uid()) and role='admin' and active)$$;
create or replace function public.is_courier() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.staff where user_id=(select auth.uid()) and role='courier' and active)$$;
alter table public.store_settings enable row level security;
alter table public.staff enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
create policy settings_read on public.store_settings for select to anon,authenticated using(true);
create policy settings_admin on public.store_settings for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy staff_read on public.staff for select to authenticated using(public.is_admin() or user_id=(select auth.uid()));
create policy staff_admin_insert on public.staff for insert to authenticated with check(public.is_admin());
create policy staff_admin_update on public.staff for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy staff_admin_delete on public.staff for delete to authenticated using(public.is_admin());
create policy products_read on public.products for select to anon,authenticated using(active or public.is_admin());
create policy products_admin_insert on public.products for insert to authenticated with check(public.is_admin());
create policy products_admin_update on public.products for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy products_admin_delete on public.products for delete to authenticated using(public.is_admin());
create policy orders_read on public.orders for select to authenticated using(public.is_admin() or (public.is_courier() and courier_id=(select auth.uid())));
create policy orders_admin_update on public.orders for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy items_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (public.is_admin() or (public.is_courier() and o.courier_id=(select auth.uid())))));
-- No anonymous INSERT/SELECT for orders: public checkout goes through the validated RPC.
create or replace function public.place_order(p_customer_name text,p_phone text,p_address text,p_district text,p_payment text,p_notes text,p_items jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_order uuid; v_subtotal numeric(10,2):=0; v_fee numeric(10,2); v_item jsonb; v_id uuid; v_qty int; v_product public.products%rowtype; v_count int:=0;
begin
 if length(trim(coalesce(p_customer_name,''))) not between 2 and 120 or length(trim(coalesce(p_phone,''))) not between 8 and 30 or length(trim(coalesce(p_address,''))) not between 5 and 240 or length(trim(coalesce(p_district,''))) not between 2 and 120 or p_payment not in ('PIX','Dinheiro','Cartão na entrega') or length(coalesce(p_notes,''))>500 then raise exception 'Dados do cliente inválidos'; end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 50 then raise exception 'Carrinho inválido'; end if;
 -- Merge duplicate IDs, lock products in stable order to avoid deadlocks.
 for v_item in select jsonb_build_object('id',id,'qty',qty) from (select (x->>'id')::uuid id,sum((x->>'qty')::int) qty from jsonb_array_elements(p_items) x group by 1 order by 1) s loop
   v_id:=(v_item->>'id')::uuid; v_qty:=(v_item->>'qty')::int;
   if v_qty<1 or v_qty>100 then raise exception 'Quantidade inválida'; end if;
   select * into v_product from public.products where id=v_id and active for update;
   if not found or v_product.stock<v_qty then raise exception 'Produto indisponível ou estoque insuficiente'; end if;
   v_subtotal:=v_subtotal+v_product.price*v_qty; v_count:=v_count+1;
 end loop;
 if v_count=0 or v_subtotal>100000 then raise exception 'Pedido inválido'; end if;
 select delivery_fee into v_fee from public.store_settings where id=1;
 insert into public.orders(customer_name,phone,address,district,payment,notes,subtotal,delivery_fee)
 values(trim(p_customer_name),trim(p_phone),trim(p_address),trim(p_district),p_payment,trim(coalesce(p_notes,'')),v_subtotal,v_fee) returning id into v_order;
 for v_item in select jsonb_build_object('id',id,'qty',qty) from (select (x->>'id')::uuid id,sum((x->>'qty')::int) qty from jsonb_array_elements(p_items) x group by 1 order by 1) s loop
   v_id:=(v_item->>'id')::uuid; v_qty:=(v_item->>'qty')::int;
   select * into v_product from public.products where id=v_id;
   update public.products set stock=stock-v_qty where id=v_id;
   insert into public.order_items(order_id,product_id,product_name,qty,unit_price) values(v_order,v_id,v_product.name,v_qty,v_product.price);
 end loop;
 return v_order;
end $$;
-- Courier can only change the status of an order assigned to them.
create or replace function public.courier_update_status(p_order uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_courier() or p_status not in ('Saiu para entrega','Entregue') then raise exception 'Acesso negado'; end if;
 update public.orders set status=p_status where id=p_order and courier_id=(select auth.uid()) and ((status='Preparando' and p_status='Saiu para entrega') or (status='Saiu para entrega' and p_status='Entregue'));
 if not found then raise exception 'Pedido não atribuído ou transição inválida'; end if;
end $$;
revoke all on function public.place_order(text,text,text,text,text,text,jsonb) from public;
grant execute on function public.place_order(text,text,text,text,text,text,jsonb) to anon,authenticated;
revoke all on function public.courier_update_status(uuid,text) from public;
grant execute on function public.courier_update_status(uuid,text) to authenticated;
revoke all on function public.is_admin() from public;
revoke all on function public.is_courier() from public;
grant execute on function public.is_admin(),public.is_courier() to anon,authenticated;
-- Realtime: the authenticated courier/admin will receive only rows permitted by RLS.
do $$ begin alter publication supabase_realtime add table public.orders; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.products; exception when duplicate_object then null; end $$;
-- Seed only when product table is empty.
insert into public.products(name,category,price,stock,emoji)
select x.name,x.category,x.price,x.stock,x.emoji from (values
('Arroz 1kg','Mercearia',6.99,30,'🍚'),('Feijão 1kg','Mercearia',8.50,20,'🫘'),('Açúcar 1kg','Mercearia',4.99,25,'🍬'),('Café 250g','Mercearia',12.90,20,'☕'),('Leite 1L','Laticínios',6.50,18,'🥛'),('Pão francês (un.)','Padaria',0.90,50,'🥖'),('Ovos (dúzia)','Frios',13.90,15,'🥚'),('Refrigerante 2L','Bebidas',10.90,12,'🥤'),('Água mineral 1,5L','Bebidas',3.50,40,'💧'),('Sabão em pó 800g','Limpeza',11.90,15,'🧼')) x(name,category,price,stock,emoji)
where not exists(select 1 from public.products);
-- Após criar o usuário no Authentication, autorize-o no SQL Editor (troque UUID):
-- insert into public.staff(user_id,role,display_name) values('COLE-O-UID-AQUI','admin','Administrador');
-- Entregador: crie usuário no Authentication e, como admin, cadastre pelo painel.
