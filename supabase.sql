-- =========================================================
--  LUCROS v2 — correr TUDO de uma vez no SQL Editor do Supabase
--  ATENÇÃO: a 1.ª linha apaga a tabela antiga "registos".
--  Se lá tiveres dados que queres guardar, apaga essa linha antes de correr.
-- =========================================================
drop table if exists public.registos;

-- Lojas
create table public.lojas (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome text not null,
  custo_capa numeric(10,2) not null default 0,      -- custo padrão por capa
  cor text not null default '#22c55e',
  ativa boolean not null default true,
  criado_em timestamptz not null default now()
);

-- Provedores de pagamento (PayPal, Shopify Payments, ...)
create table public.provedores (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome text not null,
  taxa_percent numeric(6,3) not null default 0,     -- ex.: 2.9 (%)
  taxa_fixa numeric(10,2) not null default 0,       -- ex.: 0.35 (€)
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- Encomendas
create table public.encomendas (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data date not null default current_date,
  numero text,                                      -- n.º da encomenda
  loja_id bigint not null references public.lojas(id) on delete restrict,
  provedor_id bigint references public.provedores(id) on delete set null,
  valor numeric(10,2) not null default 0,           -- total pago pelo cliente
  qtd_capas integer not null default 1,
  custo_capa numeric(10,2) not null default 0,      -- custo por capa
  custo_envio numeric(10,2) not null default 0,
  taxa numeric(10,2) not null default 0,            -- taxa do provedor
  outros_custos numeric(10,2) not null default 0,
  reembolso numeric(10,2) not null default 0,
  lucro numeric(10,2) generated always as
    (valor - reembolso - taxa - qtd_capas * custo_capa - custo_envio - outros_custos) stored,
  notas text,
  criado_em timestamptz not null default now()
);

-- Despesas que não são de uma encomenda (anúncios, apps, material...)
create table public.despesas (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data date not null default current_date,
  loja_id bigint references public.lojas(id) on delete set null,   -- vazio = geral
  categoria text not null default 'Anúncios',
  valor numeric(10,2) not null default 0,
  notas text,
  criado_em timestamptz not null default now()
);

-- Definições (fundo de reserva)
create table public.config (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  reserva_percent numeric(5,2) not null default 0
);

create index encomendas_user_data_idx on public.encomendas (user_id, data desc);
create index despesas_user_data_idx on public.despesas (user_id, data desc);

-- Segurança: cada utilizador só vê e mexe no que é seu
do $$
declare t text;
begin
  foreach t in array array['lojas','provedores','encomendas','despesas','config'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "so o dono" on public.%I for all to authenticated
         using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end $$;

grant select, insert, update, delete
  on public.lojas, public.provedores, public.encomendas, public.despesas, public.config
  to authenticated;
grant usage, select on all sequences in schema public to authenticated;
