--:::::::::::::::::::::::::::::::::::::::::::::Ejercicio 1):::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
/*
 Resolver las siguientes consultas SQL:
*/
--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--

--------------------------------------------- Ejercicio 1) a. ----------------------------------------------------------
/*
 Mostrar el listado de todos los clientes registrados en el sistema (id, apellido y nombre, tipo y número de documento,
 fecha de nacimiento) junto con la cantidad de equipos registrados que cada uno dispone, ordenado por apellido y nombre.
*/
SELECT p.id_persona, p.apellido, p.nombre, p.tipodoc, p.nrodoc, p.fecha_nacimiento, count(e.id_equipo)
FROM persona p
JOIN (SELECT id_cliente FROM cliente) c ON p.id_persona = c.id_cliente                --no puedo obviar esta tabla ya que si no aparecerá el personal también
LEFT JOIN (SELECT id_cliente, id_equipo FROM equipo) e ON c.id_cliente = e.id_cliente --LEFT para que aparezcan los clientes que no tienen equipo
GROUP BY p.id_persona
ORDER BY 2, 3;


--------------------------------------------- Ejercicio 1) b. ----------------------------------------------------------
/*
 Realizar un ranking (de mayor a menor) de la cantidad de equipos instalados y aún activos, durante los últimos
 24 meses, según su distribución geográfica, mostrando: nombre de ciudad, id de la ciudad, nombre del barrio,
 id del barrio y cantidad de equipos.
*/
SELECT c.nombre, c.id_ciudad, b.nombre, b.id_barrio, count(e.id_equipo) "cant. equipos instalados"
FROM ciudad c
JOIN barrio b ON c.id_ciudad = b.id_ciudad
JOIN (SELECT id_barrio, id_persona FROM direccion) d ON b.id_barrio = d.id_barrio
JOIN (SELECT id_cliente FROM cliente) cte ON d.id_persona = cte.id_cliente
JOIN (SELECT id_cliente, id_equipo, fecha_baja, fecha_alta FROM equipo) e ON cte.id_cliente = e.id_cliente
WHERE (e.fecha_alta > current_date - INTERVAL '2 years') AND
      ((e.fecha_baja IS NULL) OR (e.fecha_baja > current_date))
GROUP BY 1,2,3,4
ORDER BY 5 DESC;
/*
 1.b) Suponemos que aunque un cliente se haya dado de baja, si el equipo no se dá de baja aún puede considerarse utilizado
*/

--------------------------------------------- Ejercicio 1) c. ----------------------------------------------------------
/*
 Visualizar el Top-3 de los lugares donde se ha realizado la mayor cantidad de servicios periódicos durante los
 últimos 3 años.
*/
select c.nombre ciudad, count(s.id_servicio) servicios
from ciudad c
join (select id_ciudad, id_barrio from barrio) b on c.id_ciudad = b.id_ciudad
join (select id_barrio, id_persona from direccion) d on b.id_barrio = d.id_barrio
join (select id_comp, id_tcomp, id_cliente  --al no pasar por persona o cliente no incluimos a los clientes sin direccion
      from comprobante
      where fecha > current_date - interval '3 year' and        --el where de este select hace que solo se tomen en cuenta los comprobantes de tipo remito y resuelve la condición de tiempo
            id_tcomp IN (select id_tcomp from tipocomprobante where tipo = 'remito')) comp on d.id_persona = comp.id_cliente
join (select id_comp, id_tcomp, id_servicio from lineacomprobante) lc on (comp.id_comp,comp.id_tcomp) = (lc.id_comp, lc.id_tcomp)
join (select id_servicio from servicio where periodico is true) s on lc.id_servicio = s.id_servicio
group by c.id_ciudad
order by 2 desc
limit 3;
/*
 1.c) Concluímos que por lugar se refiere a ciudad y que los servicios periódicos prestados se encuentran en los comprobantes de tipo remito
*/

--------------------------------------------- Ejercicio 1) d. ----------------------------------------------------------
/*
 Indicar el nombre, apellido, tipo y número de documento de los clientes que han contratado todos los servicios
 periódicos cuyo intervalo se encuentra entre 5 y 10.
*/
select p.nombre, p.apellido, p.tipodoc, p.nrodoc
from persona p
where not exists (select s.id_servicio      --todos los servicios periódicos
                  from servicio s
                  where (s.intervalo <= 10 and s.intervalo >= 5 and s.periodico is True)
                  EXCEPT
                  select lc.id_servicio     --todos los servicios de cada cliente
                  from cliente c
                  join (select id_cliente, id_comp, id_tcomp from comprobante) comp on c.id_cliente = comp.id_cliente and comp.id_tcomp IN (select id_tcomp from tipocomprobante where tipo = 'remito')
                  join (select id_comp, id_tcomp, id_servicio from lineacomprobante) lc on (comp.id_comp,comp.id_tcomp) = (lc.id_comp, lc.id_tcomp)
	              where p.id_persona = c.id_cliente);

/*
 1.d) Como en el 1.c) Se considera que los servicios periódicos se encuentran únicamente en los comprobantes de tipo remito.
*/

--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--
--::::::::::::::::::::::::::::::::::::::::::::::::::FIN:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::--