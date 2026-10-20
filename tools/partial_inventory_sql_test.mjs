import {setup} from './club_staff_operations_sql_test.mjs';
import {apply,actor,call,id,coach,club,officer} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const migration=await readFile(new URL('../supabase/migrations/0137_partial_inventory_returns.sql',import.meta.url),'utf8');
async function start(){const f=await setup();await f.db.exec('reset role');await apply(f.db,migration);await apply(f.db,migration);await actor(f.db,coach);await f.db.exec('set role authenticated');return f.db;}
test('0137 partial good/damaged/missing returns preserve original quantity and stock',async()=>{const db=await start();try{
 const item=id(1801),a=id(1802);
 await call(db,'inventory_add_item',[item,club,'Top','ball',10]);await call(db,'inventory_assign',[a,item,8,coach]);
 await call(db,'inventory_return_partial',[id(1803),a,3,'returned']);
 await call(db,'inventory_return_partial',[id(1803),a,3,'returned']);
 let b=await call(db,'club_inventory_board',[club]);assert.equal(b.items[0].available,5);assert.equal(b.assignments[0].resolved_quantity,3);assert.equal(b.assignments[0].returned_at,null);
 await call(db,'inventory_assign',[id(1804),item,5,coach]);
 await call(db,'inventory_return_partial',[id(1805),a,2,'damaged']);
 await call(db,'inventory_return_partial',[id(1806),a,3,'missing']);
 b=await call(db,'club_inventory_board',[club]);assert.equal(b.items[0].available,0);assert.equal(b.items[0].damaged_quantity,2);assert.equal(b.items[0].missing_quantity,3);
 const closed=b.assignments.find(v=>v.id===a);assert.equal(closed.quantity,8);assert.equal(closed.resolved_quantity,8);assert.equal(closed.outcome,'mixed');assert.ok(closed.returned_at);
 assert.equal(closed.damaged_return_quantity,2);assert.equal(closed.missing_return_quantity,3);
 await assert.rejects(()=>call(db,'inventory_return_partial',[id(1807),a,1,'returned']),/miktarı/);
 await assert.rejects(()=>db.query('select * from club_inventory_returns'),/permission denied/);
 }finally{await db.close();}});
test('0137 invalid/reused operation, legacy remaining-return and authorization',async()=>{const db=await start();try{
 const item=id(1811),a=id(1812);await call(db,'inventory_add_item',[item,club,'Forma','kit',5]);await call(db,'inventory_assign',[a,item,5,coach]);
 await call(db,'inventory_return_partial',[id(1813),a,2,'returned']);
 await assert.rejects(()=>call(db,'inventory_return_partial',[id(1813),a,3,'returned']),/kimliği/);
 for(const qty of [null,0,-1,4])await assert.rejects(()=>call(db,'inventory_return_partial',[id(1814),a,qty,'returned']));
 await call(db,'inventory_return',[a,'damaged']);await call(db,'inventory_return',[a,'damaged']);
 const b=await call(db,'club_inventory_board',[club]);assert.equal(b.items[0].available,2);assert.equal(b.items[0].damaged_quantity,3);
 await actor(db,id(75));await assert.rejects(()=>call(db,'inventory_return_partial',[id(1815),a,1,'returned']),/sorumlusu/);
 await db.exec('reset role');await actor(db,officer);await db.exec('set role anon');await assert.rejects(()=>call(db,'inventory_return_partial',[id(1815),a,1,'returned']),/permission denied/);
 }finally{await db.close();}});
