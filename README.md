# MARY IMPORTS 2.0 — pedidos em tempo real

## Instalação (GitHub Pages + Supabase)

1. Crie um projeto no https://supabase.com.
2. No Supabase → SQL Editor, execute TODO o conteúdo de `supabase.sql` (projeto novo recomendado).
3. Em **Authentication → Users**, crie seu usuário administrador com e-mail e senha forte (não use a senha antiga que estava no JavaScript). Copie o **User UID**.
4. No SQL Editor, execute, substituindo pelo UID real:
   ```sql
   insert into public.staff(user_id,role,display_name)
   values ('SEU-USER-UID','admin','Administrador');
   ```
   A primeira autorização é feita pelo SQL Editor, pois nenhum usuário é administrador inicialmente.
5. Em **Project Settings → API / Connect**, copie a **Project URL** e a chave pública **anon/publishable** para `config.js`. NUNCA coloque a chave `service_role`/`secret` no site.
6. Publique os arquivos `index.html`, `style.css`, `app.js`, `config.js`, `sw.js`, `manifest.webmanifest`, `icon.svg` e `logo-mary-imports.webp` no GitHub Pages (não é necessário publicar o SQL).
7. Abra o site, clique em **Equipe** e entre com e-mail e senha. No painel, cadastre produtos e entregadores.
8. Para cada entregador, crie um usuário separado em **Authentication → Users**, copie o UID e use **Autorizar entregador** no painel. O entregador acessa a mesma página **Equipe**.
9. Teste um pedido como cliente em outro navegador. Ele deverá aparecer no painel; atribua um entregador, marque **Preparando** e o entregador poderá marcar **Saiu para entrega** e **Entregue**.

## Segurança e funcionamento

- Senhas são verificadas pelo Supabase Authentication; não existe PIN de administrador em `config.js`.
- As políticas RLS protegem pedidos, dados pessoais, equipe e alterações do catálogo. Clientes anônimos não podem listar pedidos.
- Pedidos anônimos são criados pela função `place_order`, que valida estoque e calcula preços no servidor, sem confiar nos valores do navegador.
- A confirmação do pedido acontece no banco; o link WhatsApp é opcional.
- Pedidos novos chegam ao painel por Supabase Realtime. Se a conexão cair, recarregue a página para sincronizar.
- O estoque é reduzido na confirmação. Cancelamentos não fazem reposição automática: ajuste o estoque manualmente quando necessário.
- A listagem mostra os 200 pedidos mais recentes; não é uma ferramenta de relatório histórico completo.
- O site exige internet para banco de dados e autenticação. O PWA não oferece checkout offline.
- A compra pública sem conta pode sofrer spam: antes de divulgação ampla, configure proteção contra abuso (CAPTCHA/rate limiting via Edge Function) e políticas de privacidade para dados de clientes.
- O SQL foi pensado para projeto Supabase novo. Revise conflitos se já houver tabelas com esses nomes.

## Dados preservados

Nome: MARY IMPORTS. WhatsApp: +55 62 9654-8587. Entrega: R$ 1,00. Logo e tema verde/dourado.

Os produtos locais da versão 1 não são migrados automaticamente; a nova versão cria os 10 produtos de exemplo do SQL. Para importar produtos personalizados, cadastre-os no novo painel.

## Fotos dos produtos (atualização 2.1)

1. No projeto Supabase já configurado, execute **somente** `fotos-supabase.sql` no SQL Editor. Não precisa executar novamente `supabase.sql`.
2. Publique os arquivos atualizados no GitHub Pages.
3. Entre como administrador em **Equipe → Produtos**, clique em **Escolher arquivo** e selecione uma imagem da galeria do celular ou do computador.
4. Confira a prévia e clique **Salvar produto**. A foto aparece no catálogo para todos os clientes.
5. Para trocar a foto, clique **Editar**, selecione uma nova imagem e salve. Se não selecionar nada, a foto anterior permanece.

Aceita JPG, PNG e WebP de até 5 MB. Fotos são públicas no bucket `product-photos`; não envie imagens privadas. O upload exige sessão admin e política de Storage. Arquivos antigos não são apagados automaticamente ao substituir fotos; faça limpeza manual no Storage se necessário.
