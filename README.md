# Mercadinho Delivery — versão inicial

Aplicativo web responsivo, instalável (PWA), com catálogo, carrinho, cálculo de entrega, checkout via WhatsApp, cadastro local de produtos e histórico local de pedidos.

## Como publicar grátis no GitHub Pages
1. Crie um repositório público no GitHub.
2. Envie os arquivos da pasta `mercadinho-delivery` para a raiz do repositório.
3. Em **Settings > Pages**, escolha **Deploy from a branch**, branch `main`, pasta `/ (root)` e salve.
4. Abra o endereço gerado e, no celular, escolha **Adicionar à tela inicial**.

## Antes de publicar
- Configuração inicial já personalizada em `config.js`: loja **Mercadinho Delivery**, WhatsApp **+55 62 9654-8587** (`556296548587`) e taxa fixa de entrega **R$ 1,00**.
- Confira se o número de WhatsApp informado está correto e ativo antes de publicar.
- Senha de demonstração: definida no arquivo `config.js` (não é autenticação segura). **Importante: o PIN fica visível no código-fonte e NÃO é uma autenticação segura.** Não use o painel local para dados confidenciais.
- Também é possível configurar a loja pelo painel, mas as alterações só aparecem no dispositivo/navegador que as realizou. Para configurar uma loja pública para todos, edite `config.js` antes de publicar.

## Limitações importantes
- Produtos, configurações e pedidos do painel são guardados no `localStorage` de cada navegador. **Não sincronizam entre dispositivos**.
- O pedido é encaminhado ao WhatsApp; o cliente precisa confirmar o envio na conversa. O painel do lojista não recebe pedidos automaticamente.
- O estoque não é reservado nem atualizado globalmente.
- O cálculo da taxa é fixo, não por bairro.
- Para ter autenticação real, sincronização de catálogo, estoque e pedidos, use um backend (por exemplo, Supabase) com regras RLS e papéis administrativos.
