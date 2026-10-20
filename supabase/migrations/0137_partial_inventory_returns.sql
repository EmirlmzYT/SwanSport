set local lock_timeout = '15s';
alter table public.club_inventory_assignments add column if not exists resolved_quantity int not null default 0;
update public.club_inventory_assignments set resolved_quantity=quantity where returned_at is not null and resolved_quantity=0;
do $$begin
 alter table public.club_inventory_assignments add constraint inventory_resolved_bounds check(resolved_quantity between 0 and quantity);
exception when duplicate_object then null;end $$;
alter table public.club_inventory_assignments drop constraint if exists club_inventory_assignments_outcome_check;
alter table public.club_inventory_assignments add constraint club_inventory_assignments_outcome_check check(outcome in ('pending','returned','damaged','missing','mixed'));

create table if not exists public.club_inventory_returns (
 op_id uuid primary key,assignment_id uuid not null references public.club_inventory_assignments(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 quantity int not null check(quantity>0),outcome text not null check(outcome in ('returned','damaged','missing')),
 recorded_at timestamptz not null default clock_timestamp()
);
alter table public.club_inventory_returns enable row level security;
revoke all on public.club_inventory_returns from public,anon,authenticated;

create or replace function public.inventory_return_partial(p_op uuid,p_assignment uuid,p_quantity int,p_outcome text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare i club_inventory_items;a club_inventory_assignments;r club_inventory_returns;used_outcomes int;
begin
 select * into a from club_inventory_assignments where id=p_assignment;
 select * into i from club_inventory_items where id=a.item_id;
 if auth.uid() is null or not coalesce(_inventory_write(i.club_id),false) then
  raise exception 'Aktif kulüp yöneticisi/malzeme sorumlusu gerekli' using errcode='42501';
 end if;
 perform 1 from profiles where id in(auth.uid(),i.created_by,a.created_by,a.assigned_to_profile_id) order by id for key share;
 if a.assigned_to_team_id is not null then perform 1 from teams where id=a.assigned_to_team_id for key share;end if;
 perform _inventory_require(i.club_id);
 perform 1 from club_inventory_items where id=i.id for update;
 select * into a from club_inventory_assignments where id=p_assignment for update;
 select * into r from club_inventory_returns where op_id=p_op;
 if found then
  if (r.assignment_id,r.actor_id,r.quantity,r.outcome) is distinct from (p_assignment,auth.uid(),p_quantity,p_outcome) then
   raise exception 'İşlem kimliği farklı iadeye ait' using errcode='22023';
  end if;return;
 end if;
 if p_op is null or p_quantity is null or p_quantity<=0 or p_quantity>a.quantity-a.resolved_quantity or
 p_outcome is null or p_outcome not in ('returned','damaged','missing') then
  raise exception 'İade miktarı kalan zimmeti aşamaz; geçerli sonuç gerekli' using errcode='22023';
 end if;
 insert into club_inventory_returns(op_id,assignment_id,actor_id,quantity,outcome) values(p_op,a.id,auth.uid(),p_quantity,p_outcome);
 select count(distinct outcome) into used_outcomes from club_inventory_returns where assignment_id=a.id;
 update club_inventory_assignments set resolved_quantity=resolved_quantity+p_quantity,
  returned_at=case when resolved_quantity+p_quantity=quantity then clock_timestamp() end,
  outcome=case when resolved_quantity+p_quantity<quantity then 'pending' when used_outcomes>1 then 'mixed' else p_outcome end where id=a.id;
 update club_inventory_items set damaged_quantity=damaged_quantity+case when p_outcome='damaged' then p_quantity else 0 end,
 missing_quantity=missing_quantity+case when p_outcome='missing' then p_quantity else 0 end where id=i.id;
 insert into club_inventory_audit(club_id,actor_id,action,entity_id,detail) values(i.club_id,auth.uid(),'partial_return',a.id,
 jsonb_build_object('op_id',p_op,'quantity',p_quantity,'outcome',p_outcome));
end $$;
revoke all on function public.inventory_return_partial(uuid,uuid,int,text) from public,anon;
grant execute on function public.inventory_return_partial(uuid,uuid,int,text) to authenticated;

-- Keep the old full-return API for older clients; it only resolves the remainder.
create or replace function public.inventory_return(p_assignment uuid,p_outcome text default 'returned')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare a club_inventory_assignments;c uuid;r club_inventory_returns;i club_inventory_items;
begin
 select * into a from club_inventory_assignments where id=p_assignment;
 select * into i from club_inventory_items where id=a.item_id;c:=i.club_id;
 if auth.uid() is null or not coalesce(_inventory_write(c),false) then
  raise exception 'Aktif kulüp yöneticisi/malzeme sorumlusu gerekli' using errcode='42501';end if;
 perform 1 from profiles where id in(auth.uid(),i.created_by,a.created_by,a.assigned_to_profile_id) order by id for key share;
 if a.assigned_to_team_id is not null then perform 1 from teams where id=a.assigned_to_team_id for key share;end if;
 perform _inventory_require(c);
 select * into r from club_inventory_returns where op_id=p_assignment;
 if found then
  if (r.assignment_id,r.actor_id,r.outcome) is distinct from (p_assignment,auth.uid(),p_outcome) then
   raise exception 'Zimmet farklı sonuçla kapanmış' using errcode='55000';
  end if;return;
 end if;
 if a.returned_at is not null then
  if a.outcome is distinct from p_outcome then raise exception 'Zimmet farklı sonuçla kapanmış' using errcode='55000';end if;return;
 end if;
 perform inventory_return_partial(p_assignment,p_assignment,a.quantity-a.resolved_quantity,p_outcome);
end $$;

insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Zimmetin yalnız bir kısmını nasıl iade alırım?',
 'Malzeme ve Zimmet ekranında İade Al, Hasarlı veya Eksik seçeneğini aç; kalan miktarın tamamı yerine teslim alınan adedi yaz. Sağlam iade kullanılabilir stoğa döner, hasarlı ve kayıp adetler dönmez. Kalan miktar zimmette kalır. Farklı sonuçlarla kapanan zimmet karma olarak gösterilir. Belirsiz yanıtta aynı işlemi yeniden dene; ikinci kez stok işlemez. Eski istemcinin tam iade seçeneği yalnız kalan adedi kapatır.',
 'Kulüp','club_staff',213,'/kulup/malzeme-zimmet','club_staff_operations'
where not exists(select 1 from public.faq_entries where question='Zimmetin yalnız bir kısmını nasıl iade alırım?');

create or replace function public.inventory_assign(p_id uuid,p_item uuid,p_quantity int,p_profile uuid default null,p_team uuid default null,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i club_inventory_items;a club_inventory_assignments;used int;begin
 select club_id into i.club_id from club_inventory_items where id=p_item;
 if not public._inventory_write(i.club_id) then raise exception 'Aktif kulüp yöneticisi/malzeme sorumlusu gerekli' using errcode='42501';end if;
 -- Parent FK locks precede the item/assignment row locks (account deletion).
 perform 1 from profiles where id in(auth.uid(),p_profile,(select created_by from club_inventory_items where id=p_item)) order by id for key share;
 if p_team is not null then perform 1 from teams where id=p_team for key share;end if;
 perform public._inventory_require(i.club_id);
 select * into i from club_inventory_items where id=p_item for update;
 if i.id is null then raise exception 'Malzeme erişilemez' using errcode='42501'; end if;
 select * into a from club_inventory_assignments where id=p_id;
 if found then
  if (a.item_id,a.quantity,a.assigned_to_profile_id,a.assigned_to_team_id,a.notes,a.created_by) is distinct from
   (p_item,p_quantity,p_profile,p_team,p_notes,auth.uid()) then raise exception 'İşlem kimliği farklı zimmete ait' using errcode='22023'; end if;return a.id;
 end if;
 if p_quantity is null or p_quantity<=0 or (p_profile is null)=(p_team is null) or i.status<>'active' then raise exception 'Tek hedef ve pozitif miktar gerekli' using errcode='22023'; end if;
 if p_profile is not null then
  perform 1 from club_memberships where club_id=i.club_id and profile_id=p_profile and status='active' for share;
  if not found then raise exception 'Hedef aktif kulüp üyesi olmalı' using errcode='22023'; end if;
 else
  perform 1 from teams where id=p_team and club_id=i.club_id for share;
  if not found then raise exception 'Hedef takım aynı kulüpte olmalı' using errcode='22023'; end if;
 end if;
 select coalesce(sum(quantity-resolved_quantity),0) into used from club_inventory_assignments where item_id=i.id and returned_at is null;
 if p_quantity>i.quantity-i.damaged_quantity-i.missing_quantity-used then raise exception 'Kullanılabilir stok yetersiz' using errcode='22023'; end if;
 insert into club_inventory_assignments(id,item_id,assigned_to_profile_id,assigned_to_team_id,quantity,notes,created_by)
 values(p_id,i.id,p_profile,p_team,p_quantity,p_notes,auth.uid());
 insert into club_inventory_audit(club_id,actor_id,action,entity_id,detail) values(i.club_id,auth.uid(),'assigned',p_id,jsonb_build_object('quantity',p_quantity));return p_id;
end $$;

create or replace function public.club_inventory_board(p_club uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ begin
 if not public._inventory_read(p_club) then raise exception 'Kulüp envanter yetkisi gerekli' using errcode='42501'; end if;
 return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(q)) from (
  select i.*,i.quantity-i.damaged_quantity-i.missing_quantity-coalesce((select sum(a.quantity-a.resolved_quantity) from club_inventory_assignments a where a.item_id=i.id and a.returned_at is null),0) available
  from club_inventory_items i where club_id=p_club order by name,id) q),'[]'::jsonb),
 'assignments',coalesce((select jsonb_agg(to_jsonb(q)) from (select a.*,coalesce((select sum(r.quantity) from club_inventory_returns r where r.assignment_id=a.id and r.outcome='damaged'),case when a.outcome='damaged' then a.quantity else 0 end) damaged_return_quantity,coalesce((select sum(r.quantity) from club_inventory_returns r where r.assignment_id=a.id and r.outcome='missing'),case when a.outcome='missing' then a.quantity else 0 end) missing_return_quantity,coalesce(t.name,public.athlete_ref(a.assigned_to_profile_id),'Silinmiş hedef') target_reference,
  i.name item_name from club_inventory_assignments a join club_inventory_items i on i.id=a.item_id left join teams t on t.id=a.assigned_to_team_id
  where i.club_id=p_club order by a.assigned_at desc,a.id) q),'[]'::jsonb),
 'targets',coalesce((select jsonb_agg(to_jsonb(q)) from (
  select distinct m.profile_id id,'profile'::text kind,public.athlete_ref(m.profile_id) label from club_memberships m where m.club_id=p_club and m.status='active'
  union all select t.id,'team',t.name from teams t where t.club_id=p_club) q),'[]'::jsonb));
end $$;
