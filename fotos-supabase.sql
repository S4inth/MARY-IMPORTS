-- Execute no SQL Editor do mesmo projeto Supabase da MARY IMPORTS 2.0.
-- Atualização não destrutiva: preserva produtos e pedidos existentes.
alter table public.products add column if not exists image_url text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('product-photos','product-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
-- Fotos públicas para exibição na vitrine; somente admins autenticados podem enviar.
drop policy if exists "mary_photos_admin_insert" on storage.objects;
create policy "mary_photos_admin_insert" on storage.objects for insert to authenticated
with check (bucket_id='product-photos' and public.is_admin());
-- Sem update/delete de fotos pelo cliente: evita substituir arquivos em uso.
-- A troca de foto envia novo arquivo e atualiza image_url via RLS de products.
