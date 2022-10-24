--:::::::::::::::::::::::::::::::::::::::::::::Ejercicio 2):::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
/*
 Para cada una de las restricciones/reglas del negocio en el esquema de datos:
   - Escribir la restricción de la manera que considere más apropiada en SQL estándar declarativo, indicando su tipo y
   justificación correspondiente.
   - Para los 3 últimos controles (c, d, e), implementar la restricción en PostgreSQL de la forma más adecuada, según
   las posibilidades que ofrece el DBMS.
*/
--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--

--------------------------------------------- Ejercicio 2) a. ----------------------------------------------------------
/*
 Si una persona está inactiva debe tener establecida una fecha de baja, la cual se debe controlar que sea al menos 18
 años posterior a la de nacimiento.
*/
--Tipo: Al necesitar la restricción más de un atributo para definirse, se considera de tipo TUPLA
Alter table Persona
  add constraint checkPersonaMas18
    check (activo=true or (fecha_baja is not null and (fecha_baja - fecha_nacimiento) >= interval '18 years'));

--------------------------------------------- Ejercicio 2) b. ----------------------------------------------------------
/*
 El importe de un comprobante debe coincidir con la suma de los importes de sus líneas (si las tuviera).
*/
--Tipo: Al necesitar la restricción más de una tabla para definirse, se considera de tipo ASSERTION
CREATE ASSERTION importe_comprobante
  Check (NOT EXISTS (SELECT 1
                    FROM Comprobante c
                    JOIN LineaComprobante l  ON (c.id_comp,c.id_tcomp) = (l.id_comp,l.id_tcomp)
                    GROUP by c.id_comp, c.id_tcomp
                    HAVING sum(l.importe) != c.importe));


--------------------------------------------- Ejercicio 2) c. ----------------------------------------------------------
/*
 Un equipo puede tener asignada un IP, y en este caso, la MAC resulta requerida.
*/
--Tipo: Al necesitar la restricción más de un atributo para definirse, se considera de tipo TUPLA
Alter table Equipo
  add constraint checkEquipoIp
    check (ip is null OR mac is not null);

--Al ser una RI de tabla y no usar una query, es adecuado para postgreSQL.
/*
 c.d) Se considera que es válido que pueda tener MAC sin IP
*/

--------------------------------------------- Ejercicio 2) d. ----------------------------------------------------------
/*
 Las IPs asignadas a los equipos no pueden ser compartidas entre clientes.
*/
--Tipo: Al necesitar la restricción más de una tupla para definirse, se considera de tipo TABLA, no se puede usar una query para el check de postgreSQL, asique se utiliza un TRIGGER
Alter Table Equipo
  ADD CONSTRAINT chk_ip_cliente
    CHECK (not exists (SELECT 1
                       FROM equipo
  			 	       where ip is not null
                       GROUP BY ip
                       HAVING count(DISTINCT id_cliente) > 1));
/*
  Implementación para postgreSQL
  EQUIPO
  -UPDATE? si (id_cliente, ip)
  -DELETE? no
  -INSERT? si
*/
CREATE OR REPLACE FUNCTION FN_checkIpCompartida() RETURNS TRIGGER AS $$
begin
  if (EXISTs (SELECT 1
                FROM equipo e
    	  	    where e.ip = new.ip and e.id_cliente != new.id_cliente)) then
      raise exception 'No se puede tener ip compartida';
  end if;
  return new;
end$$ LANGUAGE 'plpgsql';

CREATE TRIGGER TG_ipCompartida
after INSERT OR UPDATE OF ip, id_cliente
ON equipo
FOR EACH ROW
EXECUTE PROCEDURE FN_checkIpCompartida();

--------------------------------------------- Ejercicio 2) e. ----------------------------------------------------------
/*
 No se pueden instalar más de 25 equipos por Barrio.
*/
--Tipo: Al necesitar la restricción más de una tabla para definirse, se considera de tipo ASSERTION. No está implementado assertion en postgreSQL, asique se utiliza un TRIGGER
CREATE ASSERTION Equipos_por_barrio
  Check (NOT EXISTs (SELECT 1
                     FROM direccion d
                     join persona p on d.id_persona = p.id_persona
                     join cliente cte on p.id_persona = cte.id_cliente
                     join equipo e on cte.id_cliente = e.id_cliente
                     GROUP BY d.id_barrio
                     HAVING  count(e.id_equipo) > 25));
/*
  Implementación para postgreSQL
  EQUIPO
  -UPDATE? si (id_cliente)
  -DELETE? no
  -INSERT? si
  DIRECCION
  -UPDATE? si (id_barrio,id_persona)
  -DELETE? no
  -INSERT? si
*/
CREATE OR REPLACE FUNCTION FN_cant_equipos25() RETURNS TRIGGER AS $$
declare
    tpl record;
begin
  if (tg_table_name = 'direccion') then  --si se modifica el id_barrio, id_persona, ambos o se hace una inserción en la tabla dirección, se revisa que el barrio siga teniendo menos de 25 equipos.
    if (25 < (SELECT count(distinct e.id_equipo)
              FROM (select id_persona FROM direccion where id_barrio = new.id_barrio) d
              join (select id_cliente, id_equipo from equipo) e on d.id_persona = e.id_cliente)) then
      raise exception 'No se puede hacer el update ya que genera que se exceda el límite de 25 equipos por barrio';
    end if;
  elseif (tg_table_name = 'equipo') then --si se modifica el cliente del equipo o se agrega un nuevo equipo, se revisa si el/los barrios de ese nuevo cliente ahora pasa los 25 equipos.
    for tpl in (select id_barrio from direccion where id_persona = new.id_cliente) loop
      if (25 < (SELECT count(distinct e.id_equipo)
                FROM (select d.id_persona FROM direccion d where d.id_barrio = tpl.id_barrio) d
                join (select id_cliente, id_equipo from equipo) e on d.id_persona = e.id_cliente)) then
        raise exception 'No se puede continuar ya que genera que se exceda el límite de 25 equipos por barrio';
      end if;
    end loop;
  end if;
  return new;
end$$ language 'plpgsql';

CREATE TRIGGER TG_cant_equipos25eq
AFTER INSERT OR UPDATE OF id_cliente
ON equipo
FOR EACH ROW
EXECUTE function FN_cant_equipos25();

CREATE TRIGGER TG_cant_equipos25dir
AFTER INSERT OR UPDATE OF id_barrio, id_persona
ON direccion
FOR EACH ROW
EXECUTE function FN_cant_equipos25();

/*
 2.e) Suponemos que los clientes sin dirección no son tomados en cuenta para la restricción ya que no se sabe si pertenecen al mismo barrio.
 También tomamos que, ya que el esquema lo permite, si un cliente tiene 2 o más direcciones, al agregar o modificar el id_cliente de un equipo,
 se deberá revisar que ninguno de los barrios de las distintas direcciones supere los 25 equipos.
*/

--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
--::::::::::::::::::::::::::::::::::::::::::::::::::FIN:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--












--copia vieja
CREATE OR REPLACE FUNCTION FN_cant_equipos25() RETURNS TRIGGER AS $$
begin
  if (NOT EXISTS (SELECT 1
                  FROM direccion d
                  join persona p on d.id_persona = p.id_persona
                  join cliente cte on p.id_persona = cte.id_cliente
                  join equipo e on cte.id_cliente = e.id_cliente
                  where d.id_barrio = new.id_barrio
                  GROUP BY d.id_barrio
                  HAVING  count(e.id_equipo) > 25)) then
    raise exception 'No se puede agregar el equipo dado que excede el límite de equipos por barrio';
  end if;
  return new;
end$$ language 'plpgsql';

SELECT distinct d.id_barrio, d.id_persona, id_equipo
                  FROM direccion d
                  join equipo e on d.id_persona = e.id_cliente
                  where d.id_barrio = 372;


SELECT d.id_barrio, d.id_persona , count(*) --, e.id_equipo
FROM direccion d
group by 1,2;
insert into direccion(id_direccion, id_persona, calle ,numero, piso, depto, id_barrio) values (2,1020,'calleX',235,null,null,372);
                  --where d.id_barrio = new.id_barrio




drop trigger tg_ipcompartida on equipo;
select ip, count (distinct id_cliente) from equipo group by 1;
select ip, id_cliente from equipo where id_equipo = 5301;

delete from equipo where id_equipo >= 5300;
insert into equipo (id_equipo, nombre, mac, id_servicio, fecha_alta, tipo_conexion, tipo_asignacion, ip, id_cliente)
values (5300, 'equipo76579', '27:34:27:46:6A:67', 501, '2020-10-20', ' ', ' ', '198.0.0.10', 1001); --"única" tupla en equipo
insert into equipo (id_equipo, nombre, mac, id_servicio, fecha_alta, tipo_conexion, tipo_asignacion, ip, id_cliente)
values (5301, 'equipo76579', '27:34:27:46:6A:67', 501, '2020-10-20', ' ', ' ', '198.0.0.10', 1001); --ingreso válido, misma ip, pero mismo id_cliente
insert into equipo (id_equipo, nombre, mac, id_servicio, fecha_alta, tipo_conexion, tipo_asignacion, ip, id_cliente)
values (5302, 'equipo76579', '27:34:27:46:6A:67', 501, '2020-10-20', ' ', ' ', '198.0.0.20', 1001); --ingreso válido, ip única
insert into equipo (id_equipo, nombre, mac, id_servicio, fecha_alta, tipo_conexion, tipo_asignacion, ip, id_cliente)
values (5303, 'equipo76579', '27:34:27:46:6A:67', 501, '2020-10-20', ' ', ' ', '198.0.0.10', 1010); --ingreso inválido, misma ip y distinto id_cliente
insert into equipo (id_equipo, nombre, mac, id_servicio, fecha_alta, tipo_conexion, tipo_asignacion, ip, id_cliente)
values (5304, 'equipo76579', '27:34:27:46:6A:67', 501, '2020-10-20', ' ', ' ', '198.0.0.30', 1010); --ingreso válido, ip única

--4 elementos en equipo (id_equipo, ip, id_cliente)
-- 5300 '198.0.0.10' 1001 -> 5300 '198.0.0.10' 1020
-- 5301 '198.0.0.10' 1001 -> 5301 '198.0.0.10' 1020 -/> 5301 '198.0.0.10' 1010 -> 5301 '198.0.0.15' 1020  -> 5301 '198.0.0.15' 1010
-- 5302 '198.0.0.20' 1010
-- 5304 '198.0.0.30' 1010

update equipo set id_cliente = 1020 where id_cliente = 1001; --update válido todas las ip de 1001 le pertenecerán a 1020
update equipo set id_cliente = 1010 where id_equipo = 5301; --update inválido, el equipo 5300 y 5301 tendrán la misma ip y distinto id_cliente
update equipo set ip = '198.0.0.15' where id_equipo = 5301; --update válido, solo porque no hay otro cliente con un equipo del nuevo ip
update equipo set id_cliente = 1010 where id_equipo = 5301; --update válido, solo porque el cliente 1096 no tenía más de un equipo con el mismo ip que el equipo 5301
update equipo set ip = '198.0.0.10' where id_equipo = 5301; --update inválido, el equipo 5300 y 5301 tendrán la misma ip y distinto id_cliente


drop trigger TG_prueba on equipo;
drop function FN_prueba();

CREATE OR REPLACE FUNCTION FN_prueba() RETURNS TRIGGER AS $$
begin
  if (new.id_cliente != 1) then
    raise exception 'old.id_cliente = %, old.ip = %, new.id_cliente = %, new.ip = %', old.id_cliente, old.ip, new.id_cliente, new.ip;
  end if;
  return new;
end$$ LANGUAGE 'plpgsql';


CREATE TRIGGER TG_prueba
before INSERT OR UPDATE OF ip, id_cliente
ON equipo
FOR EACH ROW
EXECUTE PROCEDURE FN_prueba();

delete from equipo where id_equipo = 5300;
insert into equipo (id_equipo, nombre, ip, mac, id_servicio, id_cliente, fecha_alta, tipo_conexion, tipo_asignacion)
values (5300, 'equipo76579', '198.10.4.29', '27:34:27:46:6A:67', 501, 1096, '2020-10-20', ' ', ' ');
update equipo set id_cliente = 1300 where id_cliente = 1001;








alter table persona drop constraint checkPersonaMas18;
delete from persona where id_persona = 1200;
insert into persona(id_persona, tipo, tipodoc, nrodoc, nombre, apellido, fecha_nacimiento,fecha_baja, activo)
values (1200, 'cliente', 'dni', 30399916, 'Roberto', 'Rodriguez', '2000-10-20','2020-10-20', true);
insert into persona(id_persona, tipo, tipodoc, nrodoc, nombre, apellido, fecha_nacimiento,fecha_baja, activo)
values (1200, 'cliente', 'dni', 30399916, 'Roberto', 'Rodriguez', '2000-10-20','2015-10-20', true);
insert into persona(id_persona, tipo, tipodoc, nrodoc, nombre, apellido, fecha_nacimiento,fecha_baja, activo)
values (1200, 'cliente', 'dni', 30399916, 'Roberto', 'Rodriguez', '2000-10-20', null       , true);
insert into persona(id_persona, tipo, tipodoc, nrodoc, nombre, apellido, fecha_nacimiento,fecha_baja, activo)
values (1200, 'cliente', 'dni', 30399916, 'Roberto', 'Rodriguez', '2000-10-20','2020-10-20', false);
insert into persona(id_persona, tipo, tipodoc, nrodoc, nombre, apellido, fecha_nacimiento,fecha_baja, activo)
values (1200, 'cliente', 'dni', 30399916, 'Roberto', 'Rodriguez', '2000-10-20','2015-10-20', false);
insert into persona(id_persona, tipo, tipodoc, nrodoc, nombre, apellido, fecha_nacimiento,fecha_baja, activo)
values (1200, 'cliente', 'dni', 30399916, 'Roberto', 'Rodriguez', '2000-10-20', null       , false);

select id_persona from persona where not (activo=true or (fecha_baja - fecha_nacimiento) >= interval '18 years');
select id_cliente from cliente where (FALSE or (null - interval '18 years' > interval '18 years')) limit 1;

delete from persona where not (activo=true or (fecha_baja - fecha_nacimiento) >= interval '18 years');

alter table equipo drop constraint checkEquipoIp;
delete from equipo where id_equipo = 5300;
insert into equipo (id_equipo, nombre, ip, mac, id_servicio, id_cliente, fecha_alta, tipo_conexion, tipo_asignacion)
values (5300, 'equipo76579', '198.10.4.29', '27:34:27:46:6A:67', 501, 1096, '2020-10-20', ' ', ' ');
insert into equipo (id_equipo, nombre, ip, mac, id_servicio, id_cliente, fecha_alta, tipo_conexion, tipo_asignacion)
values (5300, 'equipo76579', null         , '27:34:27:46:6A:67', 501, 1096, '2020-10-20', ' ', ' ');
insert into equipo (id_equipo, nombre, ip, mac, id_servicio, id_cliente, fecha_alta, tipo_conexion, tipo_asignacion)
values (5300, 'equipo76579', '198.10.4.29', null               , 501, 1096, '2020-10-20', ' ', ' ');
insert into equipo (id_equipo, nombre, ip, mac, id_servicio, id_cliente, fecha_alta, tipo_conexion, tipo_asignacion)
values (5300, 'equipo76579',null         , null                , 501, 1096, '2020-10-20', ' ', ' ');


select * from direccion where id_direccion < 100;

insert into direccion(id_direccion, id_persona, calle   , numero, id_barrio)
              values (     1     ,  1050     , 'calleX', 235   ,   372    );

--update direccion set id_barrio = 372 where id_direccion = 2 and id_persona = 1051;

insert into equipo (id_equipo, nombre, mac, ip, ap, id_servicio, id_cliente, fecha_alta, fecha_baja, tipo_conexion, tipo_asignacion) values (56, 'sdf',null,null,null,502,1050,'2000-12-12',null,'dfs','dsf');

update equipo set id_cliente = 1050 where id_equipo = 5024;

SELECT distinct d.id_barrio, d.id_persona, id_equipo
                  FROM direccion d
                  join equipo e on d.id_persona = e.id_cliente
                  where d.id_barrio = 372;

select * from equipo where id_cliente = 1050;
SELECT e.id_equipo
              FROM (select id_persona FROM direccion where id_barrio = 372) d
              join (select id_cliente, id_equipo from equipo) e on d.id_persona = e.id_cliente;

select id_cliente, count(*)
from equipo
group by 1;

delete from direccion where id_direccion < 20;