--:::::::::::::::::::::::::::::::::::::::::::::Ejercicio 3):::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
/*
 Escribir la sentencia SQL para crear las vistas detalladas a continuación. Indicar y justificar si es actualizable o no
 en PostgreSQL, indicando la/s causa/s (Importante: siempre que sea posible, se deberán generar vistas automáticamente
 actualizables para PostgreSQL).
  - Para la/s vista/s actualizable/s, provea una sentencia que provoque diferente comportamiento según la vista tenga o
    no especificada la opción With Check Option, y analice dichos comportamientos.
  - Para una de la/s vista/s no actualizable/s, implemente los triggers instead of necesarios para su actualización.
    Plantee una sentencia que provoque su activación y explique la propagación de dicha actualización.
*/
--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
--------------------------------------------- Ejercicio 3) a. ----------------------------------------------------------
/*
 Realice una vista que contenga el saldo de cada uno de los clientes que tengan domicilio en la ciudad ‘X’.
*/
--La siguiente sentencia es automáticamente actualizable en PostgreSQL ya que muestra únicamente elementos de una tabla (Esto permite que haya
--una forma de hacerla actualizable, sin embargo si se usan ensambles, distinct, funciones de agregación, campos calculados,
--tampoco podría haber sido actualizable) e incluye todos los elementos no nulos de esta. Por lo que se podría modificar, insertar
--o eliminar como a la tabla que se le hace referencia.
CREATE OR REPLACE VIEW saldoClientes AS
SELECT id_cliente, saldo
FROM cliente
WHERE id_cliente IN (
    SELECT id_persona
    FROM direccion
    WHERE id_barrio IN (
        SELECT id_barrio
        FROM barrio
        WHERE id_ciudad IN (
            SELECT id_ciudad
            FROM ciudad
            WHERE nombre = 'X')));
--EJEMPLO!
--Tabla DIRECCION (id_persona, id_barrio, ...) contiene (100,200,...) (101,201,...)
--Tabla BARRIO (id_barrio, id_ciudad, ...) contiene (200,300,...) (201,301,...)
--Tabla CIUDAD (id_ciudad, nombre) contiene (300,'X') (301,'Y')

--SIN CHECK OPTION
insert into saldoClientes (id_cliente, saldo) values (100, 5000);
  --Sin importar los valores, siempre y cuando no vaya en contra de alguna restricción se inserta normalmente,
  --ya que la vista no checkea que sea parte de la consulta. En este caso el cliente tiene un domicilio en la ciudad 'X'
  --por lo tanto se incluira en la tabla cliente y en la vista saldoCliente
insert into saldoClientes (id_cliente, saldo) values (101, 5000);
  --En este caso se incluiría en la tabla cliente pero no en la vista ya que no tiene domicilio en la ciudad 'X'
delete from saldoClientes where id_cliente = 101;
  --No podría eliminarse ya que no es visible en la vista saldoClientes. En el caso de que el cliente fuese 100 si.
update saldoClientes set saldo = 1000 where id_cliente = 100;
  --Se podría actualizar por las mismas razones que se mencionan en el caso de eliminar.

--CON CHECK OPTION
insert into saldoClientes (id_cliente, saldo) values (100, 5000);
  --En este caso se insertará porque aparecería en la vista
insert into saldoClientes (id_cliente, saldo) values (101, 5000);
  --En este caso el check no le permitiría insertar la tupla ya que no tiene domicilio en la ciudad 'X', tampoco en la
  --tabla cliente.
delete from saldoClientes where id_cliente = 101;
  --Funciona igual que en el caso de no tener check option
update saldoClientes set saldo = 1000 where id_cliente = 100;
  --Funciona igual que en el caso de no tener check option


--------------------------------------------- Ejercicio 3) b. ----------------------------------------------------------
/*
 Realice una vista con la lista de servicios activos que posee cada cliente junto con el costo del mismo al momento de consultar la vista.
*/
/*La siguiente sentencia NO es actualizable en PostgreSQL ya que necesita mostrar elementos de dos tablas. Por lo que para que sea
  actualizable se le debería implementar trigger instead of para incluir un funcionamiento de las sentencias insert, update o delete.
  Además no posee todos los atributos necesarios para una inserción en las tablas que utiliza por lo que habria que incluirlos en
  la vista para hacerla actualizable en caso de insert.*/
CREATE OR REPLACE VIEW serviciosPorCliente AS
SELECT DISTINCT s.id_servicio, s.costo, e.id_cliente
FROM servicio s
JOIN (select id_cliente, id_servicio from equipo) e ON s.id_servicio = e.id_servicio
WHERE s.activo is True
ORDER BY id_cliente;

--VISTA REFORMULADA PARA EL TRIGGER
CREATE OR REPLACE VIEW serviciosPorClienteTG AS
SELECT DISTINCT s.id_servicio, s.nombre, s.periodico, id_cat, s.costo, e.id_cliente
FROM servicio s
JOIN (select id_cliente, id_servicio from equipo) e ON s.id_servicio = e.id_servicio
WHERE s.activo is True
ORDER BY id_cliente;

CREATE OR REPLACE FUNCTION FN_ServiciosPorCliente() RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        DELETE FROM equipo WHERE id_cliente = old.id_cliente;
        DELETE FROM servicio WHERE id_servicio = old.id_servicio;
        RETURN old;
    ELSEIF (TG_OP = 'INSERT') THEN
        INSERT INTO servicio (id_servicio, nombre, periodico, costo, activo, id_cat)
            VALUES (new.id_servicio, new.nombre, new.periodico, new.costo, true, new.id_cat);
        INSERT INTO equipo (id_equipo, nombre, id_servicio, id_cliente, fecha_alta, tipo_conexion, tipo_asignacion)
            VALUES ((SELECT MAX(id_equipo)+1 from equipo), 'equipo default', new.id_servicio, new.id_cliente, current_timestamp, 'PPTP', 'DHCP');
        RETURN new;
    ELSEIF (TG_OP = 'UPDATE') THEN
        UPDATE servicio SET id_servicio = new.id_servicio, nombre = new.nombre, periodico = new.periodico, costo = new.costo, intervalo = new.intervalo,
                            tipo_intervalo = new.tipo_intervalo, activo = new.activo, id_cat = new.id_cat where id_servicio = old.id_servicio;
        UPDATE equipo SET id_servicio = new.id_servicio where id_cliente = old.id_cliente and id_servicio = old.id_servicio;
        RETURN new;
    END IF;
END$$ LANGUAGE 'plpgsql';

CREATE TRIGGER TG_ServiciosPorCliente
INSTEAD OF INSERT OR UPDATE OR DELETE
ON serviciosPorClienteTG
FOR EACH ROW
EXECUTE FUNCTION FN_ServiciosPorCliente();

--SENTENCIA QUE ACTIVA EL TRIGGER
insert into serviciosPorClienteTG (id_servicio, nombre, periodico, id_cat, costo, id_cliente) values (511,'servicioX',true,501,200,1001);
/*Suponiendo que existe la categoria y el cliente, esta sentencia llama al trigger que ejecuta la función FN_ServiciosPorCliente la
  cual nota que la operación es un insert y crea el servicio con los datos del insert, sin contar con los valores que pueden ser null
  (agregarlos dependería solo de si se considera necesario) y se lo pone al servicio como activo. Luego se crea el equipo utilizando
  uno por defecto, con los datos importantes del insert.*/

/*
 3.b) Suponemos que por servicios activos se refiere a los servicios referentes a los equipos. Suponemos que a la hora de insertar una tupla a la
 vista, se utiliza un equipo por default para el nuevo servicio. Aunque no se implementó el trigger instead of como si la vista tuviera with check option
 funciona de esa manera ya que no se le da la posibilidad de insertar una tupla que no aparezca en la vista.
*/

--------------------------------------------- Ejercicio 3) c. ----------------------------------------------------------
/*
 Realice una vista que contenga, por cada uno de los servicios periódicos registrados, el monto facturado mensualmente durante los últimos 5 años ordenado por servicio, año, mes y monto.
*/
/*La siguiente sentencia NO es actualizable en PostgreSQL ya que necesita mostrar elementos de dos tablas. Ademas utiliza fragmentos
  de atributos y la función suma, por lo que para este caso no tendría mucho sentido buscar que sea automaticamente actualizable.*/
CREATE OR REPLACE VIEW ServiciosMontoMensual AS
SELECT s.id_servicio, extract(year from c.fecha) Año, extract(month from c.fecha) Mes, sum(lc.importe) Monto
FROM servicio s
  JOIN (select id_servicio, id_comp, id_tcomp, importe from lineacomprobante) lc ON s.id_servicio = lc.id_servicio
  JOIN (select id_comp, id_tcomp, fecha from comprobante where id_tcomp in (select id_tcomp from tipocomprobante where nombre = 'factura')) c ON (c.id_comp,c.id_tcomp) = (lc.id_comp,lc.id_tcomp)
WHERE s.periodico = true and  c.fecha > current_date - interval '5 years'
GROUP BY 1,2,3
ORDER BY 1,2,3,4;

--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
--::::::::::::::::::::::::::::::::::::::::::::::::::FIN:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--



















drop trigger tg_serviciosporcliente on serviciosPorClienteTG;
drop view serviciosPorClienteTG;

select * from serviciosPorClienteTG order by id_cliente;
insert into serviciosPorClienteTG (id_servicio, nombre, periodico, id_cat, costo, id_cliente)
              values (540,'servicio1',true,512,200,1054);

select * from servicio where id_servicio = 540;

select * from equipo where id_cliente = 1054;

update serviciosPorClienteTG set nombre = nombre || 'Act';

delete from serviciosPorClienteTG where id_servicio = 540;
delete from servicio where id_servicio = 540;