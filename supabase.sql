drop table if exists public.registos, public.encomendas, public.despesas,
  public.provedores, public.config, public.dias, public.lojas cascade;

create table public.lojas (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome text not null,
  cor text not null default '#22c55e',
  ativa boolean not null default true,
  criado_em timestamptz not null default now()
);

create table public.config (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  comissao_percent numeric(5,2) not null default 5,
  emergencia_percent numeric(5,2) not null default 40
);

create table public.dias (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data date not null,
  loja_id bigint references public.lojas(id) on delete restrict,
  encomendas integer not null default 0,
  faturacao numeric(10,2) not null default 0,
  publicidade numeric(10,2) not null default 0,
  envios numeric(10,2) not null default 0,
  taxas numeric(10,2) not null default 0,
  produto numeric(10,2) not null default 0,
  comissao_percent numeric(5,2) not null default 5,
  emergencia_percent numeric(5,2) not null default 40,
  notas text,
  criado_em timestamptz not null default now(),
  constraint dias_unico unique nulls not distinct (user_id, data, loja_id)
);

create index dias_user_data_idx on public.dias (user_id, data desc);

do $$
declare t text;
begin
  foreach t in array array['lojas','config','dias'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "so o dono" on public.%I for all to authenticated
         using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end $$;

grant select, insert, update, delete on public.lojas, public.config, public.dias to authenticated;
grant usage, select on all sequences in schema public to authenticated;

notify pgrst, 'reload schema';
